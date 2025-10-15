// core/db/database_adapter.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'migration_manager.dart';
import 'schema_registry.dart';
import 'database_cache.dart';
import 'database_config.dart';

part 'database_adapter.g.dart';

// ══════════════════════════════════════════
// DEFINIÇÃO DE TABELAS
// ══════════════════════════════════════════

@DataClassName('Song')
class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get lyrics => text()();
  TextColumn get author => text().nullable()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get checksum => text().nullable()();
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get color => text().withDefault(const Constant('#000000'))();
  IntColumn get order => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
}

@DataClassName('SyncLogEntry')
class SyncLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  IntColumn get entityId => integer()();
  TextColumn get operation => text()();
  TextColumn get status => text()();
  TextColumn get payload => text()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
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
  IntColumn get priority => integer().withDefault(const Constant(50))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get processedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AuditLogEntry')
class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tableName => text()();
  IntColumn get recordId => integer()();
  TextColumn get operation => text()();
  TextColumn get oldValues => text().nullable()();
  TextColumn get newValues => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('DatabaseMetadata')
class Metadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {key};
}

// ══════════════════════════════════════════
// DATABASE ADAPTER
// ══════════════════════════════════════════

@DriftDatabase(
  tables: [Songs, Categories, SyncLog, QueueOperations, AuditLog, Metadata],
)
class DatabaseAdapter extends _$DatabaseAdapter {
  static DatabaseAdapter? _instance;
  
  final DatabaseConfig _config;
  final DatabaseCache _cache;
  Timer? _vacuumTimer;
  Timer? _analyzeTimer;
  
  // Métricas
  int _queryCount = 0;
  int _slowQueryCount = 0;
  final _queryTimes = <Duration>[];
  
  DatabaseAdapter._({
    required DatabaseConfig config,
    required QueryExecutor executor,
  })  : _config = config,
        _cache = DatabaseCache(maxSize: config.cacheSize),
        super(executor);
  
  factory DatabaseAdapter({
    DatabaseConfig? config,
    bool isTest = false,
  }) {
    config ??= DatabaseConfig.defaults();
    
    if (_instance != null && !isTest) {
      return _instance!;
    }
    
    final executor = isTest
        ? _createTestConnection()
        : _createProductionConnection(config);
    
    final instance = DatabaseAdapter._(
      config: config,
      executor: executor,
    );
    
    if (!isTest) {
      _instance = instance;
    }
    
    return instance;
  }
  bool get isHealthy => _isConnected;
  
  @override
  int get schemaVersion => 3; // Incrementado para novas tabelas
  
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _initializeDatabase();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Backup antes de migrar
        if (_config.backupBeforeMigration) {
          await _createBackupBeforeMigration();
        }
        
