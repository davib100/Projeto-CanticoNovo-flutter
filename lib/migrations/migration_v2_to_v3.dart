// core/migrations/migration_v2_to_v3.dart
import 'package:drift/drift.dart';
import '../core/db/migration_manager.dart';

/// Migration v2 → v3: Adiciona auditoria e metadata avançada
/// 
/// Mudanças:
/// - Cria tabela audit_log para rastreamento de mudanças
/// - Cria tabela metadata para configurações globais
/// - Adiciona colunas extras em sync_log (retry_count)
/// - Adiciona coluna priority em queue_operations
/// - Adiciona coluna processed_at em queue_operations
/// - Cria triggers para auditoria automática
class MigrationV2ToV3 implements Migration {
  @override
  String get description => 'Add audit log and advanced metadata support';
  
  @override
  Future<void> migrate(Migrator migrator) async {
    // ══════════════════════════════════════════
    // CRIAR TABELA AUDIT_LOG
    // ══════════════════════════════════════════
    
    await migrator.database.customStatement('''
      CREATE TABLE audit_log (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        old_values TEXT,
        new_values TEXT,
        user_id TEXT,
        timestamp INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');
    
    // Índices para audit_log
    await migrator.database.customStatement(
      'CREATE INDEX idx_audit_table_record_v3 ON audit_log(table_name, record_id)'
    );
    
    await migrator.database.customStatement(
      'CREATE INDEX idx_audit_timestamp_v3 ON audit_log(timestamp DESC)'
    );
    
    // ══════════════════════════════════════════
    // CRIAR TABELA METADATA
    // ══════════════════════════════════════════
    
    await migrator.database.customStatement('''
      CREATE TABLE metadata (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');
    
    // ══════════════════════════════════════════
    // ATUALIZAR SYNC_LOG
    // ══════════════════════════════════════════
    
    await migrator.database.customStatement(
      'ALTER TABLE sync_log ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0'
    );
    
    // ══════════════════════════════════════════
    // ATUALIZAR QUEUE_OPERATIONS
    // ══════════════════════════════════════════
    
    await migrator.database.customStatement(
      'ALTER TABLE queue_operations ADD COLUMN priority INTEGER NOT NULL DEFAULT 50'
    );
    
    await migrator.database.customStatement(
      'ALTER TABLE queue_operations ADD COLUMN processed_at INTEGER'
    );
    
    // Recriar índice com prioridade
    await migrator.database.customStatement(
      'DROP INDEX IF EXISTS idx_queue_status'
    );
    
    await migrator.database.customStatement(
      'CREATE INDEX idx_queue_status_priority_v3 ON queue_operations(status, priority DESC, created_at ASC)'
    );
    
    // ══════════════════════════════════════════
    // CRIAR TRIGGERS DE AUDITORIA
    // ══════════════════════════════════════════
    
    // Trigger para INSERT em songs
    await migrator.database.customStatement('''
      CREATE TRIGGER audit_songs_insert_v3
      AFTER INSERT ON songs
      FOR EACH ROW
      BEGIN
        INSERT INTO audit_log (table_name, record_id, operation, new_values)
        VALUES (
          'songs',
          NEW.id,
          'INSERT',
          json_object(
            'title', NEW.title,
            'lyrics', NEW.lyrics,
            'author', NEW.author,
            'category_id', NEW.category_id
          )
        );
      END
    ''');
    
    // Trigger para UPDATE em songs
    await migrator.database.customStatement('''
      CREATE TRIGGER audit_songs_update_v3
      AFTER UPDATE ON songs
      FOR EACH ROW
      WHEN NEW.updated_at != OLD.updated_at
      BEGIN
        INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values)
        VALUES (
          'songs',
          NEW.id,
          'UPDATE',
          json_object('title', OLD.title, 'lyrics', OLD.lyrics),
          json_object('title', NEW.title, 'lyrics', NEW.lyrics)
        );
      END
    ''');
    
    // Trigger para soft DELETE em songs
    await migrator.database.customStatement('''
      CREATE TRIGGER audit_songs_delete_v3
      AFTER UPDATE OF deleted_at ON songs
      FOR EACH ROW
      WHEN NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL
      BEGIN
        INSERT INTO audit_log (table_name, record_id, operation)
        VALUES ('songs', OLD.id, 'DELETE');
      END
    ''');
    
    // Trigger para incrementar version automaticamente
    await migrator.database.customStatement('''
      CREATE TRIGGER increment_song_version_v3
      AFTER UPDATE ON songs
      FOR EACH ROW
      WHEN NEW.version = OLD.version
      BEGIN
        UPDATE songs SET version = version + 1 WHERE id = NEW.id;
      END
    ''');
    
    // Trigger para atualizar updated_at automaticamente
    await migrator.database.customStatement('''
      CREATE TRIGGER update_songs_timestamp_v3
      AFTER UPDATE ON songs
      FOR EACH ROW
      WHEN NEW.updated_at = OLD.updated_at
      BEGIN
        UPDATE songs SET updated_at = strftime('%s', 'now') WHERE id = NEW.id;
      END
    ''');
    
    // ══════════════════════════════════════════
    // CRIAR TABELA MIGRATION_HISTORY (se não existe)
    // ══════════════════════════════════════════
    
    await migrator.database.customStatement('''
      CREATE TABLE IF NOT EXISTS migration_history (
        version INTEGER NOT NULL PRIMARY KEY,
        description TEXT NOT NULL,
        applied_at TEXT NOT NULL
      )
    ''');
    
    // ══════════════════════════════════════════
    // REGISTRAR MIGRAÇÃO
    // ══════════════════════════════════════════
    
    await migrator.database.customInsert(
      'INSERT INTO migration_history (version, description, applied_at) VALUES (?, ?, ?)',
      variables: [
        Variable.withInt(3),
        Variable.withString(description),
        Variable.withString(DateTime.now().toIso8601String()),
      ],
    );
  }
}
