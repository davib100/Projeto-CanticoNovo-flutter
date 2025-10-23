import sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import fs from 'fs/promises';
import { config } from './env.mjs';
import { logger } from '../utils/logger.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

let db = null;

// ============================================================================
// DATABASE CONNECTION
// ============================================================================

/**
 * Inicializa conexão com SQLite e executa migrations
 * @returns {Promise<Database>} Instância do banco de dados
 */
export async function initDatabase() {
  try {
    // Garante que o diretório existe
    const dbDir = dirname(config.DATABASE_PATH);
    await fs.mkdir(dbDir, { recursive: true });
    
    // Abre conexão com SQLite
    db = await open({
      filename: config.DATABASE_PATH,
      driver: sqlite3.Database,
    });
    
    // Configurações de performance e segurança
    await db.exec(`
      PRAGMA journal_mode = WAL;           -- Write-Ahead Logging para melhor concorrência
      PRAGMA foreign_keys = ON;            -- Ativa integridade referencial
      PRAGMA synchronous = NORMAL;         -- Balance entre segurança e performance
      PRAGMA temp_store = MEMORY;          -- Armazena temporários em memória
      PRAGMA mmap_size = 268435456;        -- 256MB de memory-mapped I/O
      PRAGMA page_size = 4096;             -- Tamanho de página otimizado
      PRAGMA cache_size = -64000;          -- 64MB de cache
    `);
    
    logger.info('✅ Database initialized successfully', {
      path: config.DATABASE_PATH,
      mode: 'WAL',
      optimizations: 'enabled',
    });
    
    // Executa migrations
    await runMigrations();
    
    return db;
  } catch (error) {
    logger.error('❌ Failed to initialize database', { error: error.message });
    throw error;
  }
}

/**
 * Retorna instância ativa do banco de dados
 * @returns {Database} Instância do banco
 * @throws {Error} Se banco não foi inicializado
 */
export function getDatabase() {
  if (!db) {
    throw new Error('Database not initialized. Call initDatabase() first.');
  }
  return db;
}

/**
 * Fecha conexão com o banco de dados
 */
export async function closeDatabase() {
  if (db) {
    await db.close();
    db = null;
    logger.info('✅ Database connection closed');
  }
}

// ============================================================================
// MIGRATION SYSTEM
// ============================================================================

/**
 * Sistema de migrations com suporte a inline e external files
 */
async function runMigrations() {
  try {
    // Cria tabela de controle de migrations
    await createMigrationsTable();
    
    // Busca migrations já aplicadas
    const appliedMigrations = await getAppliedMigrations();
    
    // Define migrations inline (core do sistema)
    const migrations = [
      { name: '001_create_users', version: '001', fn: migration001CreateUsers },
      { name: '002_create_music', version: '002', fn: migration002CreateMusic },
      { name: '003_create_search_history', version: '003', fn: migration003CreateSearchHistory },
      { name: '004_create_sessions', version: '004', fn: migration004CreateSessions },
      { name: '005_create_analytics_tables', version: '005', fn: migration005CreateAnalyticsTables },
    ];
    
    // Executa migrations pendentes
    for (const migration of migrations) {
      await executeMigration(migration, appliedMigrations);
    }
    
    // Tenta carregar migrations externas (se existirem)
    await loadExternalMigrations(appliedMigrations);
    
    logger.info('✅ All migrations completed successfully');
  } catch (error) {
    logger.error('❌ Migration system failed', { error: error.message });
    throw error;
  }
}

/**
 * Cria tabela de controle de migrations
 */
async function createMigrationsTable() {
  await db.exec(`
    CREATE TABLE IF NOT EXISTS migrations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      version TEXT NOT NULL,
      executed_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE INDEX IF NOT EXISTS idx_migrations_version ON migrations(version);
  `);
}

/**
 * Retorna lista de migrations já aplicadas
 */
async function getAppliedMigrations() {
  const rows = await db.all('SELECT name FROM migrations ORDER BY id');
  return new Set(rows.map(row => row.name));
}

/**
 * Executa uma migration se ainda não foi aplicada
 */
