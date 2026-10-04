// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_tables.dart';

// ignore_for_file: type=lint
class $UsMetaTable extends UsMeta with TableInfo<$UsMetaTable, UsMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'us_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsMetaData> instance, {
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
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  UsMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsMetaData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $UsMetaTable createAlias(String alias) {
    return $UsMetaTable(attachedDatabase, alias);
  }
}

class UsMetaData extends DataClass implements Insertable<UsMetaData> {
  final String key;
  final String value;
  const UsMetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  UsMetaCompanion toCompanion(bool nullToAbsent) {
    return UsMetaCompanion(key: Value(key), value: Value(value));
  }

  factory UsMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsMetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  UsMetaData copyWith({String? key, String? value}) => UsMetaData(key: key ?? this.key, value: value ?? this.value);
  UsMetaData copyWithCompanion(UsMetaCompanion data) {
    return UsMetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsMetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UsMetaData && other.key == this.key && other.value == this.value);
}

class UsMetaCompanion extends UpdateCompanion<UsMetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const UsMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<UsMetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return UsMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsOutboxTable extends UsOutbox with TableInfo<$UsOutboxTable, UsOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyHashMeta = const VerificationMeta(
    'keyHash',
  );
  @override
  late final GeneratedColumn<Uint8List> keyHash = GeneratedColumn<Uint8List>(
    'key_hash',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyJsonMeta = const VerificationMeta(
    'keyJson',
  );
  @override
  late final GeneratedColumn<String> keyJson = GeneratedColumn<String>(
    'key_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _rowJsonMeta = const VerificationMeta(
    'rowJson',
  );
  @override
  late final GeneratedColumn<String> rowJson = GeneratedColumn<String>(
    'row_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deltaJsonMeta = const VerificationMeta(
    'deltaJson',
  );
  @override
  late final GeneratedColumn<String> deltaJson = GeneratedColumn<String>(
    'delta_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deliveredMaybeMeta = const VerificationMeta(
    'deliveredMaybe',
  );
  @override
  late final GeneratedColumn<int> deliveredMaybe = GeneratedColumn<int>(
    'delivered_maybe',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _failuresMeta = const VerificationMeta(
    'failures',
  );
  @override
  late final GeneratedColumn<int> failures = GeneratedColumn<int>(
    'failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<int> nextAttemptAt = GeneratedColumn<int>(
    'next_attempt_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leaseUntilMeta = const VerificationMeta(
    'leaseUntil',
  );
  @override
  late final GeneratedColumn<int> leaseUntil = GeneratedColumn<int>(
    'lease_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leasedByMeta = const VerificationMeta(
    'leasedBy',
  );
  @override
  late final GeneratedColumn<String> leasedBy = GeneratedColumn<String>(
    'leased_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastFailureJsonMeta = const VerificationMeta(
    'lastFailureJson',
  );
  @override
  late final GeneratedColumn<String> lastFailureJson = GeneratedColumn<String>(
    'last_failure_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sequence,
    entity,
    keyHash,
    keyJson,
    kind,
    rowJson,
    deltaJson,
    state,
    deliveredMaybe,
    attempts,
    failures,
    nextAttemptAt,
    leaseUntil,
    leasedBy,
    lastFailureJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'us_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('key_hash')) {
      context.handle(
        _keyHashMeta,
        keyHash.isAcceptableOrUnknown(data['key_hash']!, _keyHashMeta),
      );
    } else if (isInserting) {
      context.missing(_keyHashMeta);
    }
    if (data.containsKey('key_json')) {
      context.handle(
        _keyJsonMeta,
        keyJson.isAcceptableOrUnknown(data['key_json']!, _keyJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_keyJsonMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('row_json')) {
      context.handle(
        _rowJsonMeta,
        rowJson.isAcceptableOrUnknown(data['row_json']!, _rowJsonMeta),
      );
    }
    if (data.containsKey('delta_json')) {
      context.handle(
        _deltaJsonMeta,
        deltaJson.isAcceptableOrUnknown(data['delta_json']!, _deltaJsonMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('delivered_maybe')) {
      context.handle(
        _deliveredMaybeMeta,
        deliveredMaybe.isAcceptableOrUnknown(
          data['delivered_maybe']!,
          _deliveredMaybeMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('failures')) {
      context.handle(
        _failuresMeta,
        failures.isAcceptableOrUnknown(data['failures']!, _failuresMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('lease_until')) {
      context.handle(
        _leaseUntilMeta,
        leaseUntil.isAcceptableOrUnknown(data['lease_until']!, _leaseUntilMeta),
      );
    }
    if (data.containsKey('leased_by')) {
      context.handle(
        _leasedByMeta,
        leasedBy.isAcceptableOrUnknown(data['leased_by']!, _leasedByMeta),
      );
    }
    if (data.containsKey('last_failure_json')) {
      context.handle(
        _lastFailureJsonMeta,
        lastFailureJson.isAcceptableOrUnknown(
          data['last_failure_json']!,
          _lastFailureJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sequence};
  @override
  UsOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsOutboxData(
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      keyHash: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}key_hash'],
      )!,
      keyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_json'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      rowJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_json'],
      ),
      deltaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delta_json'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      deliveredMaybe: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delivered_maybe'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      failures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failures'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      leaseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lease_until'],
      ),
      leasedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leased_by'],
      ),
      lastFailureJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_failure_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UsOutboxTable createAlias(String alias) {
    return $UsOutboxTable(attachedDatabase, alias);
  }
}

class UsOutboxData extends DataClass implements Insertable<UsOutboxData> {
  final int sequence;

  /// SQL name of the synced entity (the user's table).
  final String entity;

  /// Stable digest of [keyJson], used for indexed lookups.
  final Uint8List keyHash;

  /// Canonical JSON array of primary-key values.
  final String keyJson;

  /// `upsert` | `update` | `delete`.
  final String kind;

  /// Full after-image for `upsert` changes.
  final String? rowJson;

  /// Changed-column map for `update` changes.
  final String? deltaJson;

  /// `pending` | `inflight`.
  final String state;

  /// 1 when the change may have reached the server; such rows are immutable.
  final int deliveredMaybe;

  /// Number of claims/sends (observability only).
  final int attempts;

  /// Non-transient failures, bounded by `SyncOptions.maxAttempts`.
  final int failures;
  final int nextAttemptAt;
  final int? leaseUntil;
  final String? leasedBy;
  final String? lastFailureJson;
  final int createdAt;
  final int updatedAt;
  const UsOutboxData({
    required this.sequence,
    required this.entity,
    required this.keyHash,
    required this.keyJson,
    required this.kind,
    this.rowJson,
    this.deltaJson,
    required this.state,
    required this.deliveredMaybe,
    required this.attempts,
    required this.failures,
    required this.nextAttemptAt,
    this.leaseUntil,
    this.leasedBy,
    this.lastFailureJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sequence'] = Variable<int>(sequence);
    map['entity'] = Variable<String>(entity);
    map['key_hash'] = Variable<Uint8List>(keyHash);
    map['key_json'] = Variable<String>(keyJson);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || rowJson != null) {
      map['row_json'] = Variable<String>(rowJson);
    }
    if (!nullToAbsent || deltaJson != null) {
      map['delta_json'] = Variable<String>(deltaJson);
    }
    map['state'] = Variable<String>(state);
    map['delivered_maybe'] = Variable<int>(deliveredMaybe);
    map['attempts'] = Variable<int>(attempts);
    map['failures'] = Variable<int>(failures);
    map['next_attempt_at'] = Variable<int>(nextAttemptAt);
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<int>(leaseUntil);
    }
    if (!nullToAbsent || leasedBy != null) {
      map['leased_by'] = Variable<String>(leasedBy);
    }
    if (!nullToAbsent || lastFailureJson != null) {
      map['last_failure_json'] = Variable<String>(lastFailureJson);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  UsOutboxCompanion toCompanion(bool nullToAbsent) {
    return UsOutboxCompanion(
      sequence: Value(sequence),
      entity: Value(entity),
      keyHash: Value(keyHash),
      keyJson: Value(keyJson),
      kind: Value(kind),
      rowJson: rowJson == null && nullToAbsent ? const Value.absent() : Value(rowJson),
      deltaJson: deltaJson == null && nullToAbsent ? const Value.absent() : Value(deltaJson),
      state: Value(state),
      deliveredMaybe: Value(deliveredMaybe),
      attempts: Value(attempts),
      failures: Value(failures),
      nextAttemptAt: Value(nextAttemptAt),
      leaseUntil: leaseUntil == null && nullToAbsent ? const Value.absent() : Value(leaseUntil),
      leasedBy: leasedBy == null && nullToAbsent ? const Value.absent() : Value(leasedBy),
      lastFailureJson: lastFailureJson == null && nullToAbsent ? const Value.absent() : Value(lastFailureJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UsOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsOutboxData(
      sequence: serializer.fromJson<int>(json['sequence']),
      entity: serializer.fromJson<String>(json['entity']),
      keyHash: serializer.fromJson<Uint8List>(json['keyHash']),
      keyJson: serializer.fromJson<String>(json['keyJson']),
      kind: serializer.fromJson<String>(json['kind']),
      rowJson: serializer.fromJson<String?>(json['rowJson']),
      deltaJson: serializer.fromJson<String?>(json['deltaJson']),
      state: serializer.fromJson<String>(json['state']),
      deliveredMaybe: serializer.fromJson<int>(json['deliveredMaybe']),
      attempts: serializer.fromJson<int>(json['attempts']),
      failures: serializer.fromJson<int>(json['failures']),
      nextAttemptAt: serializer.fromJson<int>(json['nextAttemptAt']),
      leaseUntil: serializer.fromJson<int?>(json['leaseUntil']),
      leasedBy: serializer.fromJson<String?>(json['leasedBy']),
      lastFailureJson: serializer.fromJson<String?>(json['lastFailureJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sequence': serializer.toJson<int>(sequence),
      'entity': serializer.toJson<String>(entity),
      'keyHash': serializer.toJson<Uint8List>(keyHash),
      'keyJson': serializer.toJson<String>(keyJson),
      'kind': serializer.toJson<String>(kind),
      'rowJson': serializer.toJson<String?>(rowJson),
      'deltaJson': serializer.toJson<String?>(deltaJson),
      'state': serializer.toJson<String>(state),
      'deliveredMaybe': serializer.toJson<int>(deliveredMaybe),
      'attempts': serializer.toJson<int>(attempts),
      'failures': serializer.toJson<int>(failures),
      'nextAttemptAt': serializer.toJson<int>(nextAttemptAt),
      'leaseUntil': serializer.toJson<int?>(leaseUntil),
      'leasedBy': serializer.toJson<String?>(leasedBy),
      'lastFailureJson': serializer.toJson<String?>(lastFailureJson),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  UsOutboxData copyWith({
    int? sequence,
    String? entity,
    Uint8List? keyHash,
    String? keyJson,
    String? kind,
    Value<String?> rowJson = const Value.absent(),
    Value<String?> deltaJson = const Value.absent(),
    String? state,
    int? deliveredMaybe,
    int? attempts,
    int? failures,
    int? nextAttemptAt,
    Value<int?> leaseUntil = const Value.absent(),
    Value<String?> leasedBy = const Value.absent(),
    Value<String?> lastFailureJson = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => UsOutboxData(
    sequence: sequence ?? this.sequence,
    entity: entity ?? this.entity,
    keyHash: keyHash ?? this.keyHash,
    keyJson: keyJson ?? this.keyJson,
    kind: kind ?? this.kind,
    rowJson: rowJson.present ? rowJson.value : this.rowJson,
    deltaJson: deltaJson.present ? deltaJson.value : this.deltaJson,
    state: state ?? this.state,
    deliveredMaybe: deliveredMaybe ?? this.deliveredMaybe,
    attempts: attempts ?? this.attempts,
    failures: failures ?? this.failures,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
    leasedBy: leasedBy.present ? leasedBy.value : this.leasedBy,
    lastFailureJson: lastFailureJson.present ? lastFailureJson.value : this.lastFailureJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UsOutboxData copyWithCompanion(UsOutboxCompanion data) {
    return UsOutboxData(
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      entity: data.entity.present ? data.entity.value : this.entity,
      keyHash: data.keyHash.present ? data.keyHash.value : this.keyHash,
      keyJson: data.keyJson.present ? data.keyJson.value : this.keyJson,
      kind: data.kind.present ? data.kind.value : this.kind,
      rowJson: data.rowJson.present ? data.rowJson.value : this.rowJson,
      deltaJson: data.deltaJson.present ? data.deltaJson.value : this.deltaJson,
      state: data.state.present ? data.state.value : this.state,
      deliveredMaybe: data.deliveredMaybe.present ? data.deliveredMaybe.value : this.deliveredMaybe,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      failures: data.failures.present ? data.failures.value : this.failures,
      nextAttemptAt: data.nextAttemptAt.present ? data.nextAttemptAt.value : this.nextAttemptAt,
      leaseUntil: data.leaseUntil.present ? data.leaseUntil.value : this.leaseUntil,
      leasedBy: data.leasedBy.present ? data.leasedBy.value : this.leasedBy,
      lastFailureJson: data.lastFailureJson.present ? data.lastFailureJson.value : this.lastFailureJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsOutboxData(')
          ..write('sequence: $sequence, ')
          ..write('entity: $entity, ')
          ..write('keyHash: $keyHash, ')
          ..write('keyJson: $keyJson, ')
          ..write('kind: $kind, ')
          ..write('rowJson: $rowJson, ')
          ..write('deltaJson: $deltaJson, ')
          ..write('state: $state, ')
          ..write('deliveredMaybe: $deliveredMaybe, ')
          ..write('attempts: $attempts, ')
          ..write('failures: $failures, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('leasedBy: $leasedBy, ')
          ..write('lastFailureJson: $lastFailureJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sequence,
    entity,
    $driftBlobEquality.hash(keyHash),
    keyJson,
    kind,
    rowJson,
    deltaJson,
    state,
    deliveredMaybe,
    attempts,
    failures,
    nextAttemptAt,
    leaseUntil,
    leasedBy,
    lastFailureJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsOutboxData &&
          other.sequence == this.sequence &&
          other.entity == this.entity &&
          $driftBlobEquality.equals(other.keyHash, this.keyHash) &&
          other.keyJson == this.keyJson &&
          other.kind == this.kind &&
          other.rowJson == this.rowJson &&
          other.deltaJson == this.deltaJson &&
          other.state == this.state &&
          other.deliveredMaybe == this.deliveredMaybe &&
          other.attempts == this.attempts &&
          other.failures == this.failures &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.leaseUntil == this.leaseUntil &&
          other.leasedBy == this.leasedBy &&
          other.lastFailureJson == this.lastFailureJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UsOutboxCompanion extends UpdateCompanion<UsOutboxData> {
  final Value<int> sequence;
  final Value<String> entity;
  final Value<Uint8List> keyHash;
  final Value<String> keyJson;
  final Value<String> kind;
  final Value<String?> rowJson;
  final Value<String?> deltaJson;
  final Value<String> state;
  final Value<int> deliveredMaybe;
  final Value<int> attempts;
  final Value<int> failures;
  final Value<int> nextAttemptAt;
  final Value<int?> leaseUntil;
  final Value<String?> leasedBy;
  final Value<String?> lastFailureJson;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const UsOutboxCompanion({
    this.sequence = const Value.absent(),
    this.entity = const Value.absent(),
    this.keyHash = const Value.absent(),
    this.keyJson = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowJson = const Value.absent(),
    this.deltaJson = const Value.absent(),
    this.state = const Value.absent(),
    this.deliveredMaybe = const Value.absent(),
    this.attempts = const Value.absent(),
    this.failures = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.leasedBy = const Value.absent(),
    this.lastFailureJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UsOutboxCompanion.insert({
    this.sequence = const Value.absent(),
    required String entity,
    required Uint8List keyHash,
    required String keyJson,
    required String kind,
    this.rowJson = const Value.absent(),
    this.deltaJson = const Value.absent(),
    required String state,
    this.deliveredMaybe = const Value.absent(),
    this.attempts = const Value.absent(),
    this.failures = const Value.absent(),
    required int nextAttemptAt,
    this.leaseUntil = const Value.absent(),
    this.leasedBy = const Value.absent(),
    this.lastFailureJson = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : entity = Value(entity),
       keyHash = Value(keyHash),
       keyJson = Value(keyJson),
       kind = Value(kind),
       state = Value(state),
       nextAttemptAt = Value(nextAttemptAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UsOutboxData> custom({
    Expression<int>? sequence,
    Expression<String>? entity,
    Expression<Uint8List>? keyHash,
    Expression<String>? keyJson,
    Expression<String>? kind,
    Expression<String>? rowJson,
    Expression<String>? deltaJson,
    Expression<String>? state,
    Expression<int>? deliveredMaybe,
    Expression<int>? attempts,
    Expression<int>? failures,
    Expression<int>? nextAttemptAt,
    Expression<int>? leaseUntil,
    Expression<String>? leasedBy,
    Expression<String>? lastFailureJson,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (sequence != null) 'sequence': sequence,
      if (entity != null) 'entity': entity,
      if (keyHash != null) 'key_hash': keyHash,
      if (keyJson != null) 'key_json': keyJson,
      if (kind != null) 'kind': kind,
      if (rowJson != null) 'row_json': rowJson,
      if (deltaJson != null) 'delta_json': deltaJson,
      if (state != null) 'state': state,
      if (deliveredMaybe != null) 'delivered_maybe': deliveredMaybe,
      if (attempts != null) 'attempts': attempts,
      if (failures != null) 'failures': failures,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (leasedBy != null) 'leased_by': leasedBy,
      if (lastFailureJson != null) 'last_failure_json': lastFailureJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UsOutboxCompanion copyWith({
    Value<int>? sequence,
    Value<String>? entity,
    Value<Uint8List>? keyHash,
    Value<String>? keyJson,
    Value<String>? kind,
    Value<String?>? rowJson,
    Value<String?>? deltaJson,
    Value<String>? state,
    Value<int>? deliveredMaybe,
    Value<int>? attempts,
    Value<int>? failures,
    Value<int>? nextAttemptAt,
    Value<int?>? leaseUntil,
    Value<String?>? leasedBy,
    Value<String?>? lastFailureJson,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return UsOutboxCompanion(
      sequence: sequence ?? this.sequence,
      entity: entity ?? this.entity,
      keyHash: keyHash ?? this.keyHash,
      keyJson: keyJson ?? this.keyJson,
      kind: kind ?? this.kind,
      rowJson: rowJson ?? this.rowJson,
      deltaJson: deltaJson ?? this.deltaJson,
      state: state ?? this.state,
      deliveredMaybe: deliveredMaybe ?? this.deliveredMaybe,
      attempts: attempts ?? this.attempts,
      failures: failures ?? this.failures,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      leasedBy: leasedBy ?? this.leasedBy,
      lastFailureJson: lastFailureJson ?? this.lastFailureJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (keyHash.present) {
      map['key_hash'] = Variable<Uint8List>(keyHash.value);
    }
    if (keyJson.present) {
      map['key_json'] = Variable<String>(keyJson.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rowJson.present) {
      map['row_json'] = Variable<String>(rowJson.value);
    }
    if (deltaJson.present) {
      map['delta_json'] = Variable<String>(deltaJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (deliveredMaybe.present) {
      map['delivered_maybe'] = Variable<int>(deliveredMaybe.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (failures.present) {
      map['failures'] = Variable<int>(failures.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<int>(nextAttemptAt.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<int>(leaseUntil.value);
    }
    if (leasedBy.present) {
      map['leased_by'] = Variable<String>(leasedBy.value);
    }
    if (lastFailureJson.present) {
      map['last_failure_json'] = Variable<String>(lastFailureJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsOutboxCompanion(')
          ..write('sequence: $sequence, ')
          ..write('entity: $entity, ')
          ..write('keyHash: $keyHash, ')
          ..write('keyJson: $keyJson, ')
          ..write('kind: $kind, ')
          ..write('rowJson: $rowJson, ')
          ..write('deltaJson: $deltaJson, ')
          ..write('state: $state, ')
          ..write('deliveredMaybe: $deliveredMaybe, ')
          ..write('attempts: $attempts, ')
          ..write('failures: $failures, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('leasedBy: $leasedBy, ')
          ..write('lastFailureJson: $lastFailureJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $UsCursorsTable extends UsCursors with TableInfo<$UsCursorsTable, UsCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorJsonMeta = const VerificationMeta(
    'cursorJson',
  );
  @override
  late final GeneratedColumn<String> cursorJson = GeneratedColumn<String>(
    'cursor_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entity, cursorJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'us_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('cursor_json')) {
      context.handle(
        _cursorJsonMeta,
        cursorJson.isAcceptableOrUnknown(data['cursor_json']!, _cursorJsonMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity};
  @override
  UsCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsCursor(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      cursorJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor_json'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UsCursorsTable createAlias(String alias) {
    return $UsCursorsTable(attachedDatabase, alias);
  }
}

class UsCursor extends DataClass implements Insertable<UsCursor> {
  final String entity;
  final String? cursorJson;
  final int updatedAt;
  const UsCursor({
    required this.entity,
    this.cursorJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    if (!nullToAbsent || cursorJson != null) {
      map['cursor_json'] = Variable<String>(cursorJson);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  UsCursorsCompanion toCompanion(bool nullToAbsent) {
    return UsCursorsCompanion(
      entity: Value(entity),
      cursorJson: cursorJson == null && nullToAbsent ? const Value.absent() : Value(cursorJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory UsCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsCursor(
      entity: serializer.fromJson<String>(json['entity']),
      cursorJson: serializer.fromJson<String?>(json['cursorJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'cursorJson': serializer.toJson<String?>(cursorJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  UsCursor copyWith({
    String? entity,
    Value<String?> cursorJson = const Value.absent(),
    int? updatedAt,
  }) => UsCursor(
    entity: entity ?? this.entity,
    cursorJson: cursorJson.present ? cursorJson.value : this.cursorJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UsCursor copyWithCompanion(UsCursorsCompanion data) {
    return UsCursor(
      entity: data.entity.present ? data.entity.value : this.entity,
      cursorJson: data.cursorJson.present ? data.cursorJson.value : this.cursorJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsCursor(')
          ..write('entity: $entity, ')
          ..write('cursorJson: $cursorJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, cursorJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsCursor &&
          other.entity == this.entity &&
          other.cursorJson == this.cursorJson &&
          other.updatedAt == this.updatedAt);
}

class UsCursorsCompanion extends UpdateCompanion<UsCursor> {
  final Value<String> entity;
  final Value<String?> cursorJson;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const UsCursorsCompanion({
    this.entity = const Value.absent(),
    this.cursorJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsCursorsCompanion.insert({
    required String entity,
    this.cursorJson = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       updatedAt = Value(updatedAt);
  static Insertable<UsCursor> custom({
    Expression<String>? entity,
    Expression<String>? cursorJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (cursorJson != null) 'cursor_json': cursorJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsCursorsCompanion copyWith({
    Value<String>? entity,
    Value<String?>? cursorJson,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return UsCursorsCompanion(
      entity: entity ?? this.entity,
      cursorJson: cursorJson ?? this.cursorJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (cursorJson.present) {
      map['cursor_json'] = Variable<String>(cursorJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsCursorsCompanion(')
          ..write('entity: $entity, ')
          ..write('cursorJson: $cursorJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsTombstonesTable extends UsTombstones with TableInfo<$UsTombstonesTable, UsTombstone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsTombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyHashMeta = const VerificationMeta(
    'keyHash',
  );
  @override
  late final GeneratedColumn<Uint8List> keyHash = GeneratedColumn<Uint8List>(
    'key_hash',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyJsonMeta = const VerificationMeta(
    'keyJson',
  );
  @override
  late final GeneratedColumn<String> keyJson = GeneratedColumn<String>(
    'key_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ackedAtMeta = const VerificationMeta(
    'ackedAt',
  );
  @override
  late final GeneratedColumn<int> ackedAt = GeneratedColumn<int>(
    'acked_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entity,
    keyHash,
    keyJson,
    source,
    deletedAt,
    ackedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'us_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsTombstone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('key_hash')) {
      context.handle(
        _keyHashMeta,
        keyHash.isAcceptableOrUnknown(data['key_hash']!, _keyHashMeta),
      );
    } else if (isInserting) {
      context.missing(_keyHashMeta);
    }
    if (data.containsKey('key_json')) {
      context.handle(
        _keyJsonMeta,
        keyJson.isAcceptableOrUnknown(data['key_json']!, _keyJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_keyJsonMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    if (data.containsKey('acked_at')) {
      context.handle(
        _ackedAtMeta,
        ackedAt.isAcceptableOrUnknown(data['acked_at']!, _ackedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, keyHash};
  @override
  UsTombstone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsTombstone(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      keyHash: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}key_hash'],
      )!,
      keyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_json'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      )!,
      ackedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acked_at'],
      ),
    );
  }

  @override
  $UsTombstonesTable createAlias(String alias) {
    return $UsTombstonesTable(attachedDatabase, alias);
  }
}

class UsTombstone extends DataClass implements Insertable<UsTombstone> {
  final String entity;
  final Uint8List keyHash;
  final String keyJson;

  /// `local` | `remote`.
  final String source;
  final int deletedAt;
  final int? ackedAt;
  const UsTombstone({
    required this.entity,
    required this.keyHash,
    required this.keyJson,
    required this.source,
    required this.deletedAt,
    this.ackedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['key_hash'] = Variable<Uint8List>(keyHash);
    map['key_json'] = Variable<String>(keyJson);
    map['source'] = Variable<String>(source);
    map['deleted_at'] = Variable<int>(deletedAt);
    if (!nullToAbsent || ackedAt != null) {
      map['acked_at'] = Variable<int>(ackedAt);
    }
    return map;
  }

  UsTombstonesCompanion toCompanion(bool nullToAbsent) {
    return UsTombstonesCompanion(
      entity: Value(entity),
      keyHash: Value(keyHash),
      keyJson: Value(keyJson),
      source: Value(source),
      deletedAt: Value(deletedAt),
      ackedAt: ackedAt == null && nullToAbsent ? const Value.absent() : Value(ackedAt),
    );
  }

  factory UsTombstone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsTombstone(
      entity: serializer.fromJson<String>(json['entity']),
      keyHash: serializer.fromJson<Uint8List>(json['keyHash']),
      keyJson: serializer.fromJson<String>(json['keyJson']),
      source: serializer.fromJson<String>(json['source']),
      deletedAt: serializer.fromJson<int>(json['deletedAt']),
      ackedAt: serializer.fromJson<int?>(json['ackedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'keyHash': serializer.toJson<Uint8List>(keyHash),
      'keyJson': serializer.toJson<String>(keyJson),
      'source': serializer.toJson<String>(source),
      'deletedAt': serializer.toJson<int>(deletedAt),
      'ackedAt': serializer.toJson<int?>(ackedAt),
    };
  }

  UsTombstone copyWith({
    String? entity,
    Uint8List? keyHash,
    String? keyJson,
    String? source,
    int? deletedAt,
    Value<int?> ackedAt = const Value.absent(),
  }) => UsTombstone(
    entity: entity ?? this.entity,
    keyHash: keyHash ?? this.keyHash,
    keyJson: keyJson ?? this.keyJson,
    source: source ?? this.source,
    deletedAt: deletedAt ?? this.deletedAt,
    ackedAt: ackedAt.present ? ackedAt.value : this.ackedAt,
  );
  UsTombstone copyWithCompanion(UsTombstonesCompanion data) {
    return UsTombstone(
      entity: data.entity.present ? data.entity.value : this.entity,
      keyHash: data.keyHash.present ? data.keyHash.value : this.keyHash,
      keyJson: data.keyJson.present ? data.keyJson.value : this.keyJson,
      source: data.source.present ? data.source.value : this.source,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ackedAt: data.ackedAt.present ? data.ackedAt.value : this.ackedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsTombstone(')
          ..write('entity: $entity, ')
          ..write('keyHash: $keyHash, ')
          ..write('keyJson: $keyJson, ')
          ..write('source: $source, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ackedAt: $ackedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entity,
    $driftBlobEquality.hash(keyHash),
    keyJson,
    source,
    deletedAt,
    ackedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsTombstone &&
          other.entity == this.entity &&
          $driftBlobEquality.equals(other.keyHash, this.keyHash) &&
          other.keyJson == this.keyJson &&
          other.source == this.source &&
          other.deletedAt == this.deletedAt &&
          other.ackedAt == this.ackedAt);
}

class UsTombstonesCompanion extends UpdateCompanion<UsTombstone> {
  final Value<String> entity;
  final Value<Uint8List> keyHash;
  final Value<String> keyJson;
  final Value<String> source;
  final Value<int> deletedAt;
  final Value<int?> ackedAt;
  final Value<int> rowid;
  const UsTombstonesCompanion({
    this.entity = const Value.absent(),
    this.keyHash = const Value.absent(),
    this.keyJson = const Value.absent(),
    this.source = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ackedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsTombstonesCompanion.insert({
    required String entity,
    required Uint8List keyHash,
    required String keyJson,
    required String source,
    required int deletedAt,
    this.ackedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       keyHash = Value(keyHash),
       keyJson = Value(keyJson),
       source = Value(source),
       deletedAt = Value(deletedAt);
  static Insertable<UsTombstone> custom({
    Expression<String>? entity,
    Expression<Uint8List>? keyHash,
    Expression<String>? keyJson,
    Expression<String>? source,
    Expression<int>? deletedAt,
    Expression<int>? ackedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (keyHash != null) 'key_hash': keyHash,
      if (keyJson != null) 'key_json': keyJson,
      if (source != null) 'source': source,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ackedAt != null) 'acked_at': ackedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsTombstonesCompanion copyWith({
    Value<String>? entity,
    Value<Uint8List>? keyHash,
    Value<String>? keyJson,
    Value<String>? source,
    Value<int>? deletedAt,
    Value<int?>? ackedAt,
    Value<int>? rowid,
  }) {
    return UsTombstonesCompanion(
      entity: entity ?? this.entity,
      keyHash: keyHash ?? this.keyHash,
      keyJson: keyJson ?? this.keyJson,
      source: source ?? this.source,
      deletedAt: deletedAt ?? this.deletedAt,
      ackedAt: ackedAt ?? this.ackedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (keyHash.present) {
      map['key_hash'] = Variable<Uint8List>(keyHash.value);
    }
    if (keyJson.present) {
      map['key_json'] = Variable<String>(keyJson.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (ackedAt.present) {
      map['acked_at'] = Variable<int>(ackedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsTombstonesCompanion(')
          ..write('entity: $entity, ')
          ..write('keyHash: $keyHash, ')
          ..write('keyJson: $keyJson, ')
          ..write('source: $source, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ackedAt: $ackedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsConflictsTable extends UsConflicts with TableInfo<$UsConflictsTable, UsConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsConflictsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyHashMeta = const VerificationMeta(
    'keyHash',
  );
  @override
  late final GeneratedColumn<Uint8List> keyHash = GeneratedColumn<Uint8List>(
    'key_hash',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyJsonMeta = const VerificationMeta(
    'keyJson',
  );
  @override
  late final GeneratedColumn<String> keyJson = GeneratedColumn<String>(
    'key_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localJsonMeta = const VerificationMeta(
    'localJson',
  );
  @override
  late final GeneratedColumn<String> localJson = GeneratedColumn<String>(
    'local_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteJsonMeta = const VerificationMeta(
    'remoteJson',
  );
  @override
  late final GeneratedColumn<String> remoteJson = GeneratedColumn<String>(
    'remote_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localStatusMeta = const VerificationMeta(
    'localStatus',
  );
  @override
  late final GeneratedColumn<String> localStatus = GeneratedColumn<String>(
    'local_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detectedAtMeta = const VerificationMeta(
    'detectedAt',
  );
  @override
  late final GeneratedColumn<int> detectedAt = GeneratedColumn<int>(
    'detected_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<int> resolvedAt = GeneratedColumn<int>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entity,
    keyHash,
    keyJson,
    localJson,
    remoteJson,
    localStatus,
    detectedAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'us_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('key_hash')) {
      context.handle(
        _keyHashMeta,
        keyHash.isAcceptableOrUnknown(data['key_hash']!, _keyHashMeta),
      );
    } else if (isInserting) {
      context.missing(_keyHashMeta);
    }
    if (data.containsKey('key_json')) {
      context.handle(
        _keyJsonMeta,
        keyJson.isAcceptableOrUnknown(data['key_json']!, _keyJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_keyJsonMeta);
    }
    if (data.containsKey('local_json')) {
      context.handle(
        _localJsonMeta,
        localJson.isAcceptableOrUnknown(data['local_json']!, _localJsonMeta),
      );
    }
    if (data.containsKey('remote_json')) {
      context.handle(
        _remoteJsonMeta,
        remoteJson.isAcceptableOrUnknown(data['remote_json']!, _remoteJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteJsonMeta);
    }
    if (data.containsKey('local_status')) {
      context.handle(
        _localStatusMeta,
        localStatus.isAcceptableOrUnknown(
          data['local_status']!,
          _localStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localStatusMeta);
    }
    if (data.containsKey('detected_at')) {
      context.handle(
        _detectedAtMeta,
        detectedAt.isAcceptableOrUnknown(data['detected_at']!, _detectedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UsConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsConflict(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      keyHash: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}key_hash'],
      )!,
      keyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_json'],
      )!,
      localJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_json'],
      ),
      remoteJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_json'],
      )!,
      localStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_status'],
      )!,
      detectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detected_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $UsConflictsTable createAlias(String alias) {
    return $UsConflictsTable(attachedDatabase, alias);
  }
}

class UsConflict extends DataClass implements Insertable<UsConflict> {
  final int id;
  final String entity;
  final Uint8List keyHash;
  final String keyJson;
  final String? localJson;
  final String remoteJson;
  final String localStatus;
  final int detectedAt;
  final int? resolvedAt;
  const UsConflict({
    required this.id,
    required this.entity,
    required this.keyHash,
    required this.keyJson,
    this.localJson,
    required this.remoteJson,
    required this.localStatus,
    required this.detectedAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity'] = Variable<String>(entity);
    map['key_hash'] = Variable<Uint8List>(keyHash);
    map['key_json'] = Variable<String>(keyJson);
    if (!nullToAbsent || localJson != null) {
      map['local_json'] = Variable<String>(localJson);
    }
    map['remote_json'] = Variable<String>(remoteJson);
    map['local_status'] = Variable<String>(localStatus);
    map['detected_at'] = Variable<int>(detectedAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<int>(resolvedAt);
    }
    return map;
  }

  UsConflictsCompanion toCompanion(bool nullToAbsent) {
    return UsConflictsCompanion(
      id: Value(id),
      entity: Value(entity),
      keyHash: Value(keyHash),
      keyJson: Value(keyJson),
      localJson: localJson == null && nullToAbsent ? const Value.absent() : Value(localJson),
      remoteJson: Value(remoteJson),
      localStatus: Value(localStatus),
      detectedAt: Value(detectedAt),
      resolvedAt: resolvedAt == null && nullToAbsent ? const Value.absent() : Value(resolvedAt),
    );
  }

  factory UsConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsConflict(
      id: serializer.fromJson<int>(json['id']),
      entity: serializer.fromJson<String>(json['entity']),
      keyHash: serializer.fromJson<Uint8List>(json['keyHash']),
      keyJson: serializer.fromJson<String>(json['keyJson']),
      localJson: serializer.fromJson<String?>(json['localJson']),
      remoteJson: serializer.fromJson<String>(json['remoteJson']),
      localStatus: serializer.fromJson<String>(json['localStatus']),
      detectedAt: serializer.fromJson<int>(json['detectedAt']),
      resolvedAt: serializer.fromJson<int?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entity': serializer.toJson<String>(entity),
      'keyHash': serializer.toJson<Uint8List>(keyHash),
      'keyJson': serializer.toJson<String>(keyJson),
      'localJson': serializer.toJson<String?>(localJson),
      'remoteJson': serializer.toJson<String>(remoteJson),
      'localStatus': serializer.toJson<String>(localStatus),
      'detectedAt': serializer.toJson<int>(detectedAt),
      'resolvedAt': serializer.toJson<int?>(resolvedAt),
    };
  }

  UsConflict copyWith({
    int? id,
    String? entity,
    Uint8List? keyHash,
    String? keyJson,
    Value<String?> localJson = const Value.absent(),
    String? remoteJson,
    String? localStatus,
    int? detectedAt,
    Value<int?> resolvedAt = const Value.absent(),
  }) => UsConflict(
    id: id ?? this.id,
    entity: entity ?? this.entity,
    keyHash: keyHash ?? this.keyHash,
    keyJson: keyJson ?? this.keyJson,
    localJson: localJson.present ? localJson.value : this.localJson,
    remoteJson: remoteJson ?? this.remoteJson,
    localStatus: localStatus ?? this.localStatus,
    detectedAt: detectedAt ?? this.detectedAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  UsConflict copyWithCompanion(UsConflictsCompanion data) {
    return UsConflict(
      id: data.id.present ? data.id.value : this.id,
      entity: data.entity.present ? data.entity.value : this.entity,
      keyHash: data.keyHash.present ? data.keyHash.value : this.keyHash,
      keyJson: data.keyJson.present ? data.keyJson.value : this.keyJson,
      localJson: data.localJson.present ? data.localJson.value : this.localJson,
      remoteJson: data.remoteJson.present ? data.remoteJson.value : this.remoteJson,
      localStatus: data.localStatus.present ? data.localStatus.value : this.localStatus,
      detectedAt: data.detectedAt.present ? data.detectedAt.value : this.detectedAt,
      resolvedAt: data.resolvedAt.present ? data.resolvedAt.value : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsConflict(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('keyHash: $keyHash, ')
          ..write('keyJson: $keyJson, ')
          ..write('localJson: $localJson, ')
          ..write('remoteJson: $remoteJson, ')
          ..write('localStatus: $localStatus, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entity,
    $driftBlobEquality.hash(keyHash),
    keyJson,
    localJson,
    remoteJson,
    localStatus,
    detectedAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsConflict &&
          other.id == this.id &&
          other.entity == this.entity &&
          $driftBlobEquality.equals(other.keyHash, this.keyHash) &&
          other.keyJson == this.keyJson &&
          other.localJson == this.localJson &&
          other.remoteJson == this.remoteJson &&
          other.localStatus == this.localStatus &&
          other.detectedAt == this.detectedAt &&
          other.resolvedAt == this.resolvedAt);
}

class UsConflictsCompanion extends UpdateCompanion<UsConflict> {
  final Value<int> id;
  final Value<String> entity;
  final Value<Uint8List> keyHash;
  final Value<String> keyJson;
  final Value<String?> localJson;
  final Value<String> remoteJson;
  final Value<String> localStatus;
  final Value<int> detectedAt;
  final Value<int?> resolvedAt;
  const UsConflictsCompanion({
    this.id = const Value.absent(),
    this.entity = const Value.absent(),
    this.keyHash = const Value.absent(),
    this.keyJson = const Value.absent(),
    this.localJson = const Value.absent(),
    this.remoteJson = const Value.absent(),
    this.localStatus = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  });
  UsConflictsCompanion.insert({
    this.id = const Value.absent(),
    required String entity,
    required Uint8List keyHash,
    required String keyJson,
    this.localJson = const Value.absent(),
    required String remoteJson,
    required String localStatus,
    required int detectedAt,
    this.resolvedAt = const Value.absent(),
  }) : entity = Value(entity),
       keyHash = Value(keyHash),
       keyJson = Value(keyJson),
       remoteJson = Value(remoteJson),
       localStatus = Value(localStatus),
       detectedAt = Value(detectedAt);
  static Insertable<UsConflict> custom({
    Expression<int>? id,
    Expression<String>? entity,
    Expression<Uint8List>? keyHash,
    Expression<String>? keyJson,
    Expression<String>? localJson,
    Expression<String>? remoteJson,
    Expression<String>? localStatus,
    Expression<int>? detectedAt,
    Expression<int>? resolvedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entity != null) 'entity': entity,
      if (keyHash != null) 'key_hash': keyHash,
      if (keyJson != null) 'key_json': keyJson,
      if (localJson != null) 'local_json': localJson,
      if (remoteJson != null) 'remote_json': remoteJson,
      if (localStatus != null) 'local_status': localStatus,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
    });
  }

  UsConflictsCompanion copyWith({
    Value<int>? id,
    Value<String>? entity,
    Value<Uint8List>? keyHash,
    Value<String>? keyJson,
    Value<String?>? localJson,
    Value<String>? remoteJson,
    Value<String>? localStatus,
    Value<int>? detectedAt,
    Value<int?>? resolvedAt,
  }) {
    return UsConflictsCompanion(
      id: id ?? this.id,
      entity: entity ?? this.entity,
      keyHash: keyHash ?? this.keyHash,
      keyJson: keyJson ?? this.keyJson,
      localJson: localJson ?? this.localJson,
      remoteJson: remoteJson ?? this.remoteJson,
      localStatus: localStatus ?? this.localStatus,
      detectedAt: detectedAt ?? this.detectedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (keyHash.present) {
      map['key_hash'] = Variable<Uint8List>(keyHash.value);
    }
    if (keyJson.present) {
      map['key_json'] = Variable<String>(keyJson.value);
    }
    if (localJson.present) {
      map['local_json'] = Variable<String>(localJson.value);
    }
    if (remoteJson.present) {
      map['remote_json'] = Variable<String>(remoteJson.value);
    }
    if (localStatus.present) {
      map['local_status'] = Variable<String>(localStatus.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<int>(detectedAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<int>(resolvedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsConflictsCompanion(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('keyHash: $keyHash, ')
          ..write('keyJson: $keyJson, ')
          ..write('localJson: $localJson, ')
          ..write('remoteJson: $remoteJson, ')
          ..write('localStatus: $localStatus, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }
}

class $UsDeadLettersTable extends UsDeadLetters with TableInfo<$UsDeadLettersTable, UsDeadLetter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsDeadLettersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyHashMeta = const VerificationMeta(
    'keyHash',
  );
  @override
  late final GeneratedColumn<Uint8List> keyHash = GeneratedColumn<Uint8List>(
    'key_hash',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyJsonMeta = const VerificationMeta(
    'keyJson',
  );
  @override
  late final GeneratedColumn<String> keyJson = GeneratedColumn<String>(
    'key_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureJsonMeta = const VerificationMeta(
    'failureJson',
  );
  @override
  late final GeneratedColumn<String> failureJson = GeneratedColumn<String>(
    'failure_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failedAtMeta = const VerificationMeta(
    'failedAt',
  );
  @override
  late final GeneratedColumn<int> failedAt = GeneratedColumn<int>(
    'failed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sequence,
    entity,
    keyHash,
    keyJson,
    kind,
    payloadJson,
    failureJson,
    failedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'us_dead_letters';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsDeadLetter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('key_hash')) {
      context.handle(
        _keyHashMeta,
        keyHash.isAcceptableOrUnknown(data['key_hash']!, _keyHashMeta),
      );
    } else if (isInserting) {
      context.missing(_keyHashMeta);
    }
    if (data.containsKey('key_json')) {
      context.handle(
        _keyJsonMeta,
        keyJson.isAcceptableOrUnknown(data['key_json']!, _keyJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_keyJsonMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('failure_json')) {
      context.handle(
        _failureJsonMeta,
        failureJson.isAcceptableOrUnknown(
          data['failure_json']!,
          _failureJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_failureJsonMeta);
    }
    if (data.containsKey('failed_at')) {
      context.handle(
        _failedAtMeta,
        failedAt.isAcceptableOrUnknown(data['failed_at']!, _failedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_failedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sequence};
  @override
  UsDeadLetter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsDeadLetter(
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      keyHash: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}key_hash'],
      )!,
      keyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_json'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      failureJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_json'],
      )!,
      failedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_at'],
      )!,
    );
  }

  @override
  $UsDeadLettersTable createAlias(String alias) {
    return $UsDeadLettersTable(attachedDatabase, alias);
  }
}

class UsDeadLetter extends DataClass implements Insertable<UsDeadLetter> {
  final int sequence;
  final String entity;
  final Uint8List keyHash;
  final String keyJson;
  final String kind;
  final String? payloadJson;
  final String failureJson;
  final int failedAt;
  const UsDeadLetter({
    required this.sequence,
    required this.entity,
    required this.keyHash,
    required this.keyJson,
    required this.kind,
    this.payloadJson,
    required this.failureJson,
    required this.failedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sequence'] = Variable<int>(sequence);
    map['entity'] = Variable<String>(entity);
    map['key_hash'] = Variable<Uint8List>(keyHash);
    map['key_json'] = Variable<String>(keyJson);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['failure_json'] = Variable<String>(failureJson);
    map['failed_at'] = Variable<int>(failedAt);
    return map;
  }

  UsDeadLettersCompanion toCompanion(bool nullToAbsent) {
    return UsDeadLettersCompanion(
      sequence: Value(sequence),
      entity: Value(entity),
      keyHash: Value(keyHash),
      keyJson: Value(keyJson),
      kind: Value(kind),
      payloadJson: payloadJson == null && nullToAbsent ? const Value.absent() : Value(payloadJson),
      failureJson: Value(failureJson),
      failedAt: Value(failedAt),
    );
  }

  factory UsDeadLetter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsDeadLetter(
      sequence: serializer.fromJson<int>(json['sequence']),
      entity: serializer.fromJson<String>(json['entity']),
      keyHash: serializer.fromJson<Uint8List>(json['keyHash']),
      keyJson: serializer.fromJson<String>(json['keyJson']),
      kind: serializer.fromJson<String>(json['kind']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      failureJson: serializer.fromJson<String>(json['failureJson']),
      failedAt: serializer.fromJson<int>(json['failedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sequence': serializer.toJson<int>(sequence),
      'entity': serializer.toJson<String>(entity),
      'keyHash': serializer.toJson<Uint8List>(keyHash),
      'keyJson': serializer.toJson<String>(keyJson),
      'kind': serializer.toJson<String>(kind),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'failureJson': serializer.toJson<String>(failureJson),
      'failedAt': serializer.toJson<int>(failedAt),
    };
  }

  UsDeadLetter copyWith({
    int? sequence,
    String? entity,
    Uint8List? keyHash,
    String? keyJson,
    String? kind,
    Value<String?> payloadJson = const Value.absent(),
    String? failureJson,
    int? failedAt,
  }) => UsDeadLetter(
    sequence: sequence ?? this.sequence,
    entity: entity ?? this.entity,
    keyHash: keyHash ?? this.keyHash,
    keyJson: keyJson ?? this.keyJson,
    kind: kind ?? this.kind,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    failureJson: failureJson ?? this.failureJson,
    failedAt: failedAt ?? this.failedAt,
  );
  UsDeadLetter copyWithCompanion(UsDeadLettersCompanion data) {
    return UsDeadLetter(
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      entity: data.entity.present ? data.entity.value : this.entity,
      keyHash: data.keyHash.present ? data.keyHash.value : this.keyHash,
      keyJson: data.keyJson.present ? data.keyJson.value : this.keyJson,
      kind: data.kind.present ? data.kind.value : this.kind,
      payloadJson: data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      failureJson: data.failureJson.present ? data.failureJson.value : this.failureJson,
      failedAt: data.failedAt.present ? data.failedAt.value : this.failedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsDeadLetter(')
          ..write('sequence: $sequence, ')
          ..write('entity: $entity, ')
          ..write('keyHash: $keyHash, ')
          ..write('keyJson: $keyJson, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('failureJson: $failureJson, ')
          ..write('failedAt: $failedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sequence,
    entity,
    $driftBlobEquality.hash(keyHash),
    keyJson,
    kind,
    payloadJson,
    failureJson,
    failedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsDeadLetter &&
          other.sequence == this.sequence &&
          other.entity == this.entity &&
          $driftBlobEquality.equals(other.keyHash, this.keyHash) &&
          other.keyJson == this.keyJson &&
          other.kind == this.kind &&
          other.payloadJson == this.payloadJson &&
          other.failureJson == this.failureJson &&
          other.failedAt == this.failedAt);
}

class UsDeadLettersCompanion extends UpdateCompanion<UsDeadLetter> {
  final Value<int> sequence;
  final Value<String> entity;
  final Value<Uint8List> keyHash;
  final Value<String> keyJson;
  final Value<String> kind;
  final Value<String?> payloadJson;
  final Value<String> failureJson;
  final Value<int> failedAt;
  const UsDeadLettersCompanion({
    this.sequence = const Value.absent(),
    this.entity = const Value.absent(),
    this.keyHash = const Value.absent(),
    this.keyJson = const Value.absent(),
    this.kind = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.failureJson = const Value.absent(),
    this.failedAt = const Value.absent(),
  });
  UsDeadLettersCompanion.insert({
    this.sequence = const Value.absent(),
    required String entity,
    required Uint8List keyHash,
    required String keyJson,
    required String kind,
    this.payloadJson = const Value.absent(),
    required String failureJson,
    required int failedAt,
  }) : entity = Value(entity),
       keyHash = Value(keyHash),
       keyJson = Value(keyJson),
       kind = Value(kind),
       failureJson = Value(failureJson),
       failedAt = Value(failedAt);
  static Insertable<UsDeadLetter> custom({
    Expression<int>? sequence,
    Expression<String>? entity,
    Expression<Uint8List>? keyHash,
    Expression<String>? keyJson,
    Expression<String>? kind,
    Expression<String>? payloadJson,
    Expression<String>? failureJson,
    Expression<int>? failedAt,
  }) {
    return RawValuesInsertable({
      if (sequence != null) 'sequence': sequence,
      if (entity != null) 'entity': entity,
      if (keyHash != null) 'key_hash': keyHash,
      if (keyJson != null) 'key_json': keyJson,
      if (kind != null) 'kind': kind,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (failureJson != null) 'failure_json': failureJson,
      if (failedAt != null) 'failed_at': failedAt,
    });
  }

  UsDeadLettersCompanion copyWith({
    Value<int>? sequence,
    Value<String>? entity,
    Value<Uint8List>? keyHash,
    Value<String>? keyJson,
    Value<String>? kind,
    Value<String?>? payloadJson,
    Value<String>? failureJson,
    Value<int>? failedAt,
  }) {
    return UsDeadLettersCompanion(
      sequence: sequence ?? this.sequence,
      entity: entity ?? this.entity,
      keyHash: keyHash ?? this.keyHash,
      keyJson: keyJson ?? this.keyJson,
      kind: kind ?? this.kind,
      payloadJson: payloadJson ?? this.payloadJson,
      failureJson: failureJson ?? this.failureJson,
      failedAt: failedAt ?? this.failedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (keyHash.present) {
      map['key_hash'] = Variable<Uint8List>(keyHash.value);
    }
    if (keyJson.present) {
      map['key_json'] = Variable<String>(keyJson.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (failureJson.present) {
      map['failure_json'] = Variable<String>(failureJson.value);
    }
    if (failedAt.present) {
      map['failed_at'] = Variable<int>(failedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsDeadLettersCompanion(')
          ..write('sequence: $sequence, ')
          ..write('entity: $entity, ')
          ..write('keyHash: $keyHash, ')
          ..write('keyJson: $keyJson, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('failureJson: $failureJson, ')
          ..write('failedAt: $failedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$SyncServiceDatabase extends GeneratedDatabase {
  _$SyncServiceDatabase(QueryExecutor e) : super(e);
  $SyncServiceDatabaseManager get managers => $SyncServiceDatabaseManager(this);
  late final $UsMetaTable usMeta = $UsMetaTable(this);
  late final $UsOutboxTable usOutbox = $UsOutboxTable(this);
  late final $UsCursorsTable usCursors = $UsCursorsTable(this);
  late final $UsTombstonesTable usTombstones = $UsTombstonesTable(this);
  late final $UsConflictsTable usConflicts = $UsConflictsTable(this);
  late final $UsDeadLettersTable usDeadLetters = $UsDeadLettersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    usMeta,
    usOutbox,
    usCursors,
    usTombstones,
    usConflicts,
    usDeadLetters,
  ];
}

typedef $$UsMetaTableCreateCompanionBuilder = UsMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$UsMetaTableUpdateCompanionBuilder = UsMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$UsMetaTableFilterComposer extends Composer<_$SyncServiceDatabase, $UsMetaTable> {
  $$UsMetaTableFilterComposer({
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

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsMetaTableOrderingComposer extends Composer<_$SyncServiceDatabase, $UsMetaTable> {
  $$UsMetaTableOrderingComposer({
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

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsMetaTableAnnotationComposer extends Composer<_$SyncServiceDatabase, $UsMetaTable> {
  $$UsMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$UsMetaTableTableManager
    extends
        RootTableManager<
          _$SyncServiceDatabase,
          $UsMetaTable,
          UsMetaData,
          $$UsMetaTableFilterComposer,
          $$UsMetaTableOrderingComposer,
          $$UsMetaTableAnnotationComposer,
          $$UsMetaTableCreateCompanionBuilder,
          $$UsMetaTableUpdateCompanionBuilder,
          (
            UsMetaData,
            BaseReferences<_$SyncServiceDatabase, $UsMetaTable, UsMetaData>,
          ),
          UsMetaData,
          PrefetchHooks Function()
        > {
  $$UsMetaTableTableManager(_$SyncServiceDatabase db, $UsMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$UsMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$UsMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$UsMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => UsMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => UsMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsMetaTable, UsMetaData>(table),
                  BaseReferences<_$SyncServiceDatabase, $UsMetaTable, UsMetaData>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$SyncServiceDatabase,
      $UsMetaTable,
      UsMetaData,
      $$UsMetaTableFilterComposer,
      $$UsMetaTableOrderingComposer,
      $$UsMetaTableAnnotationComposer,
      $$UsMetaTableCreateCompanionBuilder,
      $$UsMetaTableUpdateCompanionBuilder,
      (
        UsMetaData,
        BaseReferences<_$SyncServiceDatabase, $UsMetaTable, UsMetaData>,
      ),
      UsMetaData,
      PrefetchHooks Function()
    >;
typedef $$UsOutboxTableCreateCompanionBuilder = UsOutboxCompanion Function({
  Value<int> sequence,
  required String entity,
  required Uint8List keyHash,
  required String keyJson,
  required String kind,
  Value<String?> rowJson,
  Value<String?> deltaJson,
  required String state,
  Value<int> deliveredMaybe,
  Value<int> attempts,
  Value<int> failures,
  required int nextAttemptAt,
  Value<int?> leaseUntil,
  Value<String?> leasedBy,
  Value<String?> lastFailureJson,
  required int createdAt,
  required int updatedAt,
});
typedef $$UsOutboxTableUpdateCompanionBuilder = UsOutboxCompanion Function({
  Value<int> sequence,
  Value<String> entity,
  Value<Uint8List> keyHash,
  Value<String> keyJson,
  Value<String> kind,
  Value<String?> rowJson,
  Value<String?> deltaJson,
  Value<String> state,
  Value<int> deliveredMaybe,
  Value<int> attempts,
  Value<int> failures,
  Value<int> nextAttemptAt,
  Value<int?> leaseUntil,
  Value<String?> leasedBy,
  Value<String?> lastFailureJson,
  Value<int> createdAt,
  Value<int> updatedAt,
});

class $$UsOutboxTableFilterComposer extends Composer<_$SyncServiceDatabase, $UsOutboxTable> {
  $$UsOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get keyHash => $composableBuilder(
    column: $table.keyHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyJson => $composableBuilder(
    column: $table.keyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowJson => $composableBuilder(
    column: $table.rowJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deltaJson => $composableBuilder(
    column: $table.deltaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deliveredMaybe => $composableBuilder(
    column: $table.deliveredMaybe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failures => $composableBuilder(
    column: $table.failures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leasedBy => $composableBuilder(
    column: $table.leasedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastFailureJson => $composableBuilder(
    column: $table.lastFailureJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsOutboxTableOrderingComposer extends Composer<_$SyncServiceDatabase, $UsOutboxTable> {
  $$UsOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get keyHash => $composableBuilder(
    column: $table.keyHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyJson => $composableBuilder(
    column: $table.keyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowJson => $composableBuilder(
    column: $table.rowJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deltaJson => $composableBuilder(
    column: $table.deltaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deliveredMaybe => $composableBuilder(
    column: $table.deliveredMaybe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failures => $composableBuilder(
    column: $table.failures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leasedBy => $composableBuilder(
    column: $table.leasedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastFailureJson => $composableBuilder(
    column: $table.lastFailureJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsOutboxTableAnnotationComposer extends Composer<_$SyncServiceDatabase, $UsOutboxTable> {
  $$UsOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sequence => $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get entity => $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<Uint8List> get keyHash => $composableBuilder(column: $table.keyHash, builder: (column) => column);

  GeneratedColumn<String> get keyJson => $composableBuilder(column: $table.keyJson, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get rowJson => $composableBuilder(column: $table.rowJson, builder: (column) => column);

  GeneratedColumn<String> get deltaJson => $composableBuilder(column: $table.deltaJson, builder: (column) => column);

  GeneratedColumn<String> get state => $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get deliveredMaybe => $composableBuilder(
    column: $table.deliveredMaybe,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts => $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get failures => $composableBuilder(column: $table.failures, builder: (column) => column);

  GeneratedColumn<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leasedBy => $composableBuilder(column: $table.leasedBy, builder: (column) => column);

  GeneratedColumn<String> get lastFailureJson => $composableBuilder(
    column: $table.lastFailureJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UsOutboxTableTableManager
    extends
        RootTableManager<
          _$SyncServiceDatabase,
          $UsOutboxTable,
          UsOutboxData,
          $$UsOutboxTableFilterComposer,
          $$UsOutboxTableOrderingComposer,
          $$UsOutboxTableAnnotationComposer,
          $$UsOutboxTableCreateCompanionBuilder,
          $$UsOutboxTableUpdateCompanionBuilder,
          (
            UsOutboxData,
            BaseReferences<_$SyncServiceDatabase, $UsOutboxTable, UsOutboxData>,
          ),
          UsOutboxData,
          PrefetchHooks Function()
        > {
  $$UsOutboxTableTableManager(_$SyncServiceDatabase db, $UsOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$UsOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$UsOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$UsOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sequence = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<Uint8List> keyHash = const Value.absent(),
                Value<String> keyJson = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> rowJson = const Value.absent(),
                Value<String?> deltaJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> deliveredMaybe = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> failures = const Value.absent(),
                Value<int> nextAttemptAt = const Value.absent(),
                Value<int?> leaseUntil = const Value.absent(),
                Value<String?> leasedBy = const Value.absent(),
                Value<String?> lastFailureJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => UsOutboxCompanion(
                sequence: sequence,
                entity: entity,
                keyHash: keyHash,
                keyJson: keyJson,
                kind: kind,
                rowJson: rowJson,
                deltaJson: deltaJson,
                state: state,
                deliveredMaybe: deliveredMaybe,
                attempts: attempts,
                failures: failures,
                nextAttemptAt: nextAttemptAt,
                leaseUntil: leaseUntil,
                leasedBy: leasedBy,
                lastFailureJson: lastFailureJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> sequence = const Value.absent(),
                required String entity,
                required Uint8List keyHash,
                required String keyJson,
                required String kind,
                Value<String?> rowJson = const Value.absent(),
                Value<String?> deltaJson = const Value.absent(),
                required String state,
                Value<int> deliveredMaybe = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> failures = const Value.absent(),
                required int nextAttemptAt,
                Value<int?> leaseUntil = const Value.absent(),
                Value<String?> leasedBy = const Value.absent(),
                Value<String?> lastFailureJson = const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => UsOutboxCompanion.insert(
                sequence: sequence,
                entity: entity,
                keyHash: keyHash,
                keyJson: keyJson,
                kind: kind,
                rowJson: rowJson,
                deltaJson: deltaJson,
                state: state,
                deliveredMaybe: deliveredMaybe,
                attempts: attempts,
                failures: failures,
                nextAttemptAt: nextAttemptAt,
                leaseUntil: leaseUntil,
                leasedBy: leasedBy,
                lastFailureJson: lastFailureJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsOutboxTable, UsOutboxData>(table),
                  BaseReferences<_$SyncServiceDatabase, $UsOutboxTable, UsOutboxData>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$SyncServiceDatabase,
      $UsOutboxTable,
      UsOutboxData,
      $$UsOutboxTableFilterComposer,
      $$UsOutboxTableOrderingComposer,
      $$UsOutboxTableAnnotationComposer,
      $$UsOutboxTableCreateCompanionBuilder,
      $$UsOutboxTableUpdateCompanionBuilder,
      (
        UsOutboxData,
        BaseReferences<_$SyncServiceDatabase, $UsOutboxTable, UsOutboxData>,
      ),
      UsOutboxData,
      PrefetchHooks Function()
    >;
typedef $$UsCursorsTableCreateCompanionBuilder = UsCursorsCompanion Function({
  required String entity,
  Value<String?> cursorJson,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$UsCursorsTableUpdateCompanionBuilder = UsCursorsCompanion Function({
  Value<String> entity,
  Value<String?> cursorJson,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$UsCursorsTableFilterComposer extends Composer<_$SyncServiceDatabase, $UsCursorsTable> {
  $$UsCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursorJson => $composableBuilder(
    column: $table.cursorJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsCursorsTableOrderingComposer extends Composer<_$SyncServiceDatabase, $UsCursorsTable> {
  $$UsCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursorJson => $composableBuilder(
    column: $table.cursorJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsCursorsTableAnnotationComposer extends Composer<_$SyncServiceDatabase, $UsCursorsTable> {
  $$UsCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity => $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get cursorJson => $composableBuilder(
    column: $table.cursorJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UsCursorsTableTableManager
    extends
        RootTableManager<
          _$SyncServiceDatabase,
          $UsCursorsTable,
          UsCursor,
          $$UsCursorsTableFilterComposer,
          $$UsCursorsTableOrderingComposer,
          $$UsCursorsTableAnnotationComposer,
          $$UsCursorsTableCreateCompanionBuilder,
          $$UsCursorsTableUpdateCompanionBuilder,
          (
            UsCursor,
            BaseReferences<_$SyncServiceDatabase, $UsCursorsTable, UsCursor>,
          ),
          UsCursor,
          PrefetchHooks Function()
        > {
  $$UsCursorsTableTableManager(_$SyncServiceDatabase db, $UsCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$UsCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$UsCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$UsCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<String?> cursorJson = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsCursorsCompanion(
                entity: entity,
                cursorJson: cursorJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                Value<String?> cursorJson = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UsCursorsCompanion.insert(
                entity: entity,
                cursorJson: cursorJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsCursorsTable, UsCursor>(table),
                  BaseReferences<_$SyncServiceDatabase, $UsCursorsTable, UsCursor>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$SyncServiceDatabase,
      $UsCursorsTable,
      UsCursor,
      $$UsCursorsTableFilterComposer,
      $$UsCursorsTableOrderingComposer,
      $$UsCursorsTableAnnotationComposer,
      $$UsCursorsTableCreateCompanionBuilder,
      $$UsCursorsTableUpdateCompanionBuilder,
      (
        UsCursor,
        BaseReferences<_$SyncServiceDatabase, $UsCursorsTable, UsCursor>,
      ),
      UsCursor,
      PrefetchHooks Function()
    >;
typedef $$UsTombstonesTableCreateCompanionBuilder = UsTombstonesCompanion Function({
  required String entity,
  required Uint8List keyHash,
  required String keyJson,
  required String source,
  required int deletedAt,
  Value<int?> ackedAt,
  Value<int> rowid,
});
typedef $$UsTombstonesTableUpdateCompanionBuilder = UsTombstonesCompanion Function({
  Value<String> entity,
  Value<Uint8List> keyHash,
  Value<String> keyJson,
  Value<String> source,
  Value<int> deletedAt,
  Value<int?> ackedAt,
  Value<int> rowid,
});

class $$UsTombstonesTableFilterComposer extends Composer<_$SyncServiceDatabase, $UsTombstonesTable> {
  $$UsTombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get keyHash => $composableBuilder(
    column: $table.keyHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyJson => $composableBuilder(
    column: $table.keyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ackedAt => $composableBuilder(
    column: $table.ackedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsTombstonesTableOrderingComposer extends Composer<_$SyncServiceDatabase, $UsTombstonesTable> {
  $$UsTombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get keyHash => $composableBuilder(
    column: $table.keyHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyJson => $composableBuilder(
    column: $table.keyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ackedAt => $composableBuilder(
    column: $table.ackedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsTombstonesTableAnnotationComposer extends Composer<_$SyncServiceDatabase, $UsTombstonesTable> {
  $$UsTombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity => $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<Uint8List> get keyHash => $composableBuilder(column: $table.keyHash, builder: (column) => column);

  GeneratedColumn<String> get keyJson => $composableBuilder(column: $table.keyJson, builder: (column) => column);

  GeneratedColumn<String> get source => $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get deletedAt => $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get ackedAt => $composableBuilder(column: $table.ackedAt, builder: (column) => column);
}

class $$UsTombstonesTableTableManager
    extends
        RootTableManager<
          _$SyncServiceDatabase,
          $UsTombstonesTable,
          UsTombstone,
          $$UsTombstonesTableFilterComposer,
          $$UsTombstonesTableOrderingComposer,
          $$UsTombstonesTableAnnotationComposer,
          $$UsTombstonesTableCreateCompanionBuilder,
          $$UsTombstonesTableUpdateCompanionBuilder,
          (
            UsTombstone,
            BaseReferences<_$SyncServiceDatabase, $UsTombstonesTable, UsTombstone>,
          ),
          UsTombstone,
          PrefetchHooks Function()
        > {
  $$UsTombstonesTableTableManager(
    _$SyncServiceDatabase db,
    $UsTombstonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$UsTombstonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$UsTombstonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$UsTombstonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<Uint8List> keyHash = const Value.absent(),
                Value<String> keyJson = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> deletedAt = const Value.absent(),
                Value<int?> ackedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsTombstonesCompanion(
                entity: entity,
                keyHash: keyHash,
                keyJson: keyJson,
                source: source,
                deletedAt: deletedAt,
                ackedAt: ackedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                required Uint8List keyHash,
                required String keyJson,
                required String source,
                required int deletedAt,
                Value<int?> ackedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsTombstonesCompanion.insert(
                entity: entity,
                keyHash: keyHash,
                keyJson: keyJson,
                source: source,
                deletedAt: deletedAt,
                ackedAt: ackedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsTombstonesTable, UsTombstone>(table),
                  BaseReferences<_$SyncServiceDatabase, $UsTombstonesTable, UsTombstone>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsTombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$SyncServiceDatabase,
      $UsTombstonesTable,
      UsTombstone,
      $$UsTombstonesTableFilterComposer,
      $$UsTombstonesTableOrderingComposer,
      $$UsTombstonesTableAnnotationComposer,
      $$UsTombstonesTableCreateCompanionBuilder,
      $$UsTombstonesTableUpdateCompanionBuilder,
      (
        UsTombstone,
        BaseReferences<_$SyncServiceDatabase, $UsTombstonesTable, UsTombstone>,
      ),
      UsTombstone,
      PrefetchHooks Function()
    >;
typedef $$UsConflictsTableCreateCompanionBuilder = UsConflictsCompanion Function({
  Value<int> id,
  required String entity,
  required Uint8List keyHash,
  required String keyJson,
  Value<String?> localJson,
  required String remoteJson,
  required String localStatus,
  required int detectedAt,
  Value<int?> resolvedAt,
});
typedef $$UsConflictsTableUpdateCompanionBuilder = UsConflictsCompanion Function({
  Value<int> id,
  Value<String> entity,
  Value<Uint8List> keyHash,
  Value<String> keyJson,
  Value<String?> localJson,
  Value<String> remoteJson,
  Value<String> localStatus,
  Value<int> detectedAt,
  Value<int?> resolvedAt,
});

class $$UsConflictsTableFilterComposer extends Composer<_$SyncServiceDatabase, $UsConflictsTable> {
  $$UsConflictsTableFilterComposer({
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

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get keyHash => $composableBuilder(
    column: $table.keyHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyJson => $composableBuilder(
    column: $table.keyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localJson => $composableBuilder(
    column: $table.localJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteJson => $composableBuilder(
    column: $table.remoteJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localStatus => $composableBuilder(
    column: $table.localStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsConflictsTableOrderingComposer extends Composer<_$SyncServiceDatabase, $UsConflictsTable> {
  $$UsConflictsTableOrderingComposer({
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

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get keyHash => $composableBuilder(
    column: $table.keyHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyJson => $composableBuilder(
    column: $table.keyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localJson => $composableBuilder(
    column: $table.localJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteJson => $composableBuilder(
    column: $table.remoteJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localStatus => $composableBuilder(
    column: $table.localStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsConflictsTableAnnotationComposer extends Composer<_$SyncServiceDatabase, $UsConflictsTable> {
  $$UsConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entity => $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<Uint8List> get keyHash => $composableBuilder(column: $table.keyHash, builder: (column) => column);

  GeneratedColumn<String> get keyJson => $composableBuilder(column: $table.keyJson, builder: (column) => column);

  GeneratedColumn<String> get localJson => $composableBuilder(column: $table.localJson, builder: (column) => column);

  GeneratedColumn<String> get remoteJson => $composableBuilder(
    column: $table.remoteJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localStatus => $composableBuilder(
    column: $table.localStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );
}

class $$UsConflictsTableTableManager
    extends
        RootTableManager<
          _$SyncServiceDatabase,
          $UsConflictsTable,
          UsConflict,
          $$UsConflictsTableFilterComposer,
          $$UsConflictsTableOrderingComposer,
          $$UsConflictsTableAnnotationComposer,
          $$UsConflictsTableCreateCompanionBuilder,
          $$UsConflictsTableUpdateCompanionBuilder,
          (
            UsConflict,
            BaseReferences<_$SyncServiceDatabase, $UsConflictsTable, UsConflict>,
          ),
          UsConflict,
          PrefetchHooks Function()
        > {
  $$UsConflictsTableTableManager(
    _$SyncServiceDatabase db,
    $UsConflictsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$UsConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$UsConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$UsConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<Uint8List> keyHash = const Value.absent(),
                Value<String> keyJson = const Value.absent(),
                Value<String?> localJson = const Value.absent(),
                Value<String> remoteJson = const Value.absent(),
                Value<String> localStatus = const Value.absent(),
                Value<int> detectedAt = const Value.absent(),
                Value<int?> resolvedAt = const Value.absent(),
              }) => UsConflictsCompanion(
                id: id,
                entity: entity,
                keyHash: keyHash,
                keyJson: keyJson,
                localJson: localJson,
                remoteJson: remoteJson,
                localStatus: localStatus,
                detectedAt: detectedAt,
                resolvedAt: resolvedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entity,
                required Uint8List keyHash,
                required String keyJson,
                Value<String?> localJson = const Value.absent(),
                required String remoteJson,
                required String localStatus,
                required int detectedAt,
                Value<int?> resolvedAt = const Value.absent(),
              }) => UsConflictsCompanion.insert(
                id: id,
                entity: entity,
                keyHash: keyHash,
                keyJson: keyJson,
                localJson: localJson,
                remoteJson: remoteJson,
                localStatus: localStatus,
                detectedAt: detectedAt,
                resolvedAt: resolvedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsConflictsTable, UsConflict>(table),
                  BaseReferences<_$SyncServiceDatabase, $UsConflictsTable, UsConflict>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$SyncServiceDatabase,
      $UsConflictsTable,
      UsConflict,
      $$UsConflictsTableFilterComposer,
      $$UsConflictsTableOrderingComposer,
      $$UsConflictsTableAnnotationComposer,
      $$UsConflictsTableCreateCompanionBuilder,
      $$UsConflictsTableUpdateCompanionBuilder,
      (
        UsConflict,
        BaseReferences<_$SyncServiceDatabase, $UsConflictsTable, UsConflict>,
      ),
      UsConflict,
      PrefetchHooks Function()
    >;
typedef $$UsDeadLettersTableCreateCompanionBuilder = UsDeadLettersCompanion Function({
  Value<int> sequence,
  required String entity,
  required Uint8List keyHash,
  required String keyJson,
  required String kind,
  Value<String?> payloadJson,
  required String failureJson,
  required int failedAt,
});
typedef $$UsDeadLettersTableUpdateCompanionBuilder = UsDeadLettersCompanion Function({
  Value<int> sequence,
  Value<String> entity,
  Value<Uint8List> keyHash,
  Value<String> keyJson,
  Value<String> kind,
  Value<String?> payloadJson,
  Value<String> failureJson,
  Value<int> failedAt,
});

class $$UsDeadLettersTableFilterComposer extends Composer<_$SyncServiceDatabase, $UsDeadLettersTable> {
  $$UsDeadLettersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get keyHash => $composableBuilder(
    column: $table.keyHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyJson => $composableBuilder(
    column: $table.keyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureJson => $composableBuilder(
    column: $table.failureJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failedAt => $composableBuilder(
    column: $table.failedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsDeadLettersTableOrderingComposer extends Composer<_$SyncServiceDatabase, $UsDeadLettersTable> {
  $$UsDeadLettersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get keyHash => $composableBuilder(
    column: $table.keyHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyJson => $composableBuilder(
    column: $table.keyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureJson => $composableBuilder(
    column: $table.failureJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failedAt => $composableBuilder(
    column: $table.failedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsDeadLettersTableAnnotationComposer extends Composer<_$SyncServiceDatabase, $UsDeadLettersTable> {
  $$UsDeadLettersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sequence => $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get entity => $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<Uint8List> get keyHash => $composableBuilder(column: $table.keyHash, builder: (column) => column);

  GeneratedColumn<String> get keyJson => $composableBuilder(column: $table.keyJson, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureJson => $composableBuilder(
    column: $table.failureJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failedAt => $composableBuilder(column: $table.failedAt, builder: (column) => column);
}

class $$UsDeadLettersTableTableManager
    extends
        RootTableManager<
          _$SyncServiceDatabase,
          $UsDeadLettersTable,
          UsDeadLetter,
          $$UsDeadLettersTableFilterComposer,
          $$UsDeadLettersTableOrderingComposer,
          $$UsDeadLettersTableAnnotationComposer,
          $$UsDeadLettersTableCreateCompanionBuilder,
          $$UsDeadLettersTableUpdateCompanionBuilder,
          (
            UsDeadLetter,
            BaseReferences<_$SyncServiceDatabase, $UsDeadLettersTable, UsDeadLetter>,
          ),
          UsDeadLetter,
          PrefetchHooks Function()
        > {
  $$UsDeadLettersTableTableManager(
    _$SyncServiceDatabase db,
    $UsDeadLettersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$UsDeadLettersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$UsDeadLettersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$UsDeadLettersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sequence = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<Uint8List> keyHash = const Value.absent(),
                Value<String> keyJson = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<String> failureJson = const Value.absent(),
                Value<int> failedAt = const Value.absent(),
              }) => UsDeadLettersCompanion(
                sequence: sequence,
                entity: entity,
                keyHash: keyHash,
                keyJson: keyJson,
                kind: kind,
                payloadJson: payloadJson,
                failureJson: failureJson,
                failedAt: failedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> sequence = const Value.absent(),
                required String entity,
                required Uint8List keyHash,
                required String keyJson,
                required String kind,
                Value<String?> payloadJson = const Value.absent(),
                required String failureJson,
                required int failedAt,
              }) => UsDeadLettersCompanion.insert(
                sequence: sequence,
                entity: entity,
                keyHash: keyHash,
                keyJson: keyJson,
                kind: kind,
                payloadJson: payloadJson,
                failureJson: failureJson,
                failedAt: failedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsDeadLettersTable, UsDeadLetter>(table),
                  BaseReferences<_$SyncServiceDatabase, $UsDeadLettersTable, UsDeadLetter>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsDeadLettersTableProcessedTableManager =
    ProcessedTableManager<
      _$SyncServiceDatabase,
      $UsDeadLettersTable,
      UsDeadLetter,
      $$UsDeadLettersTableFilterComposer,
      $$UsDeadLettersTableOrderingComposer,
      $$UsDeadLettersTableAnnotationComposer,
      $$UsDeadLettersTableCreateCompanionBuilder,
      $$UsDeadLettersTableUpdateCompanionBuilder,
      (
        UsDeadLetter,
        BaseReferences<_$SyncServiceDatabase, $UsDeadLettersTable, UsDeadLetter>,
      ),
      UsDeadLetter,
      PrefetchHooks Function()
    >;

class $SyncServiceDatabaseManager {
  final _$SyncServiceDatabase _db;
  $SyncServiceDatabaseManager(this._db);
  $$UsMetaTableTableManager get usMeta => $$UsMetaTableTableManager(_db, _db.usMeta);
  $$UsOutboxTableTableManager get usOutbox => $$UsOutboxTableTableManager(_db, _db.usOutbox);
  $$UsCursorsTableTableManager get usCursors => $$UsCursorsTableTableManager(_db, _db.usCursors);
  $$UsTombstonesTableTableManager get usTombstones => $$UsTombstonesTableTableManager(_db, _db.usTombstones);
  $$UsConflictsTableTableManager get usConflicts => $$UsConflictsTableTableManager(_db, _db.usConflicts);
  $$UsDeadLettersTableTableManager get usDeadLetters => $$UsDeadLettersTableTableManager(_db, _db.usDeadLetters);
}
