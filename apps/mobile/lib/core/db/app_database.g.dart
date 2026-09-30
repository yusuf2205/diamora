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

class $PendingActionsTable extends PendingActions
    with TableInfo<$PendingActionsTable, PendingAction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    payload,
    idempotencyKey,
    createdAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingAction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingAction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $PendingActionsTable createAlias(String alias) {
    return $PendingActionsTable(attachedDatabase, alias);
  }
}

class PendingAction extends DataClass implements Insertable<PendingAction> {
  final int id;

  /// progress | receive
  final String kind;
  final String payload;
  final String idempotencyKey;
  final DateTime createdAt;
  final int attempts;

  /// set when the server said «no» (not a network problem): shown to her, then dropped
  final String? lastError;
  const PendingAction({
    required this.id,
    required this.kind,
    required this.payload,
    required this.idempotencyKey,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['payload'] = Variable<String>(payload);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingActionsCompanion toCompanion(bool nullToAbsent) {
    return PendingActionsCompanion(
      id: Value(id),
      kind: Value(kind),
      payload: Value(payload),
      idempotencyKey: Value(idempotencyKey),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PendingAction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAction(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String>(json['payload']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String>(payload),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingAction copyWith({
    int? id,
    String? kind,
    String? payload,
    String? idempotencyKey,
    DateTime? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => PendingAction(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  PendingAction copyWithCompanion(PendingActionsCompanion data) {
    return PendingAction(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingAction(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    payload,
    idempotencyKey,
    createdAt,
    attempts,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingAction &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.idempotencyKey == this.idempotencyKey &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class PendingActionsCompanion extends UpdateCompanion<PendingAction> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> payload;
  final Value<String> idempotencyKey;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const PendingActionsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PendingActionsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String payload,
    required String idempotencyKey,
    required DateTime createdAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : kind = Value(kind),
       payload = Value(payload),
       idempotencyKey = Value(idempotencyKey),
       createdAt = Value(createdAt);
  static Insertable<PendingAction> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<String>? idempotencyKey,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PendingActionsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? payload,
    Value<String>? idempotencyKey,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return PendingActionsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingActionsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $CachedResponsesTable extends CachedResponses
    with TableInfo<$CachedResponsesTable, CachedResponse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedResponsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
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
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, json, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedResponse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CachedResponse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedResponse(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $CachedResponsesTable createAlias(String alias) {
    return $CachedResponsesTable(attachedDatabase, alias);
  }
}

class CachedResponse extends DataClass implements Insertable<CachedResponse> {
  final String key;
  final String json;
  final DateTime savedAt;
  const CachedResponse({
    required this.key,
    required this.json,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  CachedResponsesCompanion toCompanion(bool nullToAbsent) {
    return CachedResponsesCompanion(
      key: Value(key),
      json: Value(json),
      savedAt: Value(savedAt),
    );
  }

  factory CachedResponse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedResponse(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  CachedResponse copyWith({String? key, String? json, DateTime? savedAt}) =>
      CachedResponse(
        key: key ?? this.key,
        json: json ?? this.json,
        savedAt: savedAt ?? this.savedAt,
      );
  CachedResponse copyWithCompanion(CachedResponsesCompanion data) {
    return CachedResponse(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedResponse(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedResponse &&
          other.key == this.key &&
          other.json == this.json &&
          other.savedAt == this.savedAt);
}

class CachedResponsesCompanion extends UpdateCompanion<CachedResponse> {
  final Value<String> key;
  final Value<String> json;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const CachedResponsesCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedResponsesCompanion.insert({
    required String key,
    required String json,
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       json = Value(json),
       savedAt = Value(savedAt);
  static Insertable<CachedResponse> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedResponsesCompanion copyWith({
    Value<String>? key,
    Value<String>? json,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return CachedResponsesCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedResponsesCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedWorkersTable cachedWorkers = $CachedWorkersTable(this);
  late final $PendingActionsTable pendingActions = $PendingActionsTable(this);
  late final $CachedResponsesTable cachedResponses = $CachedResponsesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedWorkers,
    pendingActions,
    cachedResponses,
  ];
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
typedef $$PendingActionsTableCreateCompanionBuilder =
    PendingActionsCompanion Function({
      Value<int> id,
      required String kind,
      required String payload,
      required String idempotencyKey,
      required DateTime createdAt,
      Value<int> attempts,
      Value<String?> lastError,
    });
typedef $$PendingActionsTableUpdateCompanionBuilder =
    PendingActionsCompanion Function({
      Value<int> id,
      Value<String> kind,
      Value<String> payload,
      Value<String> idempotencyKey,
      Value<DateTime> createdAt,
      Value<int> attempts,
      Value<String?> lastError,
    });

class $$PendingActionsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingActionsTable,
          PendingAction,
          $$PendingActionsTableFilterComposer,
          $$PendingActionsTableOrderingComposer,
          $$PendingActionsTableAnnotationComposer,
          $$PendingActionsTableCreateCompanionBuilder,
          $$PendingActionsTableUpdateCompanionBuilder,
          (
            PendingAction,
            BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>,
          ),
          PendingAction,
          PrefetchHooks Function()
        > {
  $$PendingActionsTableTableManager(
    _$AppDatabase db,
    $PendingActionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingActionsCompanion(
                id: id,
                kind: kind,
                payload: payload,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String payload,
                required String idempotencyKey,
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingActionsCompanion.insert(
                id: id,
                kind: kind,
                payload: payload,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingActionsTable, PendingAction>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingActionsTable,
                    PendingAction
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingActionsTable,
      PendingAction,
      $$PendingActionsTableFilterComposer,
      $$PendingActionsTableOrderingComposer,
      $$PendingActionsTableAnnotationComposer,
      $$PendingActionsTableCreateCompanionBuilder,
      $$PendingActionsTableUpdateCompanionBuilder,
      (
        PendingAction,
        BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>,
      ),
      PendingAction,
      PrefetchHooks Function()
    >;
typedef $$CachedResponsesTableCreateCompanionBuilder =
    CachedResponsesCompanion Function({
      required String key,
      required String json,
      required DateTime savedAt,
      Value<int> rowid,
    });
typedef $$CachedResponsesTableUpdateCompanionBuilder =
    CachedResponsesCompanion Function({
      Value<String> key,
      Value<String> json,
      Value<DateTime> savedAt,
      Value<int> rowid,
    });

class $$CachedResponsesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedResponsesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedResponsesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$CachedResponsesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedResponsesTable,
          CachedResponse,
          $$CachedResponsesTableFilterComposer,
          $$CachedResponsesTableOrderingComposer,
          $$CachedResponsesTableAnnotationComposer,
          $$CachedResponsesTableCreateCompanionBuilder,
          $$CachedResponsesTableUpdateCompanionBuilder,
          (
            CachedResponse,
            BaseReferences<
              _$AppDatabase,
              $CachedResponsesTable,
              CachedResponse
            >,
          ),
          CachedResponse,
          PrefetchHooks Function()
        > {
  $$CachedResponsesTableTableManager(
    _$AppDatabase db,
    $CachedResponsesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedResponsesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedResponsesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedResponsesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedResponsesCompanion(
                key: key,
                json: json,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String json,
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedResponsesCompanion.insert(
                key: key,
                json: json,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedResponsesTable, CachedResponse>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedResponsesTable,
                    CachedResponse
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedResponsesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedResponsesTable,
      CachedResponse,
      $$CachedResponsesTableFilterComposer,
      $$CachedResponsesTableOrderingComposer,
      $$CachedResponsesTableAnnotationComposer,
      $$CachedResponsesTableCreateCompanionBuilder,
      $$CachedResponsesTableUpdateCompanionBuilder,
      (
        CachedResponse,
        BaseReferences<_$AppDatabase, $CachedResponsesTable, CachedResponse>,
      ),
      CachedResponse,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedWorkersTableTableManager get cachedWorkers =>
      $$CachedWorkersTableTableManager(_db, _db.cachedWorkers);
  $$PendingActionsTableTableManager get pendingActions =>
      $$PendingActionsTableTableManager(_db, _db.pendingActions);
  $$CachedResponsesTableTableManager get cachedResponses =>
      $$CachedResponsesTableTableManager(_db, _db.cachedResponses);
}