async function executeMigration(migration, appliedMigrations) {
  if (appliedMigrations.has(migration.name)) {
    return; // Migration já aplicada
  }
  
  logger.info(`⏳ Running migration: ${migration.name} (v${migration.version})`);
  
  try {
    await migration.fn(db);
    
    await db.run(
      'INSERT INTO migrations (name, version) VALUES (?, ?)',
      [migration.name, migration.version]
    );
    
    logger.info(`✅ Migration completed: ${migration.name}`);
  } catch (error) {
    logger.error(`❌ Migration failed: ${migration.name}`, { error: error.message });
    throw error;
  }
}

/**
 * Carrega e executa migrations de arquivos externos (se existirem)
 */
async function loadExternalMigrations(appliedMigrations) {
  const migrationsDir = join(__dirname, '../migrations');
  
  try {
    const files = await fs.readdir(migrationsDir);
    const migrationFiles = files
      .filter(f => f.endsWith('.mjs') && f !== 'rollback.mjs' && f !== 'status.mjs')
      .sort();
    
    for (const file of migrationFiles) {
      const migrationPath = join(migrationsDir, file);
      const { up, metadata } = await import(migrationPath);
      
      if (metadata && !appliedMigrations.has(metadata.name)) {
        logger.info(`⏳ Running external migration: ${metadata.name} (v${metadata.version})`);
        
        await up(db);
        
        await db.run(
          'INSERT INTO migrations (name, version) VALUES (?, ?)',
          [metadata.name, metadata.version]
        );
        
        logger.info(`✅ External migration completed: ${metadata.name}`);
      }
    }
  } catch (error) {
    // Diretório de migrations externas não existe ou está vazio - isso é ok
    logger.debug('No external migrations found or directory not accessible');
  }
}

// ============================================================================
// INLINE MIGRATIONS
// ============================================================================

/**
 * Migration 001: Tabela de usuários
 */
async function migration001CreateUsers(db) {
  await db.exec(`
    -- Tabela de usuários com autenticação OAuth
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      full_name TEXT,
      profile_picture TEXT,
      oauth_provider TEXT CHECK(oauth_provider IN ('google', 'microsoft', 'facebook')),
      oauth_id TEXT,
      terms_accepted BOOLEAN DEFAULT 0,
      terms_accepted_at DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_login DATETIME,
      UNIQUE(oauth_provider, oauth_id)
    );
    
    -- Índices otimizados
    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    CREATE INDEX IF NOT EXISTS idx_users_oauth ON users(oauth_provider, oauth_id);
    CREATE INDEX IF NOT EXISTS idx_users_last_login ON users(last_login DESC);
  `);
}

/**
 * Migration 002: Tabela de músicas com Full-Text Search
 */
async function migration002CreateMusic(db) {
  await db.exec(`
    -- Tabela principal de músicas
    CREATE TABLE IF NOT EXISTS music (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      artist TEXT,
      lyrics TEXT NOT NULL,
      chords TEXT,
      category_id TEXT,
      genre TEXT CHECK(genre IN ('gospel', 'hino', 'contemporaneo', 'tradicional', 'louvor', 'adoracao')),
      key TEXT,
      tempo TEXT CHECK(tempo IN ('lento', 'moderado', 'rapido')),
      duration TEXT,
      sheet_music_url TEXT,
      audio_url TEXT,
      tags TEXT,  -- JSON array serializado
      last_accessed DATETIME,
      access_count INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Índices principais
    CREATE INDEX IF NOT EXISTS idx_music_title ON music(title COLLATE NOCASE);
    CREATE INDEX IF NOT EXISTS idx_music_artist ON music(artist COLLATE NOCASE);
    CREATE INDEX IF NOT EXISTS idx_music_genre ON music(genre);
    CREATE INDEX IF NOT EXISTS idx_music_category ON music(category_id);
    CREATE INDEX IF NOT EXISTS idx_music_access ON music(access_count DESC, last_accessed DESC);
    CREATE INDEX IF NOT EXISTS idx_music_created ON music(created_at DESC);
    
    -- Full-Text Search (FTS5) para busca otimizada
    CREATE VIRTUAL TABLE IF NOT EXISTS music_fts USING fts5(
      id UNINDEXED,
      title,
      artist,
      lyrics,
      content=music,
      content_rowid=rowid,
      tokenize='porter unicode61'
    );
    
    -- Triggers para sincronizar FTS automaticamente
    CREATE TRIGGER IF NOT EXISTS music_fts_insert 
    AFTER INSERT ON music 
    BEGIN
      INSERT INTO music_fts(rowid, id, title, artist, lyrics)
      VALUES (new.rowid, new.id, new.title, new.artist, new.lyrics);
    END;
    
    CREATE TRIGGER IF NOT EXISTS music_fts_update 
    AFTER UPDATE ON music 
    BEGIN
      UPDATE music_fts 
      SET title = new.title, 
          artist = new.artist, 
          lyrics = new.lyrics
      WHERE rowid = old.rowid;
    END;
    
    CREATE TRIGGER IF NOT EXISTS music_fts_delete 
    AFTER DELETE ON music 
    BEGIN
      DELETE FROM music_fts WHERE rowid = old.rowid;
    END;
    
    -- Trigger para atualizar updated_at automaticamente
    CREATE TRIGGER IF NOT EXISTS music_updated_at 
    AFTER UPDATE ON music
    BEGIN
      UPDATE music SET updated_at = CURRENT_TIMESTAMP WHERE id = old.id;
    END;
  `);
}