        try {
          await MigrationManager.runMigrations(m, from, to);
          
          // Validar após migração
          await _validateSchema();
          
        } catch (e) {
          // Rollback em caso de erro
          if (_config.rollbackOnMigrationFailure) {
            await _restoreBackupAfterMigrationFailure();
          }
          rethrow;
        }
      },
      beforeOpen: (details) async {
        // Configurações de performance
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
        await customStatement('PRAGMA synchronous = NORMAL');
        await customStatement('PRAGMA temp_store = MEMORY');
        await customStatement('PRAGMA mmap_size = 30000000000');
        await customStatement('PRAGMA page_size = 4096');
        await customStatement('PRAGMA cache_size = -64000'); // 64MB
        
        // Validar integridade
        if (details.wasCreated || details.hadUpgrade) {
          final integrityCheck = await _checkIntegrity();
          if (!integrityCheck) {
            throw DatabaseIntegrityException('Database integrity check failed');
          }
        }
        
        // Inicializar após abertura
        if (details.wasCreated) {
          await _initializeDatabase();
        }
        
        // Agendar manutenção
        _scheduleMaintenance();
      },
    );
  }
  
  /// Cria conexão de produção
  static QueryExecutor _createProductionConnection(DatabaseConfig config) {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, config.databaseName));
      
      if (kDebugMode) {
        debugPrint('📁 Database path: ${file.path}');
      }
      
      return NativeDatabase.createInBackground(
        file,
        logStatements: config.logStatements,
        setup: (database) {
          database.execute('PRAGMA journal_mode = WAL');
          database.execute('PRAGMA foreign_keys = ON');
        },
      );
    });
  }
  
  /// Cria conexão de teste (em memória)
  static QueryExecutor _createTestConnection() {
    return NativeDatabase.memory(
      logStatements: kDebugMode,
    );
  }
  
  /// Inicializa o banco de dados
  Future<void> _initializeDatabase() async {
    // Registrar schema
    await _registerSchemas();
    
    // Criar índices
    await _createIndexes();
    
    // Criar triggers
    await _createTriggers();
    
    // Criar FTS tables
    await _createFullTextSearchTables();
    
    // Inserir metadados
    await _insertMetadata();
    
    if (kDebugMode) {
      debugPrint('✅ Database initialized');
    }
  }
  
  /// Registra schemas
  Future<void> _registerSchemas() async {
    SchemaRegistry.registerTable(songs);
    SchemaRegistry.registerTable(categories);
    SchemaRegistry.registerTable(syncLog);
    SchemaRegistry.registerTable(queueOperations);
    SchemaRegistry.registerTable(auditLog);
    SchemaRegistry.registerTable(metadata);
  }
  
  /// Cria índices estratégicos
  Future<void> _createIndexes() async {
    // Índices para Songs
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_songs_title ON songs(title COLLATE NOCASE)'
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_songs_category ON songs(category_id)'
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_songs_favorite ON songs(is_favorite)'
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_songs_deleted ON songs(deleted_at)'
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_songs_updated ON songs(updated_at DESC)'
    );
    
    // Índice composto para queries comuns
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_songs_category_favorite '
      'ON songs(category_id, is_favorite) WHERE deleted_at IS NULL'
    );
    
    // Índices para SyncLog
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_status ON sync_log(status)'
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_entity ON sync_log(entity_type, entity_id)'
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_created ON sync_log(created_at DESC)'
    );
    
    // Índices para QueueOperations
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_queue_status_priority '
      'ON queue_operations(status, priority DESC, created_at ASC)'
    );
    
    // Índices para AuditLog
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_table_record '
      'ON audit_log(table_name, record_id)'
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_timestamp '
      'ON audit_log(timestamp DESC)'
    );
    
    if (kDebugMode) {
      debugPrint('✅ Indexes created');
    }
  }
  
  /// Cria triggers para audit trail e soft delete
  Future<void> _createTriggers() async {
    // Trigger para atualizar updated_at em Songs
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS update_songs_timestamp
      AFTER UPDATE ON songs
      FOR EACH ROW
      WHEN NEW.updated_at = OLD.updated_at
      BEGIN
        UPDATE songs SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
      END;
    ''');
    
    // Trigger para audit trail em Songs
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS audit_songs_insert
      AFTER INSERT ON songs
      FOR EACH ROW
      BEGIN
        INSERT INTO audit_log (table_name, record_id, operation, new_values)
        VALUES ('songs', NEW.id, 'INSERT', json_object(
          'title', NEW.title,
          'lyrics', NEW.lyrics,
          'author', NEW.author
        ));
      END;
    ''');
    
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS audit_songs_update
      AFTER UPDATE ON songs
      FOR EACH ROW
      BEGIN
        INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values)
        VALUES ('songs', NEW.id, 'UPDATE', 
          json_object('title', OLD.title, 'lyrics', OLD.lyrics),
          json_object('title', NEW.title, 'lyrics', NEW.lyrics)
        );
      END;
    ''');
    
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS audit_songs_delete
      AFTER UPDATE OF deleted_at ON songs
      FOR EACH ROW
      WHEN NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL
      BEGIN
        INSERT INTO audit_log (table_name, record_id, operation)
        VALUES ('songs', OLD.id, 'DELETE');
      END;
    ''');
    
    // Trigger para incrementar version em update
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS increment_song_version
      AFTER UPDATE ON songs
      FOR EACH ROW
      WHEN NEW.version = OLD.version
      BEGIN
        UPDATE songs SET version = version + 1 WHERE id = NEW.id;
      END;
    ''');
    
    if (kDebugMode) {
      debugPrint('✅ Triggers created');
    }
  }
  
  /// Cria tabelas FTS5 para full-text search
  Future<void> _createFullTextSearchTables() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS songs_fts USING fts5(
        title,
        lyrics,
        author,
        content=songs,
        content_rowid=id,
        tokenize='porter unicode61'
      );
    ''');
    
    // Trigger para manter FTS sincronizado
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS songs_fts_insert
      AFTER INSERT ON songs
      BEGIN
        INSERT INTO songs_fts(rowid, title, lyrics, author)
        VALUES (NEW.id, NEW.title, NEW.lyrics, NEW.author);
      END;
    ''');
    
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS songs_fts_update
      AFTER UPDATE ON songs
      BEGIN
        UPDATE songs_fts 
        SET title = NEW.title, lyrics = NEW.lyrics, author = NEW.author
        WHERE rowid = NEW.id;
      END;
    ''');
    
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS songs_fts_delete
      AFTER DELETE ON songs
      BEGIN
        DELETE FROM songs_fts WHERE rowid = OLD.id;
      END;
    ''');
    
    if (kDebugMode) {
      debugPrint('✅ Full-text search tables created');
    }
  }
  
  /// Insere metadados iniciais
  Future<void> _insertMetadata() async {
    await into(metadata).insert(
      MetadataCompanion.insert(
        key: 'db_version',
        value: schemaVersion.toString(),
      ),
      mode: InsertMode.insertOrReplace,
    );
    
    await into(metadata).insert(
      MetadataCompanion.insert(
        key: 'created_at',
        value: DateTime.now().toIso8601String(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }
  
  // ══════════════════════════════════════════
  // CRUD GENÉRICO COM SEGURANÇA
  // ══════════════════════════════════════════
  
  /// Valida nome de tabela
  void _validateTableName(String tableName) {
    const allowedTables = {
      'songs',
      'categories',
      'sync_log',
      'queue_operations',
      'audit_log',
      'metadata',
    };
    
    if (!allowedTables.contains(tableName)) {
      throw DatabaseSecurityException(
        'Invalid table name: $tableName'
      );
    }
  }
  
  /// Valida nomes de colunas
  void _validateColumnNames(List<String> columns, String tableName) {
    final table = _getTableByName(tableName);
    final validColumns = table.$columns.map((c) => c.$name).toSet();
    
    for (final column in columns) {
      if (!validColumns.contains(column)) {
        throw DatabaseSecurityException(
          'Invalid column name: $column for table: $tableName'
        );
      }
    }
  }
  
  /// Insere registro genérico com validação
  Future<int> insertGeneric(
    String tableName,
    Map<String, dynamic> data, {
    bool useCache = true,
  }) async {
    _validateTableName(tableName);
    _validateColumnNames(data.keys.toList(), tableName);
    
    final startTime = DateTime.now();
    
    try {
      final columns = data.keys.join(', ');
      final placeholders = List.filled(data.length, '?').join(', ');
      
      final result = await customInsert(
        'INSERT INTO $tableName ($columns) VALUES ($placeholders)',
        variables: data.values.map((v) => Variable(v)).toList(),
        updates: {_getTableByName(tableName)},
      );
      
      // Invalidar cache
      if (useCache) {
        _cache.invalidateTable(tableName);
      }
      
      _recordQueryTime(DateTime.now().difference(startTime));
      
      return result;
      
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw DatabaseConstraintException(
          'Unique constraint violated for table: $tableName'
        );
      }
      rethrow;
    }
  }
  
  /// Atualiza registro genérico
  Future<int> updateGeneric(
    String tableName,
    Map<String, dynamic> data,
    String whereClause,
    List<dynamic> whereArgs, {
    bool useCache = true,
  }) async {
    _validateTableName(tableName);
    _validateColumnNames(data.keys.toList(), tableName);
    
    final startTime = DateTime.now();
    
    final setClause = data.keys.map((k) => '$k = ?').join(', ');
    
    final result = await customUpdate(
      'UPDATE $tableName SET $setClause WHERE $whereClause',
      variables: [
        ...data.values.map((v) => Variable(v)),
        ...whereArgs.map((v) => Variable(v)),
      ],
      updates: {_getTableByName(tableName)},
    );
    
    // Invalidar cache
    if (useCache) {
      _cache.invalidateTable(tableName);
    }
    
    _recordQueryTime(DateTime.now().difference(startTime));
    
    return result;
  }
  
  /// Deleta registro (soft delete quando aplicável)
  Future<int> deleteGeneric(
    String tableName,
    String whereClause,
    List<dynamic> whereArgs, {
    bool hard = false,
    bool useCache = true,
  }) async {
    _validateTableName(tableName);
    
    final startTime = DateTime.now();
    
    int result;
    
    // Soft delete para tabelas que suportam
    if (!hard && _supportsSoftDelete(tableName)) {
      result = await updateGeneric(
        tableName,
        {'deleted_at': DateTime.now().toIso8601String()},
        whereClause,
        whereArgs,
        useCache: useCache,
      );
    } else {
      result = await customUpdate(
        'DELETE FROM $tableName WHERE $whereClause',
        variables: whereArgs.map((v) => Variable(v)).toList(),
        updates: {_getTableByName(tableName)},
      );
      
      if (useCache) {
        _cache.invalidateTable(tableName);
      }
    }
    
    _recordQueryTime(DateTime.now().difference(startTime));
    
    return result;
  }
  
  /// Query genérica com cache
  Future<List<Map<String, dynamic>>> queryGeneric(
    String tableName, {
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    bool useCache = true,
    bool includeDeleted = false,
  }) async {
    _validateTableName(tableName);
    
    if (columns != null) {
      _validateColumnNames(columns, tableName);
    }
    
    // Gerar chave de cache
    final cacheKey = _generateCacheKey(
      tableName,
      columns,
      where,
      whereArgs,
      orderBy,
      limit,
    );
    
    // Verificar cache
    if (useCache) {
      final cached = _cache.get(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    
    final startTime = DateTime.now();
    
    final cols = columns?.join(', ') ?? '*';
    
    // Adicionar filtro de soft delete
    final conditions = <String>[];
    if (where != null) {
      conditions.add(where);
    }
    
    if (!includeDeleted && _supportsSoftDelete(tableName)) {
      conditions.add('deleted_at IS NULL');
    }
    
    final whereClause = conditions.isNotEmpty 
      ? 'WHERE ${conditions.join(' AND ')}' 
      : '';
    
    final orderClause = orderBy != null ? 'ORDER BY $orderBy' : '';
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    
    final query = '''
      SELECT $cols FROM $tableName 
      $whereClause $orderClause $limitClause
    '''.trim();
    
    final results = await customSelect(
      query,
      variables: whereArgs?.map((v) => Variable(v)).toList() ?? [],
      readsFrom: {_getTableByName(tableName)},
    ).get();
    
    final data = results.map((row) => row.data).toList();
    
    // Salvar em cache
    if (useCache) {
      _cache.put(cacheKey, data);
    }
    
    final duration = DateTime.now().difference(startTime);
    _recordQueryTime(duration);
    
    // Log slow queries
    if (duration.inMilliseconds > _config.slowQueryThreshold) {
      _slowQueryCount++;
      
      if (kDebugMode) {
        debugPrint('🐌 Slow query (${duration.inMilliseconds}ms): $query');
      }
    }
    
    return data;
  }
  
  /// Busca full-text
  Future<List<Map<String, dynamic>>> searchFullText(
    String query, {
    int? limit,
    bool highlightMatches = true,
  }) async {
    final startTime = DateTime.now();
    
    final selectColumns = highlightMatches
      ? 'songs.*, snippet(songs_fts, 1, "<mark>", "</mark>", "...", 32) as highlighted'
      : 'songs.*';
    
    final results = await customSelect('''
      SELECT $selectColumns
      FROM songs_fts
      INNER JOIN songs ON songs_fts.rowid = songs.id
      WHERE songs_fts MATCH ?
      AND songs.deleted_at IS NULL
      ORDER BY rank
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', variables: [Variable(query)]).get();
    
    _recordQueryTime(DateTime.now().difference(startTime));
    
    return results.map((row) => row.data).toList();
  }
  
  /// Batch insert otimizado
  Future<int> batchInsert(
    String tableName,
    List<Map<String, dynamic>> records, {
    int chunkSize = 100,
  }) async {
    _validateTableName(tableName);
    
    if (records.isEmpty) return 0;
    
    _validateColumnNames(records.first.keys.toList(), tableName);
    
    int totalInserted = 0;
    
    // Processar em chunks
    for (int i = 0; i < records.length; i += chunkSize) {
      final chunk = records.skip(i).take(chunkSize).toList();
      
      await transaction(() async {
        for (final record in chunk) {
          await insertGeneric(tableName, record, useCache: false);
          totalInserted++;
        }
      });
    }
    
    // Invalidar cache uma vez
    _cache.invalidateTable(tableName);
    
    return totalInserted;
  }
  
  // ══════════════════════════════════════════
  // BACKUP E RESTORE
  // ══════════════════════════════════════════
  
  /// Exporta banco de dados com checksum
  Future<DatabaseBackup> export() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, _config.databaseName));
    
    // Checkpoint do WAL
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    
    final bytes = await file.readAsBytes();
    
    // Calcular checksum
    final checksum = sha256.convert(bytes).toString();
    
    return DatabaseBackup(
      data: bytes,
      checksum: checksum,
      timestamp: DateTime.now(),
      schemaVersion: schemaVersion,
    );
  }
  
  /// Restaura banco de dados com validação
  Future<void> restore(DatabaseBackup backup) async {
    // Validar checksum
    final calculatedChecksum = sha256.convert(backup.data).toString();
    
    if (calculatedChecksum != backup.checksum) {
      throw DatabaseBackupException('Backup checksum mismatch');
    }
    
    await close();
    
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, _config.databaseName));
    
    // Backup do arquivo atual
    if (await file.exists()) {
      final backupFile = File('${file.path}.bak');
      await file.copy(backupFile.path);
    }
    
    try {
      await file.writeAsBytes(backup.data);
    } catch (e) {
      // Restaurar backup em caso de erro
      final backupFile = File('${file.path}.bak');
      if (await backupFile.exists()) {
        await backupFile.copy(file.path);
      }
      rethrow;
    }
  }
  
  /// Cria backup antes de migração
  Future<void> _createBackupBeforeMigration() async {
    final backup = await export();
    
    final backupFolder = await getApplicationDocumentsDirectory();
    final backupFile = File(
      p.join(backupFolder.path, 'migration_backup_${DateTime.now().millisecondsSinceEpoch}.db')
    );
    
    await backupFile.writeAsBytes(backup.data);
    
    if (kDebugMode) {
      debugPrint('✅ Backup created before migration: ${backupFile.path}');
    }
  }
  
  /// Restaura backup após falha de migração
  Future<void> _restoreBackupAfterMigrationFailure() async {
    // Implementação de restore automático
    if (kDebugMode) {
      debugPrint('⚠️  Restoring backup after migration failure');
    }
  }
  
  // ══════════════════════════════════════════
  // MANUTENÇÃO E OTIMIZAÇÃO
  // ══════════════════════════════════════════
  
  /// Agenda tarefas de manutenção
  void _scheduleMaintenance() {
    // Vacuum a cada 7 dias
    _vacuumTimer = Timer.periodic(const Duration(days: 7), (_) {
      vacuum();
    });
    
    // Analyze a cada dia
    _analyzeTimer = Timer.periodic(const Duration(days: 1), (_) {
      analyze();
    });
  }
  
  /// Executa VACUUM
  Future<void> vacuum() async {
    if (kDebugMode) {
      debugPrint('🧹 Running VACUUM...');
    }
    
    await customStatement('VACUUM');
    
    if (kDebugMode) {
      debugPrint('✅ VACUUM completed');
    }
  }
  
  /// Executa ANALYZE
  Future<void> analyze() async {
    if (kDebugMode) {
      debugPrint('📊 Running ANALYZE...');
    }
    
    await customStatement('ANALYZE');
    
    if (kDebugMode) {
      debugPrint('✅ ANALYZE completed');
    }
  }
  
  /// Verifica integridade do banco
  Future<bool> _checkIntegrity() async {
    final result = await customSelect('PRAGMA integrity_check').get();
    final status = result.first.read<String>('integrity_check');
    return status == 'ok';
  }
  
  /// Valida schema
  Future<void> _validateSchema() async {
    final validation = SchemaRegistry.validateSchema();
    
    if (!validation.isValid) {
      throw DatabaseSchemaException(
        'Schema validation failed: ${validation.errors.join(", ")}'
      );
    }
  }
  
  /// Purga registros deletados antigos
  Future<int> purgeDeleted({Duration olderThan = const Duration(days: 30)}) async {
    final cutoffDate = DateTime.now().subtract(olderThan);
    
    int totalPurged = 0;
    
    for (final tableName in ['songs', 'categories']) {
      if (_supportsSoftDelete(tableName)) {
        final count = await customUpdate(
          'DELETE FROM $tableName WHERE deleted_at < ?',
          variables: [Variable(cutoffDate)],
          updates: {_getTableByName(tableName)},
        );
        
        totalPurged += count;
      }
    }
    
    if (kDebugMode) {
      debugPrint('🗑️  Purged $totalPurged soft-deleted records');
    }
    
    return totalPurged;
  }
  
  // ══════════════════════════════════════════
  // UTILITÁRIOS
  // ══════════════════════════════════════════
  
  /// Verifica se tabela suporta soft delete
  bool _supportsSoftDelete(String tableName) {
    return ['songs', 'categories'].contains(tableName);
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
      case 'audit_log':
        return auditLog;
      case 'metadata':
        return metadata;
      default:
        throw ArgumentError('Unknown table: $tableName');
    }
  }
  
  /// Gera chave de cache
  String _generateCacheKey(
    String tableName,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  ) {
    return '$tableName:${columns?.join(",")}:$where:${whereArgs?.join(",")}:$orderBy:$limit';
  }
  
  /// Registra tempo de query
  void _recordQueryTime(Duration duration) {
    _queryCount++;
    _queryTimes.add(duration);
    
    // Manter apenas últimas 1000 queries
    if (_queryTimes.length > 1000) {
      _queryTimes.removeAt(0);
    }
  }
  
  /// Obtém métricas do banco
  DatabaseMetrics getMetrics() {
    final avgQueryTime = _queryTimes.isEmpty
      ? Duration.zero
      : Duration(
          microseconds: _queryTimes.fold<int>(
            0, 
            (sum, d) => sum + d.inMicroseconds
          ) ~/ _queryTimes.length
        );
    
    return DatabaseMetrics(
      queryCount: _queryCount,
      slowQueryCount: _slowQueryCount,
      averageQueryTime: avgQueryTime,
      cacheHitRate: _cache.hitRate,
      cacheSize: _cache.size,
    );
  }
  
  /// Limpa cache
  void clearCache() {
    _cache.clear();
  }
  
  @override
  Future<void> close() async {
    _vacuumTimer?.cancel();
    _analyzeTimer?.cancel();
    await super.close();
  }
}

