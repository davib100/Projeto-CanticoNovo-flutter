import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
  IntColumn get priority => int()();
  IntColumn get maxRetries => int()();
  IntColumn get attempts => int()();
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
        data: operation.data.toString(),
        priority: operation.priority.index,
        maxRetries: operation.maxRetries,
        attempts: operation.attempts,
        batchId: operation.batchId,
        createdAt: operation.createdAt,
        status: operation.status,
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
    )..where((tbl) => tbl.id.equals(operation.id))).write(
      OperationsCompanion(
        attempts: Value(operation.attempts),
        status: Value(operation.status),
      ),
    );
  }

  Future<List<QueuedOperation>> getPendingOperations() async {
    final result =
        await (select(operations)..where(
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

  @override
  Future<void> init() async {
    _db = AppDatabase();
  }

  @override
  Future<void> close() async {
    await _db.close();
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
  Future<void> executeMigrations(Map<int, String> migrations) async {
    // Drift handles migrations automatically
  }

  @override
  Future<T?> getCached<T>(String key) async {
    // Implement caching logic here if needed
    return null;
  }

  @override
  Future<void> setCached<T>(String key, T value, {Duration? ttl}) async {
    // Implement caching logic here if needed
  }

  @override
  Future<void> invalidateCache(String key) async {
    // Implement caching logic here if needed
  }

  @override
  Future<File> export() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'db.sqlite'));
  }

  @override
  Future<void> restore(List<int> data) async {
    await _db.close();
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    await file.writeAsBytes(data);
    _db = AppDatabase();
  }
}
