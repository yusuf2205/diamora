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

@DriftDatabase(tables: [CachedWorkers])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'yusmus'));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;
}
