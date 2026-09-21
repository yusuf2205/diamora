import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';
import '../storage/token_store.dart';

/// Envelope of docs/REALTIME.md. Events are HINTS ("something changed"): screens refetch from the API, which stays the
/// source of truth.
class RealtimeEvent {
  RealtimeEvent({required this.id, required this.type, required this.occurredAt, required this.data});
  final String id;
  final String type;
  final DateTime occurredAt;
  final Map<String, dynamic> data;

  factory RealtimeEvent.fromJson(Map<dynamic, dynamic> j) => RealtimeEvent(
        id: j['id'] as String,
        type: j['type'] as String,
        occurredAt: DateTime.parse(j['occurredAt'] as String),
        data: (j['data'] as Map).cast<String, dynamic>(),
      );
}

/// Socket.IO connection (token in the handshake). Reconnects with back-off; on every (re)connect listeners are told to refetch,
/// because there is no replay.
class RealtimeClient {
  RealtimeClient(this._tokens);
  final TokenStore _tokens;
  io.Socket? _socket;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _connected = StreamController<bool>.broadcast();

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<bool> get connection => _connected.stream;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    await disconnect();
    final token = await _tokens.readAccess();
    if (token == null) return;
    final s = io.io(
      AppConfig.root,
      io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).enableReconnection().setReconnectionDelay(1000).setReconnectionDelayMax(15000).disableAutoConnect().build(),
    );
    s.on('ready', (_) => _connected.add(true));
    s.on('event', (d) {
      if (d is Map) _events.add(RealtimeEvent.fromJson(d));
    });
    s.onDisconnect((_) => _connected.add(false));
    // the access token expires (15 min): a reconnect must present a fresh one
    s.io.on('reconnect_attempt', (_) async => s.auth = {'token': await _tokens.readAccess()});
    s.connect();
    _socket = s;
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
    _connected.add(false);
  }
}
