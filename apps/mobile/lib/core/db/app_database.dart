import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Read cache of the workers list so the ADMIN app stays useful without internet (D-022). The NAS is the source of truth:
/// this table is only ever a copy. Wiped on logout.
class CachedWorkers extends Table {
  TextColumn get id => text()();
  TextColumn get status => text()();
  TextColumn get name => text()();

  /// lower-cased "name code phone" for offline search
  TextColumn get search => text()();

  /// full API payload (JSON)
  TextColumn get json => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Work done without internet, waiting to be sent (oldest first): «сколько сделано», «работа принята».
/// Sent by OfflineQueue as soon as the server answers again; every action carries its own idempotency key, so a retry
/// after a half-sent request never counts twice.
class PendingActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// progress | receive
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  TextColumn get idempotencyKey => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  /// set when the server said «no» (not a network problem): shown to her, then dropped
  TextColumn get lastError => text().nullable()();
}

/// The last answer of a few screens («Главная», «Наши работы»), shown when there is no internet instead of an error.
class CachedResponses extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [CachedWorkers, PendingActions, CachedResponses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'diamoraa'));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(pendingActions);
            await m.createTable(cachedResponses);
          }
        },
      );
}
