// core/migrations/migration_v3_to_v4.dart
import 'package:drift/drift.dart';
import '../core/db/migration_manager.dart';

/// Migration v3 → v4: Full-Text Search e otimizações avançadas
/// 
/// Mudanças:
/// - Cria FTS5 virtual table para busca full-text em songs
/// - Adiciona triggers para manter FTS sincronizado
/// - Cria índices compostos otimizados
/// - Adiciona suporte a conflict resolution
class MigrationV3ToV4 implements Migration {
  @override
  String get description => 'Add full-text search and advanced optimizations';
  
  @override
  Future<void> migrate(Migrator migrator) async {
    // ══════════════════════════════════════════
    // CRIAR FTS5 VIRTUAL TABLE
    // ══════════════════════════════════════════
    
    await migrator.database.customStatement('''
      CREATE VIRTUAL TABLE songs_fts USING fts5(
        title,
        lyrics,
        author,
        content=songs,
        content_rowid=id,
        tokenize='porter unicode61'
      )
    ''');
    
    // Popular FTS com dados existentes
    await migrator.database.customStatement('''
      INSERT INTO songs_fts(rowid, title, lyrics, author)
      SELECT id, title, lyrics, author FROM songs WHERE deleted_at IS NULL
    ''');
    
    // ══════════════════════════════════════════
    // TRIGGERS PARA FTS
    // ══════════════════════════════════════════
    
    // Trigger para INSERT
    await migrator.database.customStatement('''
      CREATE TRIGGER songs_fts_insert_v4
      AFTER INSERT ON songs
      BEGIN
        INSERT INTO songs_fts(rowid, title, lyrics, author)
        VALUES (NEW.id, NEW.title, NEW.lyrics, NEW.author);
      END
    ''');
    
    // Trigger para UPDATE
    await migrator.database.customStatement('''
      CREATE TRIGGER songs_fts_update_v4
      AFTER UPDATE ON songs
      BEGIN
        UPDATE songs_fts 
        SET title = NEW.title, lyrics = NEW.lyrics, author = NEW.author
        WHERE rowid = NEW.id;
      END
    ''');
    
    // Trigger para DELETE (hard delete)
    await migrator.database.customStatement('''
      CREATE TRIGGER songs_fts_delete_v4
      AFTER DELETE ON songs
      BEGIN
        DELETE FROM songs_fts WHERE rowid = OLD.id;
      END
    ''');
    
    // Trigger para soft delete (remover do FTS)
    await migrator.database.customStatement('''
      CREATE TRIGGER songs_fts_soft_delete_v4
      AFTER UPDATE OF deleted_at ON songs
      WHEN NEW.deleted_at IS NOT NULL
      BEGIN
        DELETE FROM songs_fts WHERE rowid = NEW.id;
      END
    ''');
    
    // ══════════════════════════════════════════
    // ÍNDICES COMPOSTOS OTIMIZADOS
    // ══════════════════════════════════════════
    
    // Índice composto para queries comuns (categoria + favorito)
    await migrator.database.customStatement('''
      CREATE INDEX idx_songs_category_favorite_v4 
      ON songs(category_id, is_favorite) 
      WHERE deleted_at IS NULL
    ''');
    
    // Índice para ordenação por data de atualização
    await migrator.database.customStatement(
      'CREATE INDEX idx_songs_updated_desc_v4 ON songs(updated_at DESC) WHERE deleted_at IS NULL'
    );
    
    // Índice para sync_log otimizado
    await migrator.database.customStatement(
      'CREATE INDEX idx_sync_entity_status_v4 ON sync_log(entity_type, entity_id, status)'
    );
    
    // ══════════════════════════════════════════
    // TABELA DE CONFLITOS
    // ══════════════════════════════════════════
    
    await migrator.database.customStatement('''
      CREATE TABLE conflict_log (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        local_data TEXT NOT NULL,
        server_data TEXT NOT NULL,
        strategy TEXT NOT NULL,
        winner TEXT NOT NULL,
        resolved_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');
    
    await migrator.database.customStatement(
      'CREATE INDEX idx_conflict_entity_v4 ON conflict_log(entity_type, entity_id)'
    );
    
    // ══════════════════════════════════════════
    // TABELA DE CONFLITOS MANUAIS
    // ══════════════════════════════════════════
    
    await migrator.database.customStatement('''
      CREATE TABLE manual_conflict_queue (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        local_data TEXT NOT NULL,
        server_data TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        resolved_at INTEGER
      )
    ''');
    
    await migrator.database.customStatement(
      'CREATE INDEX idx_manual_conflict_status_v4 ON manual_conflict_queue(status, created_at)'
    );
    
    // ══════════════════════════════════════════
    // OTIMIZAÇÕES DE PERFORMANCE
    // ══════════════════════════════════════════
    
    // Atualizar estatísticas do banco
    await migrator.database.customStatement('ANALYZE');
    
    // ══════════════════════════════════════════
    // REGISTRAR MIGRAÇÃO
    // ══════════════════════════════════════════
    
    await migrator.database.customInsert(
      'INSERT INTO migration_history (version, description, applied_at) VALUES (?, ?, ?)',
      variables: [
        Variable.withInt(4),
        Variable.withString(description),
        Variable.withString(DateTime.now().toIso8601String()),
      ],
    );
  }
}