/**
 * Migration 003: Histórico de buscas
 */
async function migration003CreateSearchHistory(db) {
  await db.exec(`
    -- Tabela de histórico de buscas
    CREATE TABLE IF NOT EXISTS search_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      query TEXT NOT NULL,
      results_count INTEGER DEFAULT 0,
      searched_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    
    -- Índices otimizados para queries comuns
    CREATE INDEX IF NOT EXISTS idx_search_history_user ON search_history(user_id);
    CREATE INDEX IF NOT EXISTS idx_search_history_query ON search_history(query COLLATE NOCASE);
    CREATE INDEX IF NOT EXISTS idx_search_history_date ON search_history(searched_at DESC);
    CREATE INDEX IF NOT EXISTS idx_search_history_user_date ON search_history(user_id, searched_at DESC);
    
    -- View: Buscas populares (últimos 30 dias)
    CREATE VIEW IF NOT EXISTS v_popular_searches_30d AS
    SELECT 
      LOWER(query) as normalized_query,
      COUNT(*) as search_count,
      COUNT(DISTINCT user_id) as unique_users,
      AVG(results_count) as avg_results,
      MAX(searched_at) as last_searched
    FROM search_history
    WHERE searched_at >= date('now', '-30 days')
    GROUP BY LOWER(query)
    ORDER BY search_count DESC;
  `);
}

/**
 * Migration 004: Sessões de usuário
 */
async function migration004CreateSessions(db) {
  await db.exec(`
    -- Tabela de sessões (single-device enforcement)
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      device_name TEXT,
      device_os TEXT,
      refresh_token TEXT NOT NULL,
      expires_at DATETIME NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_used DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(user_id, device_id)
    );
    
    -- Índices para queries de autenticação
    CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
    CREATE INDEX IF NOT EXISTS idx_sessions_device ON sessions(device_id);
    CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(refresh_token);
    CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);
    
    -- Índice para limpeza de sessões expiradas
    CREATE INDEX IF NOT EXISTS idx_sessions_expired 
      ON sessions(expires_at) WHERE expires_at < CURRENT_TIMESTAMP;
  `);
}

/**
 * Migration 005: Analytics e tracking
 */
