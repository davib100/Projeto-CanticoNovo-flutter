
// core/db/database_adapter.dart
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import '../services/connectivity_service.dart';
import 'database_cache.dart';
import 'migration_manager.dart';

part 'database_adapter.g.dart';

// ══════════════════════════════════════════
// TABELAS
// ══════════════════════════════════════════

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get description => text().nullable()();
}

/// Tabela para o log de auditoria de sincronização
@DataClassName('AuditLogEntry')
class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetTable => text().named('table_name')();
  TextColumn get recordId => text()();
  TextColumn get action => text()(); // e.g., 'create', 'update', 'delete'
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get status => text()(); // e.g., 'pending', 'synced', 'failed'
  TextColumn get details => text().nullable()(); // JSON com detalhes do erro, etc.
}

/// Tabela para a fila de operações pendentes (Queue)
@DataClassName('QueuedOperation')
class OperationQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operationType => text()(); // 'create', 'update', 'delete'
  TextColumn get entityName => text()(); // Nome da tabela/entidade
  TextColumn get entityId => text()(); // ID do registro
  TextColumn get data => text()(); // JSON do objeto
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, processing, failed
}

/// Tabela de metadados de sincronização
@DataClassName('SyncMetadata')
class SyncJournal extends Table {
  TextColumn get entityName => text()();
  DateTimeColumn get lastSync => dateTime()();
  TextColumn get syncStatus => text()(); // 'success', 'failed', 'in_progress'
  TextColumn get details => text().nullable()(); // Erros, estatísticas, etc.
  
  @override
  Set<Column> get primaryKey => {entityName};
}

// ══════════════════════════════════════════
// DATABASE ADAPTER
// ══════════════════════════════════════════

@DriftDatabase(
  tables: [AuditLog, OperationQueue, SyncJournal, Categories],
  daos: [DatabaseCache],
)
class DatabaseAdapter extends _$DatabaseAdapter {
  static DatabaseAdapter? _instance;
  static final _lock = Lock();

  // Private constructor
  DatabaseAdapter._() : super(_openConnection());

  // Singleton factory
  factory DatabaseAdapter() {
    if (_instance == null) {
      _lock.synchronized(() {
        if (_instance == null) {
          _instance = DatabaseAdapter._();
          // Inicializar serviços dependentes que precisam do DB
          _instance!._initializeDependencies();
        }
      });
    }
    return _instance!;
  }
  
  // Getter estático para fácil acesso
  static DatabaseAdapter get instance {
    if (_instance == null) {
      // Este log ajuda a identificar chamadas ao `instance` antes da inicialização.
      // Em um app real, isso pode indicar um problema na ordem de inicialização.
      if (kDebugMode) {
        print("⚠️ DatabaseAdapter.instance called before initialization. Creating new instance via factory.");
      }
      return DatabaseAdapter(); // A factory cuidará da criação segura
    }
    return _instance!;
  }
  
  bool get isHealthy => ConnectivityService.instance.isConnected;

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _initializeDatabase();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        await MigrationManager.runMigrations(m, from, to);
      },
      beforeOpen: (details) async {
        if (kDebugMode) {
          print("✅ Verifying database integrity before opening...");
        }
        
        // Exemplo: Validação de consistência ou limpeza de cache
        if (details.wasCreated) {
          if (kDebugMode) {
            print("✨ New database created. Initial setup can be performed here.");
          }
        }
        
        // Habilitar WAL mode para melhor concorrência
        await customStatement('PRAGMA journal_mode=WAL;');
        
        // Opcional: Aumentar o tamanho do cache para melhor performance
        await customStatement('PRAGMA cache_size = -20000;'); // 20MB cache
      },
    );
  }

  /// Inicializa o banco de dados com dados iniciais se necessário
  Future<void> _initializeDatabase() async {
    // Aqui você pode adicionar dados iniciais, como configurações padrão
    // Ex: await into(syncJournal).insert(SyncMetadata(...));
    if (kDebugMode) {
      print("🌱 Database initialized and seeded.");
    }
  }
  
  /// Inicializa dependências que precisam do banco
  void _initializeDependencies() {
    // O DatabaseCache é um DAO, então é inicializado pelo próprio Drift.
    // Outros serviços podem ser inicializados aqui.
    // Ex: AnalyticsService.initialize(this);
    if (kDebugMode) {
      print("🔗 Database dependencies initialized.");
    }
  }

  /// Fecha a conexão com o banco de dados
  @override
  Future<void> close() async {
    await super.close();
    _instance = null;
    if (kDebugMode) {
      print("🔒 Database connection closed.");
    }
  }

  /// Captura uma exceção com Sentry e a relança
  Future<T> _captureAndThrow<T>(dynamic exception, StackTrace stackTrace, String context) async {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      hint: Hint.withMap({'context': context}),
    );
    // Relançar a exceção para que a camada superior possa lidar com ela
    throw exception;
  }

  // Métodos CRUD genéricos com tratamento de erro e logging
  Future<D?> getById<T extends Table, D>(int id, TableInfo<T, D> table) async {
    try {
      return await (select(table)..where((tbl) => (tbl as dynamic).id.equals(id))).getSingleOrNull();
    } catch (e, s) {
      return _captureAndThrow(e, s, 'getById from ${table.entityName}');
    }
  }

  Future<int> create<T extends Table, D>(Insertable<D> entity, TableInfo<T, D> table) async {
    try {
      return await into(table).insert(entity);
    } catch (e, s) {
      return _captureAndThrow(e, s, 'create in ${table.entityName}');
    }
  }
}

/// Abre a conexão com o banco de dados
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cantico_novo.db'));

    // Assegurar que a biblioteca nativa do SQLite3 seja encontrada
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    
    // Log para o caminho do banco de dados
    if (kDebugMode) {
      print("🔍 Database file path: ${file.path}");
    }

    final database = sqlite3.open(
      file.path,
      mode: OpenMode.readWriteCreate,
    );
    
    return NativeDatabase.opened(database);
  });
}
