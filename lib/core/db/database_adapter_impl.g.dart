// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_adapter_impl.dart';

// ignore_for_file: type=lint
class $OperationsTable extends Operations
    with TableInfo<$OperationsTable, Operation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
      'priority', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _maxRetriesMeta =
      const VerificationMeta('maxRetries');
  @override
  late final GeneratedColumn<int> maxRetries = GeneratedColumn<int>(
      'max_retries', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _batchIdMeta =
      const VerificationMeta('batchId');
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
      'batch_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        type,
        data,
        priority,
        maxRetries,
        attempts,
        batchId,
        createdAt,
        status
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operations';
  @override
  VerificationContext validateIntegrity(Insertable<Operation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('max_retries')) {
      context.handle(
          _maxRetriesMeta,
          maxRetries.isAcceptableOrUnknown(
              data['max_retries']!, _maxRetriesMeta));
    } else if (isInserting) {
      context.missing(_maxRetriesMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    } else if (isInserting) {
      context.missing(_attemptsMeta);
    }
    if (data.containsKey('batch_id')) {
      context.handle(_batchIdMeta,
          batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Operation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Operation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data']),
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}priority'])!,
      maxRetries: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_retries'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      batchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}batch_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status']),
    );
  }

  @override
  $OperationsTable createAlias(String alias) {
    return $OperationsTable(attachedDatabase, alias);
  }
}

class Operation extends DataClass implements Insertable<Operation> {
  final String id;
  final String type;
  final String? data;
  final int priority;
  final int maxRetries;
  final int attempts;
  final String? batchId;
  final DateTime createdAt;
  final String? status;
  const Operation(
      {required this.id,
      required this.type,
      this.data,
      required this.priority,
      required this.maxRetries,
      required this.attempts,
      this.batchId,
      required this.createdAt,
      this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || data != null) {
      map['data'] = Variable<String>(data);
    }
    map['priority'] = Variable<int>(priority);
    map['max_retries'] = Variable<int>(maxRetries);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || batchId != null) {
      map['batch_id'] = Variable<String>(batchId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    return map;
  }

  OperationsCompanion toCompanion(bool nullToAbsent) {
    return OperationsCompanion(
      id: Value(id),
      type: Value(type),
      data: data == null && nullToAbsent ? const Value.absent() : Value(data),
      priority: Value(priority),
      maxRetries: Value(maxRetries),
      attempts: Value(attempts),
      batchId: batchId == null && nullToAbsent
          ? const Value.absent()
          : Value(batchId),
      createdAt: Value(createdAt),
      status:
          status == null && nullToAbsent ? const Value.absent() : Value(status),
    );
  }

  factory Operation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Operation(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      data: serializer.fromJson<String?>(json['data']),
      priority: serializer.fromJson<int>(json['priority']),
      maxRetries: serializer.fromJson<int>(json['maxRetries']),
      attempts: serializer.fromJson<int>(json['attempts']),
      batchId: serializer.fromJson<String?>(json['batchId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String?>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'data': serializer.toJson<String?>(data),
      'priority': serializer.toJson<int>(priority),
      'maxRetries': serializer.toJson<int>(maxRetries),
      'attempts': serializer.toJson<int>(attempts),
      'batchId': serializer.toJson<String?>(batchId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String?>(status),
    };
  }

  Operation copyWith(
          {String? id,
          String? type,
          Value<String?> data = const Value.absent(),
          int? priority,
          int? maxRetries,
          int? attempts,
          Value<String?> batchId = const Value.absent(),
          DateTime? createdAt,
          Value<String?> status = const Value.absent()}) =>
      Operation(
        id: id ?? this.id,
        type: type ?? this.type,
        data: data.present ? data.value : this.data,
        priority: priority ?? this.priority,
        maxRetries: maxRetries ?? this.maxRetries,
        attempts: attempts ?? this.attempts,
        batchId: batchId.present ? batchId.value : this.batchId,
        createdAt: createdAt ?? this.createdAt,
        status: status.present ? status.value : this.status,
      );
  @override
  String toString() {
    return (StringBuffer('Operation(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('data: $data, ')
          ..write('priority: $priority, ')
          ..write('maxRetries: $maxRetries, ')
          ..write('attempts: $attempts, ')
          ..write('batchId: $batchId, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, data, priority, maxRetries,
      attempts, batchId, createdAt, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Operation &&
          other.id == this.id &&
          other.type == this.type &&
          other.data == this.data &&
          other.priority == this.priority &&
          other.maxRetries == this.maxRetries &&
          other.attempts == this.attempts &&
          other.batchId == this.batchId &&
          other.createdAt == this.createdAt &&
          other.status == this.status);
}

class OperationsCompanion extends UpdateCompanion<Operation> {
  final Value<String> id;
  final Value<String> type;
  final Value<String?> data;
  final Value<int> priority;
  final Value<int> maxRetries;
  final Value<int> attempts;
  final Value<String?> batchId;
  final Value<DateTime> createdAt;
  final Value<String?> status;
  final Value<int> rowid;
  const OperationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.data = const Value.absent(),
    this.priority = const Value.absent(),
    this.maxRetries = const Value.absent(),
    this.attempts = const Value.absent(),
    this.batchId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OperationsCompanion.insert({
    required String id,
    required String type,
    this.data = const Value.absent(),
    required int priority,
    required int maxRetries,
    required int attempts,
    this.batchId = const Value.absent(),
    required DateTime createdAt,
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        type = Value(type),
        priority = Value(priority),
        maxRetries = Value(maxRetries),
        attempts = Value(attempts),
        createdAt = Value(createdAt);
  static Insertable<Operation> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? data,
    Expression<int>? priority,
    Expression<int>? maxRetries,
    Expression<int>? attempts,
    Expression<String>? batchId,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (data != null) 'data': data,
      if (priority != null) 'priority': priority,
      if (maxRetries != null) 'max_retries': maxRetries,
      if (attempts != null) 'attempts': attempts,
      if (batchId != null) 'batch_id': batchId,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OperationsCompanion copyWith(
      {Value<String>? id,
      Value<String>? type,
      Value<String?>? data,
      Value<int>? priority,
      Value<int>? maxRetries,
      Value<int>? attempts,
      Value<String?>? batchId,
      Value<DateTime>? createdAt,
      Value<String?>? status,
      Value<int>? rowid}) {
    return OperationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      priority: priority ?? this.priority,
      maxRetries: maxRetries ?? this.maxRetries,
      attempts: attempts ?? this.attempts,
      batchId: batchId ?? this.batchId,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (maxRetries.present) {
      map['max_retries'] = Variable<int>(maxRetries.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('data: $data, ')
          ..write('priority: $priority, ')
          ..write('maxRetries: $maxRetries, ')
          ..write('attempts: $attempts, ')
          ..write('batchId: $batchId, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $OperationsTable operations = $OperationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [operations];
}