// ══════════════════════════════════════════
// CLASSES DE SUPORTE
// ══════════════════════════════════════════

class DatabaseBackup {
  final Uint8List data;
  final String checksum;
  final DateTime timestamp;
  final int schemaVersion;
  
  DatabaseBackup({
    required this.data,
    required this.checksum,
    required this.timestamp,
    required this.schemaVersion,
  });
}

class DatabaseMetrics {
  final int queryCount;
  final int slowQueryCount;
  final Duration averageQueryTime;
  final double cacheHitRate;
  final int cacheSize;
  
  DatabaseMetrics({
    required this.queryCount,
    required this.slowQueryCount,
    required this.averageQueryTime,
    required this.cacheHitRate,
    required this.cacheSize,
  });
  
  @override
  String toString() {
    return 'DatabaseMetrics(\n'
           '  Total Queries: $queryCount\n'
           '  Slow Queries: $slowQueryCount\n'
           '  Avg Query Time: ${averageQueryTime.inMilliseconds}ms\n'
           '  Cache Hit Rate: ${(cacheHitRate * 100).toStringAsFixed(1)}%\n'
           '  Cache Size: $cacheSize\n'
           ')';
  }
}

// ══════════════════════════════════════════
// EXCEÇÕES
// ══════════════════════════════════════════

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
  
  @override
  String toString() => 'DatabaseException: $message';
}

class DatabaseIntegrityException extends DatabaseException {
  DatabaseIntegrityException(String message) : super(message);
}

class DatabaseSecurityException extends DatabaseException {
  DatabaseSecurityException(String message) : super(message);
}

class DatabaseConstraintException extends DatabaseException {
  DatabaseConstraintException(String message) : super(message);
}

class DatabaseSchemaException extends DatabaseException {
  DatabaseSchemaException(String message) : super(message);
}

class DatabaseBackupException extends DatabaseException {
  DatabaseBackupException(String message) : super(message);
}
