// core/db/database_adapter.dart
@DriftDatabase(tables: [Songs, Categories, SyncLog, QueueOperations])
class DatabaseAdapter extends _$DatabaseAdapter {
  DatabaseAdapter() : super(_openConnection());
  
  @override
  int get schemaVersion => 1;
  
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        await MigrationManager.runMigrations(m, from, to);
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
      }
    );
  }
  
  static QueryExecutor _openConnection() {
    return NativeDatabase.memory(
      logStatements: true,
      setup: (db) {
        db.execute('PRAGMA journal_mode = WAL');
      }
    );
  }
  
  // Métodos genéricos
  Future<int> insertGeneric(String table, Map<String, dynamic> data) async {
    return await customInsert(
      'INSERT INTO $table (${data.keys.join(", ")}) '
      'VALUES (${List.filled(data.length, "?").join(", ")})',
      variables: data.values.map((v) => Variable(v)).toList(),
    );
  }
}

// core/db/database_adapter.dart (VERSÃO COMPLETA)
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'migration_manager.dart';
import 'schema_registry.dart';

part '../../../core/db/database_adapter.g.dart';

// Definição das tabelas
@DataClassName('Song')
class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get lyrics => text()();
  TextColumn get author => text().nullable()();
  IntColumn get categoryId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get color => text().withDefault(const Constant('#000000'))();
  IntColumn get order => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('SyncLogEntry')
class SyncLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  IntColumn get entityId => integer()();
  TextColumn get operation => text()(); // insert, update, delete
  TextColumn get status => text()(); // pending, synced, conflict, error
  TextColumn get payload => text()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

@DataClassName('QueueOperation')
class QueueOperations extends Table {
  TextColumn get id => text()();
  TextColumn get module => text()();
  TextColumn get action => text()();
  TextColumn get payload => text()();
  TextColumn get status => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Songs, Categories, SyncLog, QueueOperations],
  daos: [],
)
class DatabaseAdapter extends _$DatabaseAdapter {
  DatabaseAdapter() : super(_openConnection());
  
  @override
  int get schemaVersion => 1;
  
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _initializeSchemaRegistry();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        await MigrationManager.runMigrations(m, from, to);
      },
      beforeOpen: (details) async {
        // Habilitar foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
        
        // Habilitar WAL mode para melhor performance
        await customStatement('PRAGMA journal_mode = WAL');
        
        // Validar integridade após migração
        if (details.wasCreated || details.hadUpgrade) {
          final result = await customSelect('PRAGMA integrity_check').get();
          if (result.first.read<String>('integrity_check') != 'ok') {
            throw Exception('Database integrity check failed');
          }
        }
      },
    );
  }
  
  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'cantico_novo.db'));
      
      return NativeDatabase.createInBackground(
        file,
        logStatements: true,
        setup: (database) {
          database.execute('PRAGMA journal_mode = WAL');
          database.execute('PRAGMA foreign_keys = ON');
        },
      );
    });
  }
  
  /// Inicializa o registro de schemas
  Future<void> _initializeSchemaRegistry() async {
    SchemaRegistry.registerTable(songs);
    SchemaRegistry.registerTable(categories);
    SchemaRegistry.registerTable(syncLog);
    SchemaRegistry.registerTable(queueOperations);
  }
  
  // ===== CRUD Genérico =====
  
  /// Insere registro genérico
  Future<int> insertGeneric(
    String tableName, 
    Map<String, dynamic> data
  ) async {
    final columns = data.keys.join(', ');
    final placeholders = List.filled(data.length, '?').join(', ');
    
    return await customInsert(
      'INSERT INTO $tableName ($columns) VALUES ($placeholders)',
      variables: data.values.map((v) => Variable(v)).toList(),
      updates: {_getTableByName(tableName)},
    );
  }
  
  /// Atualiza registro genérico
  Future<int> updateGeneric(
    String tableName,
    Map<String, dynamic> data,
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    final setClause = data.keys.map((k) => '$k = ?').join(', ');
    
    return await customUpdate(
      'UPDATE $tableName SET $setClause WHERE $whereClause',
      variables: [
        ...data.values.map((v) => Variable(v)),
        ...whereArgs.map((v) => Variable(v)),
      ],
      updates: {_getTableByName(tableName)},
    );
  }
  
  /// Deleta registro genérico
  Future<int> deleteGeneric(
    String tableName,
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    return await customUpdate(
      'DELETE FROM $tableName WHERE $whereClause',
      variables: whereArgs.map((v) => Variable(v)).toList(),
      updates: {_getTableByName(tableName)},
    );
  }
  
  /// Query genérica
  Future<List<Map<String, dynamic>>> queryGeneric(
    String tableName, {
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final cols = columns?.join(', ') ?? '*';
    final whereClause = where != null ? 'WHERE $where' : '';
    final orderClause = orderBy != null ? 'ORDER BY $orderBy' : '';
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    
    final query = '''
      SELECT $cols FROM $tableName 
      $whereClause $orderClause $limitClause
    ''';
    
    final results = await customSelect(
      query,
      variables: whereArgs?.map((v) => Variable(v)).toList() ?? [],
      readsFrom: {_getTableByName(tableName)},
    ).get();
    
    return results.map((row) => row.data).toList();
  }
  
  /// Exporta banco de dados
  Future<Uint8List> export() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cantico_novo.db'));
    
    // Fazer checkpoint do WAL antes de exportar
    await customStatement('PRAGMA wal_checkpoint(FULL)');
    
    return await file.readAsBytes();
  }
  
  /// Restaura banco de dados
  Future<void> restore(Uint8List data) async {
    await close();
    
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cantico_novo.db'));
    
    await file.writeAsBytes(data);
    
    // Reabrir conexão
    // A LazyDatabase irá reabrir automaticamente na próxima query
  }
  
  /// Obtém tabela pelo nome
  TableInfo _getTableByName(String tableName) {
    switch (tableName) {
      case 'songs':
        return songs;
      case 'categories':
        return categories;
      case 'sync_log':
        return syncLog;
      case 'queue_operations':
        return queueOperations;
      default:
        throw ArgumentError('Unknown table: $tableName');
    }
  }
}
