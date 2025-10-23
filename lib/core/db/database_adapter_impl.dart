import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../queue/queued_operation.dart';
import 'database_adapter.dart';

part 'database_adapter_impl.g.dart';

@DataClassName('Operation')
class Operations extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get data => text().nullable()();
  IntColumn get priority => integer()();
  IntColumn get maxRetries => integer()();
  IntColumn get attempts => integer()();
  TextColumn get batchId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get status => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Operations])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> saveOperation(QueuedOperation operation) {
    return into(operations).insert(
      OperationsCompanion.insert(
        id: operation.id,
        type: operation.type,
        data: Value(operation.data),
        priority: operation.priority.index,
        maxRetries: operation.maxRetries,
        attempts: operation.attempts,
        batchId: Value(operation.batchId),
        createdAt: operation.createdAt,
        status: Value(operation.status),
      ),
      mode: InsertMode.replace,
    );
  }

  Future<void> deleteOperation(String id) {
    return (delete(operations)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> updateOperation(QueuedOperation operation) {
    return (update(
      operations,
    )..where((tbl) => tbl.id.equals(operation.id)))
        .write(
      OperationsCompanion(
        attempts: Value(operation.attempts),
        status: Value(operation.status),
      ),
    );
  }

  Future<List<QueuedOperation>> getPendingOperations() async {
    final result = await (select(operations)
          ..where(
            (tbl) =>
                tbl.status.isNull() |
                tbl.status.equals('paused') |
                tbl.status.equals('running'),
          ))
        .get();

    return result
        .map(
          (o) => QueuedOperation(
            id: o.id,
            type: o.type,
            data: o.data,
            priority: QueuePriority.values[o.priority],
            maxRetries: o.maxRetries,
            attempts: o.attempts,
            batchId: o.batchId,
            status: o.status,
          ),
        )
        .toList();
  }

  Future<void> clearAllOperations() {
    return delete(operations).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}

class DatabaseAdapterImpl extends DatabaseAdapter {
  late AppDatabase _db;
  bool _isInitialized = false;

  @override
  bool get isHealthy => _isInitialized;

  @override
  Future<void> init() async {
    _db = AppDatabase();
    await _db.executor.ensureOpen(_db);
    _isInitialized = true;
  }

  @override
  Future<void> close() async {
    await _db.close();
    _isInitialized = false;
  }

  @override
  Future<String> export() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'db.sqlite');
  }

  @override
  Future<void> restore(String path) async {
    await close();
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    final backup = File(path);
    await backup.copy(file.path);
    await init();
  }

  @override
  Future<void> saveOperation(QueuedOperation operation) async {
    await _db.saveOperation(operation);
  }

  @override
  Future<void> deleteOperation(String id) async {
    await _db.deleteOperation(id);
  }

  @override
  Future<void> updateOperation(QueuedOperation operation) async {
    await _db.updateOperation(operation);
  }

  @override
  Future<List<QueuedOperation>> getPendingOperations() async {
    return await _db.getPendingOperations();
  }

  @override
  Future<void> clearAllOperations() async {
    await _db.clearAllOperations();
  }

  @override
  Future<void> transaction(Future<void> Function(dynamic txn) action) async {
    return _db.transaction(() => action(_db));
  }

  @override
  Future<int> insert({
    required String table,
    required Map<String, dynamic> data,
    ConflictAlgorithm? conflictAlgorithm,
    dynamic transaction,
  }) async {
    final db = transaction?.executor ?? _db.executor;
    final columns = data.keys.join(', ');
    final placeholders = List.filled(data.length, '?').join(', ');
    
    String conflictClause = '';
    if (conflictAlgorithm != null && conflictAlgorithm == ConflictAlgorithm.replace) {
      conflictClause = 'OR REPLACE';
    }

    final sql = 'INSERT $conflictClause INTO $table ($columns) VALUES ($placeholders)';
    return await db.runInsert(sql, data.values.toList());
  }

  @override
  Future<int> update({
    required String table,
    required Map<String, dynamic> data,
    String? where,
    List<dynamic>? whereArgs,
    dynamic transaction,
  }) async {
    final db = transaction?.executor ?? _db.executor;
    final setClause = data.keys.map((key) => '$key = ?').join(', ');
    final sql = 'UPDATE $table SET $setClause${where != null ? ' WHERE $where' : ''}';
    final args = [...data.values, ...(whereArgs ?? [])];
    return await db.runUpdate(sql, args);
  }

  @override
  Future<int> delete({
    required String table,
    String? where,
    List<dynamic>? whereArgs,
    dynamic transaction,
  }) async {
    final db = transaction?.executor ?? _db.executor;
    final sql = 'DELETE FROM $table${where != null ? ' WHERE $where' : ''}';
    return await db.runDelete(sql, whereArgs ?? []);
  }

  @override
  Future<List<Map<String, dynamic>>> query({
    required String table,
    List<String>? columns,
    String? where,
    List? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final columnsClause = columns?.join(', ') ?? '*';
    var sql = 'SELECT $columnsClause FROM $table';
    if (where != null) {
      sql += ' WHERE $where';
    }
    if (orderBy != null) {
      sql += ' ORDER BY $orderBy';
    }
    if (limit != null) {
      sql += ' LIMIT $limit';
    }
    final result = await _db.executor.runSelect(sql, whereArgs?.cast<Object?>() ?? []);
    return result;
  }
}

final databaseAdapterProvider = Provider<DatabaseAdapter>((ref) {
  return DatabaseAdapterImpl();
});
