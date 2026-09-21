// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedWorkersTable extends CachedWorkers
    with TableInfo<$CachedWorkersTable, CachedWorker> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedWorkersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchMeta = const VerificationMeta('search');
  @override
  late final GeneratedColumn<String> search = GeneratedColumn<String>(
    'search',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    status,
    name,
    search,
    json,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_workers';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedWorker> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('search')) {
      context.handle(
        _searchMeta,
        search.isAcceptableOrUnknown(data['search']!, _searchMeta),
      );
    } else if (isInserting) {
      context.missing(_searchMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedWorker map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedWorker(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      search: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedWorkersTable createAlias(String alias) {
    return $CachedWorkersTable(attachedDatabase, alias);
  }
}

class CachedWorker extends DataClass implements Insertable<CachedWorker> {
  final String id;
  final String status;
  final String name;

  /// lower-cased "name code phone" for offline search
  final String search;

  /// full API payload (JSON)
  final String json;
  final DateTime cachedAt;
  const CachedWorker({
    required this.id,
    required this.status,
    required this.name,
    required this.search,
    required this.json,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['status'] = Variable<String>(status);
    map['name'] = Variable<String>(name);
    map['search'] = Variable<String>(search);
    map['json'] = Variable<String>(json);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedWorkersCompanion toCompanion(bool nullToAbsent) {
    return CachedWorkersCompanion(
      id: Value(id),
      status: Value(status),
      name: Value(name),
      search: Value(search),
      json: Value(json),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedWorker.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedWorker(
      id: serializer.fromJson<String>(json['id']),
      status: serializer.fromJson<String>(json['status']),
      name: serializer.fromJson<String>(json['name']),
      search: serializer.fromJson<String>(json['search']),
      json: serializer.fromJson<String>(json['json']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'status': serializer.toJson<String>(status),
      'name': serializer.toJson<String>(name),
      'search': serializer.toJson<String>(search),
      'json': serializer.toJson<String>(json),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedWorker copyWith({
    String? id,
    String? status,
    String? name,
    String? search,
    String? json,
    DateTime? cachedAt,
  }) => CachedWorker(
    id: id ?? this.id,
    status: status ?? this.status,
    name: name ?? this.name,
    search: search ?? this.search,
    json: json ?? this.json,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedWorker copyWithCompanion(CachedWorkersCompanion data) {
    return CachedWorker(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      name: data.name.present ? data.name.value : this.name,
      search: data.search.present ? data.search.value : this.search,
      json: data.json.present ? data.json.value : this.json,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedWorker(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('name: $name, ')
          ..write('search: $search, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, status, name, search, json, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedWorker &&
          other.id == this.id &&
          other.status == this.status &&
          other.name == this.name &&
          other.search == this.search &&
          other.json == this.json &&
          other.cachedAt == this.cachedAt);
}

class CachedWorkersCompanion extends UpdateCompanion<CachedWorker> {
  final Value<String> id;
  final Value<String> status;
  final Value<String> name;
  final Value<String> search;
  final Value<String> json;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedWorkersCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.name = const Value.absent(),
    this.search = const Value.absent(),
    this.json = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedWorkersCompanion.insert({
    required String id,
    required String status,
    required String name,
    required String search,
    required String json,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       status = Value(status),
       name = Value(name),
       search = Value(search),
       json = Value(json),
       cachedAt = Value(cachedAt);
  static Insertable<CachedWorker> custom({
    Expression<String>? id,
    Expression<String>? status,
    Expression<String>? name,
    Expression<String>? search,
    Expression<String>? json,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (name != null) 'name': name,
      if (search != null) 'search': search,
      if (json != null) 'json': json,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedWorkersCompanion copyWith({
    Value<String>? id,
    Value<String>? status,
    Value<String>? name,
    Value<String>? search,
    Value<String>? json,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedWorkersCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      name: name ?? this.name,
      search: search ?? this.search,
      json: json ?? this.json,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (search.present) {
      map['search'] = Variable<String>(search.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedWorkersCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('name: $name, ')
          ..write('search: $search, ')
          ..write('json: $json, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedWorkersTable cachedWorkers = $CachedWorkersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedWorkers];
}

typedef $$CachedWorkersTableCreateCompanionBuilder =
    CachedWorkersCompanion Function({
      required String id,
      required String status,
      required String name,
      required String search,
      required String json,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedWorkersTableUpdateCompanionBuilder =
    CachedWorkersCompanion Function({
      Value<String> id,
      Value<String> status,
      Value<String> name,
      Value<String> search,
      Value<String> json,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedWorkersTableFilterComposer
    extends Composer<_$AppDatabase, $CachedWorkersTable> {
  $$CachedWorkersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get search => $composableBuilder(
    column: $table.search,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedWorkersTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedWorkersTable> {
  $$CachedWorkersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get search => $composableBuilder(
    column: $table.search,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedWorkersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedWorkersTable> {
  $$CachedWorkersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get search =>
      $composableBuilder(column: $table.search, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedWorkersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedWorkersTable,
          CachedWorker,
          $$CachedWorkersTableFilterComposer,
          $$CachedWorkersTableOrderingComposer,
          $$CachedWorkersTableAnnotationComposer,
          $$CachedWorkersTableCreateCompanionBuilder,
          $$CachedWorkersTableUpdateCompanionBuilder,
          (
            CachedWorker,
            BaseReferences<_$AppDatabase, $CachedWorkersTable, CachedWorker>,
          ),
          CachedWorker,
          PrefetchHooks Function()
        > {
  $$CachedWorkersTableTableManager(_$AppDatabase db, $CachedWorkersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedWorkersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedWorkersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedWorkersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> search = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedWorkersCompanion(
                id: id,
                status: status,
                name: name,
                search: search,
                json: json,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String status,
                required String name,
                required String search,
                required String json,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedWorkersCompanion.insert(
                id: id,
                status: status,
                name: name,
                search: search,
                json: json,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedWorkersTable, CachedWorker>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedWorkersTable,
                    CachedWorker
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedWorkersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedWorkersTable,
      CachedWorker,
      $$CachedWorkersTableFilterComposer,
      $$CachedWorkersTableOrderingComposer,
      $$CachedWorkersTableAnnotationComposer,
      $$CachedWorkersTableCreateCompanionBuilder,
      $$CachedWorkersTableUpdateCompanionBuilder,
      (
        CachedWorker,
        BaseReferences<_$AppDatabase, $CachedWorkersTable, CachedWorker>,
      ),
      CachedWorker,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedWorkersTableTableManager get cachedWorkers =>
      $$CachedWorkersTableTableManager(_db, _db.cachedWorkers);
}
