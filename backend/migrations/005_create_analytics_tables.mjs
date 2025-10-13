/**
 * Migration 005: Create Analytics Tables
 * 
 * Cria tabelas para tracking e analytics:
 * - music_access_log: Log de acessos a músicas
 * - quick_access_log: Log de adições/remoções do acesso rápido
 * 
 * @param {Database} db - Instância do banco de dados SQLite
 */
export async function up(db) {
    console.log('Running migration 005: Create Analytics Tables...');
  
    await db.exec(`
      -- ========================================
      -- Tabela: music_access_log
      -- Descrição: Registra todos os acessos a músicas
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
      
      -- Índices para otimização de queries
      CREATE INDEX IF NOT EXISTS idx_music_access_log_music 
        ON music_access_log(music_id);
      
      CREATE INDEX IF NOT EXISTS idx_music_access_log_user 
        ON music_access_log(user_id);
      
      CREATE INDEX IF NOT EXISTS idx_music_access_log_date 
        ON music_access_log(accessed_at DESC);
      
      CREATE INDEX IF NOT EXISTS idx_music_access_log_music_date 
        ON music_access_log(music_id, accessed_at DESC);
      
      -- ========================================
      -- Tabela: quick_access_log
      -- Descrição: Registra adições/remoções do acesso rápido
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
      
      -- Índices para otimização
      CREATE INDEX IF NOT EXISTS idx_quick_access_log_user 
        ON quick_access_log(user_id);
      
      CREATE INDEX IF NOT EXISTS idx_quick_access_log_music 
        ON quick_access_log(music_id);
      
      CREATE INDEX IF NOT EXISTS idx_quick_access_log_date 
        ON quick_access_log(created_at DESC);
      
      CREATE INDEX IF NOT EXISTS idx_quick_access_log_user_action 
        ON quick_access_log(user_id, action);
      
      -- ========================================
      -- Tabela: user_activity_summary
      -- Descrição: Resumo agregado de atividade diária
      -- ========================================
      CREATE TABLE IF NOT EXISTS user_activity_summary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        activity_date DATE NOT NULL,
        searches_count INTEGER DEFAULT 0,
        music_accesses_count INTEGER DEFAULT 0,
        quick_access_changes_count INTEGER DEFAULT 0,
        unique_music_accessed INTEGER DEFAULT 0,
        total_time_spent_minutes INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE(user_id, activity_date)
      );
      
      CREATE INDEX IF NOT EXISTS idx_user_activity_summary_user 
        ON user_activity_summary(user_id);
      
      CREATE INDEX IF NOT EXISTS idx_user_activity_summary_date 
        ON user_activity_summary(activity_date DESC);
      
      -- ========================================
      -- Tabela: music_popularity_snapshot
      -- Descrição: Snapshots periódicos de popularidade
      -- ========================================
      CREATE TABLE IF NOT EXISTS music_popularity_snapshot (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        music_id TEXT NOT NULL,
        snapshot_date DATE NOT NULL,
        access_count_7d INTEGER DEFAULT 0,
        access_count_30d INTEGER DEFAULT 0,
        unique_users_7d INTEGER DEFAULT 0,
        unique_users_30d INTEGER DEFAULT 0,
        search_appearances_7d INTEGER DEFAULT 0,
        search_appearances_30d INTEGER DEFAULT 0,
        popularity_score REAL DEFAULT 0,
        trending_score REAL DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (music_id) REFERENCES music(id) ON DELETE CASCADE,
        UNIQUE(music_id, snapshot_date)
      );
      
      CREATE INDEX IF NOT EXISTS idx_music_popularity_snapshot_music 
        ON music_popularity_snapshot(music_id);
      
      CREATE INDEX IF NOT EXISTS idx_music_popularity_snapshot_date 
        ON music_popularity_snapshot(snapshot_date DESC);
      
      CREATE INDEX IF NOT EXISTS idx_music_popularity_snapshot_score 
        ON music_popularity_snapshot(popularity_score DESC);
      
      CREATE INDEX IF NOT EXISTS idx_music_popularity_snapshot_trending 
        ON music_popularity_snapshot(trending_score DESC);
      
      -- ========================================
      -- Tabela: search_analytics
      -- Descrição: Analytics avançados de buscas
      -- ========================================
      CREATE TABLE IF NOT EXISTS search_analytics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        search_history_id INTEGER NOT NULL,
        query_normalized TEXT NOT NULL,
        query_length INTEGER,
        results_clicked INTEGER DEFAULT 0,
        first_result_clicked_position INTEGER,
        time_to_first_click_ms INTEGER,
        session_duration_ms INTEGER,
        device_type TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (search_history_id) REFERENCES search_history(id) ON DELETE CASCADE
      );
      
      CREATE INDEX IF NOT EXISTS idx_search_analytics_query 
        ON search_analytics(query_normalized);
      
      CREATE INDEX IF NOT EXISTS idx_search_analytics_date 
        ON search_analytics(created_at DESC);
      
      -- ========================================
      -- Views para facilitar queries
      -- ========================================
      
      -- View: Músicas mais acessadas (últimos 30 dias)
      CREATE VIEW IF NOT EXISTS v_popular_music_30d AS
      SELECT 
        m.id,
        m.title,
        m.artist,
        m.genre,
        COUNT(mal.id) as access_count,
        COUNT(DISTINCT mal.user_id) as unique_users,
        MAX(mal.accessed_at) as last_accessed
      FROM music m
      LEFT JOIN music_access_log mal 
        ON m.id = mal.music_id 
        AND mal.accessed_at >= date('now', '-30 days')
      GROUP BY m.id
      ORDER BY access_count DESC;
      
      -- View: Atividade diária de usuários
      CREATE VIEW IF NOT EXISTS v_daily_user_activity AS
      SELECT 
        date(searched_at) as activity_date,
        COUNT(DISTINCT user_id) as active_users,
        COUNT(*) as total_searches,
        AVG(results_count) as avg_results_per_search
      FROM search_history
      WHERE searched_at >= date('now', '-90 days')
      GROUP BY date(searched_at)
      ORDER BY activity_date DESC;
      
      -- View: Top buscas sem resultado
      CREATE VIEW IF NOT EXISTS v_zero_result_searches AS
      SELECT 
        query,
        COUNT(*) as search_count,
        COUNT(DISTINCT user_id) as unique_users,
        MAX(searched_at) as last_searched
      FROM search_history
      WHERE results_count = 0
        AND searched_at >= date('now', '-30 days')
      GROUP BY LOWER(query)
      ORDER BY search_count DESC;
      
      -- ========================================
      -- Triggers para manutenção automática
      -- ========================================
      
      -- Trigger: Atualiza resumo de atividade ao registrar busca
      CREATE TRIGGER IF NOT EXISTS trg_update_activity_on_search
      AFTER INSERT ON search_history
      BEGIN
        INSERT INTO user_activity_summary (
          user_id, 
          activity_date, 
          searches_count,
          updated_at
        )
        VALUES (
          NEW.user_id,
          date(NEW.searched_at),
          1,
          CURRENT_TIMESTAMP
        )
        ON CONFLICT(user_id, activity_date) DO UPDATE SET
          searches_count = searches_count + 1,
          updated_at = CURRENT_TIMESTAMP;
      END;
      
      -- Trigger: Atualiza resumo de atividade ao registrar acesso a música
      CREATE TRIGGER IF NOT EXISTS trg_update_activity_on_music_access
      AFTER INSERT ON music_access_log
      WHEN NEW.user_id IS NOT NULL
      BEGIN
        INSERT INTO user_activity_summary (
          user_id, 
          activity_date, 
          music_accesses_count,
          updated_at
        )
        VALUES (
          NEW.user_id,
          date(NEW.accessed_at),
          1,
          CURRENT_TIMESTAMP
        )
        ON CONFLICT(user_id, activity_date) DO UPDATE SET
          music_accesses_count = music_accesses_count + 1,
          updated_at = CURRENT_TIMESTAMP;
      END;
      
      -- Trigger: Atualiza resumo ao adicionar/remover quick access
      CREATE TRIGGER IF NOT EXISTS trg_update_activity_on_quick_access
      AFTER INSERT ON quick_access_log
      BEGIN
        INSERT INTO user_activity_summary (
          user_id, 
          activity_date, 
          quick_access_changes_count,
          updated_at
        )
        VALUES (
          NEW.user_id,
          date(NEW.created_at),
          1,
          CURRENT_TIMESTAMP
        )
        ON CONFLICT(user_id, activity_date) DO UPDATE SET
          quick_access_changes_count = quick_access_changes_count + 1,
          updated_at = CURRENT_TIMESTAMP;
      END;
    `);
  
    console.log('✅ Migration 005 completed successfully');
  }
  
  /**
   * Rollback da migration 005
   */
  export async function down(db) {
    console.log('Rolling back migration 005: Create Analytics Tables...');
  
    await db.exec(`
      -- Remove triggers
      DROP TRIGGER IF EXISTS trg_update_activity_on_search;
      DROP TRIGGER IF EXISTS trg_update_activity_on_music_access;
      DROP TRIGGER IF EXISTS trg_update_activity_on_quick_access;
      
      -- Remove views
      DROP VIEW IF EXISTS v_popular_music_30d;
      DROP VIEW IF EXISTS v_daily_user_activity;
      DROP VIEW IF EXISTS v_zero_result_searches;
      
      -- Remove tables
      DROP TABLE IF EXISTS search_analytics;
      DROP TABLE IF EXISTS music_popularity_snapshot;
      DROP TABLE IF EXISTS user_activity_summary;
      DROP TABLE IF EXISTS quick_access_log;
      DROP TABLE IF EXISTS music_access_log;
    `);
  
    console.log('✅ Migration 005 rolled back successfully');
  }
  
  /**
   * Metadata da migration
   */
  export const metadata = {
    version: '005',
    name: 'create_analytics_tables',
    description: 'Creates analytics and tracking tables with views and triggers',
    author: 'Cântico Novo Team',
    createdAt: '2025-10-12',
  };
  