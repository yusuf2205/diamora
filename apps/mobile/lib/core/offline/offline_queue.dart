import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../network/api_exception.dart';

/// No internet, the server is off, or it is overloaded: try the same thing again later. Anything else (a 4xx) is the
/// server saying «no» - retrying would never help.
bool isRetryable(Object e) =>
    (e is ApiException && (e.isOffline || (e.status ?? 0) >= 500 || e.status == 429 || e.status == 408)) || e is TimeoutException || e is SocketException;

/// Sends one queued action; the repository knows how (see WorkRepository.sendQueued).
typedef QueuedSender = Future<void> Function(String kind, Map<String, dynamic> payload, String idempotencyKey);

/// Work done without internet («сколько сделано», «готово», «работа принята») is kept on the phone and sent in the
/// same order as soon as the server answers - on its own, no button to press. Each action has ONE idempotency key for
/// all its tries, so an answer lost on the way back never counts it twice.
class OfflineQueue {
  OfflineQueue(this._db, this._send);
  final AppDatabase _db;
  final QueuedSender _send;
  Future<int>? _running;
  // our own change signal (a drift table stream leaves timers behind when a screen closes)
  final _changes = StreamController<void>.broadcast();
  void _changed() => _changes.add(null);

  Future<void> add(String kind, Map<String, dynamic> payload) async {
    await _db.into(_db.pendingActions).insert(PendingActionsCompanion.insert(
          kind: kind,
          payload: jsonEncode(payload),
          idempotencyKey: const Uuid().v4(),
          createdAt: DateTime.now(),
        ));
    _changed();
  }

  Future<List<PendingAction>> list() => (_db.select(_db.pendingActions)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  /// the list now, and again after every change
  Stream<List<PendingAction>> watch() async* {
    yield await list();
    await for (final _ in _changes.stream) {
      yield await list();
    }
  }

  Future<void> dismiss(int id) async {
    await (_db.delete(_db.pendingActions)..where((t) => t.id.equals(id))).go();
    _changed();
  }

  /// Sends what is waiting, oldest first; stops at the first network problem (the rest waits for the next try).
  /// Returns how many were sent. Two calls at once share one run.
  Future<int> flush() => _running ??= _flush().whenComplete(() => _running = null);

  Future<int> _flush() async {
    try {
      return await _flushOnce();
    } finally {
      _changed();
    }
  }

  Future<int> _flushOnce() async {
    var sent = 0;
    final rows = await (_db.select(_db.pendingActions)
          ..where((t) => t.lastError.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    for (final r in rows) {
      try {
        await _send(r.kind, (jsonDecode(r.payload) as Map).cast<String, dynamic>(), r.idempotencyKey);
        await (_db.delete(_db.pendingActions)..where((t) => t.id.equals(r.id))).go();
        sent++;
      } catch (e) {
        if (isRetryable(e)) {
          await (_db.update(_db.pendingActions)..where((t) => t.id.equals(r.id))).write(PendingActionsCompanion(attempts: Value(r.attempts + 1)));
          break;
        }
        // the server refused it: keep it visible with the reason so she knows, never retry it
        final reason = e is ApiException ? e.code : e.toString();
        await (_db.update(_db.pendingActions)..where((t) => t.id.equals(r.id))).write(PendingActionsCompanion(lastError: Value(reason), attempts: Value(r.attempts + 1)));
      }
    }
    return sent;
  }
}

/// The last good answer of a screen, shown without internet («данные от 12:30») instead of an error.
class ResponseCache {
  ResponseCache(this._db);
  final AppDatabase _db;

  Future<void> save(String key, Object json) =>
      _db.into(_db.cachedResponses).insertOnConflictUpdate(CachedResponsesCompanion.insert(key: key, json: jsonEncode(json), savedAt: DateTime.now()));

  Future<({Object? json, DateTime savedAt})?> read(String key) async {
    final r = await (_db.select(_db.cachedResponses)..where((t) => t.key.equals(key))).getSingleOrNull();
    return r == null ? null : (json: jsonDecode(r.json), savedAt: r.savedAt);
  }

  /// network first; on a network problem the cached copy (if any), else the error as before
  Future<T> get<T>(String key, Future<Object> Function() fetch, T Function(Object json) parse) async {
    try {
      final j = await fetch();
      try {
        await save(key, j);
      } catch (_) {/* storage trouble: the screen still gets the fresh data */}
      return parse(j);
    } catch (e) {
      if (!isRetryable(e)) rethrow;
      ({Object? json, DateTime savedAt})? c;
      try {
        c = await read(key);
      } catch (_) {}
      if (c == null || c.json == null) rethrow;
      return parse(c.json!);
    }
  }

  Future<void> clear() => _db.delete(_db.cachedResponses).go();
}