async function migration005CreateAnalyticsTables(db) {
  await db.exec(`
    -- ========================================
    -- Tabela: music_access_log
    -- Log detalhado de acessos a músicas
    -- ========================================
    CREATE TABLE IF NOT EXISTS music_access_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      music_id TEXT NOT NULL,
      user_id TEXT,
      ip_address TEXT,
      user_agent TEXT,
      accessed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (music_id) REFERENCES music(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
    );
    
    CREATE INDEX IF NOT EXISTS idx_music_access_log_music ON music_access_log(music_id);
    CREATE INDEX IF NOT EXISTS idx_music_access_log_user ON music_access_log(user_id);
    CREATE INDEX IF NOT EXISTS idx_music_access_log_date ON music_access_log(accessed_at DESC);
    CREATE INDEX IF NOT EXISTS idx_music_access_log_music_date ON music_access_log(music_id, accessed_at DESC);
    
    -- ========================================
    -- Tabela: quick_access_log
    -- Log de ações no acesso rápido
    -- ========================================
    CREATE TABLE IF NOT EXISTS quick_access_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      music_id TEXT NOT NULL,
      action TEXT CHECK(action IN ('add', 'remove', 'reorder')) NOT NULL,
      position INTEGER,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (music_id) REFERENCES music(id) ON DELETE CASCADE
    );
    
    CREATE INDEX IF NOT EXISTS idx_quick_access_log_user ON quick_access_log(user_id);
    CREATE INDEX IF NOT EXISTS idx_quick_access_log_music ON quick_access_log(music_id);
    CREATE INDEX IF NOT EXISTS idx_quick_access_log_date ON quick_access_log(created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_quick_access_log_action ON quick_access_log(user_id, action);
    
    -- ========================================
    -- Tabela: user_activity_summary
    -- Resumo agregado de atividade diária
    -- ========================================
    CREATE TABLE IF NOT EXISTS user_activity_summary (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      activity_date DATE NOT NULL,
      searches_count INTEGER DEFAULT 0,
      music_accesses_count INTEGER DEFAULT 0,
      quick_access_changes_count INTEGER DEFAULT 0,
      unique_music_accessed INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(user_id, activity_date)
    );
    
    CREATE INDEX IF NOT EXISTS idx_user_activity_summary_user ON user_activity_summary(user_id);
    CREATE INDEX IF NOT EXISTS idx_user_activity_summary_date ON user_activity_summary(activity_date DESC);
    
    -- ========================================
    -- Views analíticas
    -- ========================================
    
    -- View: Músicas mais acessadas (últimos 30 dias)
    CREATE VIEW IF NOT EXISTS v_popular_music_30d AS
    SELECT 
      m.id,
      m.title,
      m.artist,
      m.genre,
      COUNT(mal.id) as access_count_30d,
      COUNT(DISTINCT mal.user_id) as unique_users_30d,
      MAX(mal.accessed_at) as last_accessed
    FROM music m
    LEFT JOIN music_access_log mal 
      ON m.id = mal.music_id 
      AND mal.accessed_at >= date('now', '-30 days')
    GROUP BY m.id
    ORDER BY access_count_30d DESC;
    
    -- View: Atividade diária agregada
    CREATE VIEW IF NOT EXISTS v_daily_activity AS
    SELECT 
      date(searched_at) as activity_date,
      COUNT(DISTINCT user_id) as active_users,
      COUNT(*) as total_searches,
      AVG(results_count) as avg_results
    FROM search_history
    WHERE searched_at >= date('now', '-90 days')
    GROUP BY date(searched_at)
    ORDER BY activity_date DESC;
    
    -- ========================================
    -- Triggers para manutenção automática
    -- ========================================
    
    -- Trigger: Atualiza resumo ao registrar busca
    CREATE TRIGGER IF NOT EXISTS trg_update_activity_on_search
    AFTER INSERT ON search_history
    FOR EACH ROW
    BEGIN
      INSERT INTO user_activity_summary (user_id, activity_date, searches_count, updated_at)
      VALUES (NEW.user_id, date(NEW.searched_at), 1, CURRENT_TIMESTAMP)
      ON CONFLICT(user_id, activity_date) DO UPDATE SET
        searches_count = searches_count + 1,
        updated_at = CURRENT_TIMESTAMP;
    END;
    
    -- Trigger: Atualiza resumo ao registrar acesso
    CREATE TRIGGER IF NOT EXISTS trg_update_activity_on_access
    AFTER INSERT ON music_access_log
    FOR EACH ROW
    WHEN NEW.user_id IS NOT NULL
    BEGIN
      INSERT INTO user_activity_summary (user_id, activity_date, music_accesses_count, updated_at)
      VALUES (NEW.user_id, date(NEW.accessed_at), 1, CURRENT_TIMESTAMP)
      ON CONFLICT(user_id, activity_date) DO UPDATE SET
        music_accesses_count = music_accesses_count + 1,
        updated_at = CURRENT_TIMESTAMP;
    END;
    
    -- Trigger: Atualiza resumo ao modificar quick access
    CREATE TRIGGER IF NOT EXISTS trg_update_activity_on_quick_access
    AFTER INSERT ON quick_access_log
    FOR EACH ROW
    BEGIN
      INSERT INTO user_activity_summary (user_id, activity_date, quick_access_changes_count, updated_at)
      VALUES (NEW.user_id, date(NEW.created_at), 1, CURRENT_TIMESTAMP)
      ON CONFLICT(user_id, activity_date) DO UPDATE SET
        quick_access_changes_count = quick_access_changes_count + 1,
        updated_at = CURRENT_TIMESTAMP;
    END;
  `);
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Verifica integridade do banco de dados
 */
export async function checkDatabaseIntegrity() {
  try {
    const result = await db.get('PRAGMA integrity_check');
    const isHealthy = result.integrity_check === 'ok';
    
    logger.info('Database integrity check', {
      status: isHealthy ? 'healthy' : 'corrupted',
      result: result.integrity_check,
    });
    
    return isHealthy;
  } catch (error) {
    logger.error('Failed to check database integrity', { error: error.message });
    return false;
  }
}

/**
 * Otimiza banco de dados (VACUUM + ANALYZE)
 */
export async function optimizeDatabase() {
  try {
    logger.info('Starting database optimization...');
    
    await db.exec('VACUUM;');
    await db.exec('ANALYZE;');
    
    logger.info('✅ Database optimization completed');
  } catch (error) {
    logger.error('Failed to optimize database', { error: error.message });
    throw error;
  }
}

/**
 * Retorna estatísticas do banco de dados
 */
export async function getDatabaseStats() {
  try {
    const stats = await db.get(`
      SELECT 
        page_count * page_size / 1024 / 1024 as size_mb,
        page_count,
        page_size
      FROM pragma_page_count(), pragma_page_size()
    `);
    
    const tables = await db.all(`
      SELECT name, (SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND tbl_name=m.name) as index_count
      FROM sqlite_master m
      WHERE type='table' AND name NOT LIKE 'sqlite_%'
      ORDER BY name
    `);
    
    return {
      size_mb: Math.round(stats.size_mb * 100) / 100,
      page_count: stats.page_count,
      page_size: stats.page_size,
      tables: tables.length,
      table_list: tables,
    };
  } catch (error) {
    logger.error('Failed to get database stats', { error: error.message });
    throw error;
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

export default {
  initDatabase,
  getDatabase,
  closeDatabase,
  checkDatabaseIntegrity,
  optimizeDatabase,
  getDatabaseStats,
};

import sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import { config } from './env.mjs';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let db = null;

export async function initDatabase() {
  try {
    // Criar diretório do banco se não existir
    const dbDir = path.dirname(config.DB_PATH);
    if (!fs.existsSync(dbDir)) {
      fs.mkdirSync(dbDir, { recursive: true });
    }

    // Abrir conexão com SQLite
    db = await open({
      filename: config.DB_PATH,
      driver: sqlite3.Database,
    });

    // Habilitar WAL mode para melhor concorrência
    await db.exec('PRAGMA journal_mode = WAL');
    await db.exec('PRAGMA foreign_keys = ON');

    console.log('✅ Database connected successfully');

    // Executar migrations
    await runMigrations();

    return db;
  } catch (error) {
    console.error('❌ Database connection failed:', error);
    throw error;
  }
}

async function runMigrations() {
  try {
    // Criar tabela de migrations se não existir
    await db.exec(`
      CREATE TABLE IF NOT EXISTS migrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        executed_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Ler arquivos de migration
    const migrationsDir = path.join(__dirname, '..', 'migrations');
    
    if (!fs.existsSync(migrationsDir)) {
      console.log('⚠️  No migrations directory found');
      return;
    }

    const migrationFiles = fs
      .readdirSync(migrationsDir)
      .filter(file => file.endsWith('.sql'))
      .sort();

    for (const file of migrationFiles) {
      const migrationName = file;

      // Verificar se já foi executada
      const executed = await db.get(
        'SELECT * FROM migrations WHERE name = ?',
        [migrationName]
      );

      if (!executed) {
        console.log(`🔄 Running migration: ${migrationName}`);

        const migrationPath = path.join(migrationsDir, file);
        const sql = fs.readFileSync(migrationPath, 'utf8');

        await db.exec(sql);
        await db.run(
          'INSERT INTO migrations (name) VALUES (?)',
          [migrationName]
        );

        console.log(`✅ Migration completed: ${migrationName}`);
      }
    }

    console.log('✅ All migrations completed');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  }
}

export function getDatabase() {
  if (!db) {
    throw new Error('Database not initialized. Call initDatabase() first.');
  }
  return db;
}

export async function closeDatabase() {
  if (db) {
    await db.close();
    db = null;
    console.log('✅ Database connection closed');
  }
}

export default {
  initDatabase,
  getDatabase,
  closeDatabase,
};
