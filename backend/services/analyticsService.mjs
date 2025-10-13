import { getDatabase } from '../config/database.mjs';
import { logger } from '../utils/logger.mjs';
import { addBreadcrumb } from '../config/sentry.mjs';

/**
 * Service de Analytics e Métricas
 * 
 * Responsabilidades:
 * - Tracking de eventos (buscas, acessos, clicks)
 * - Métricas de popularidade de músicas
 * - Analytics de comportamento de usuários
 * - Relatórios e dashboards
 * - Detecção de tendências
 */
export class AnalyticsService {
  
  /**
   * Registra evento de busca
   */
  static async trackSearch(userId, query, resultsCount) {
    try {
      const db = getDatabase();
      
      await db.run(
        `INSERT INTO search_history (user_id, query, results_count, searched_at)
         VALUES (?, ?, ?, CURRENT_TIMESTAMP)`,
        [userId, query, resultsCount]
      );

      // Breadcrumb para Sentry
      addBreadcrumb('Search tracked', {
        userId,
        query,
        resultsCount,
      });

      logger.info('Search event tracked', {
        userId,
        query,
        resultsCount,
      });
    } catch (error) {
      logger.error('Failed to track search', {
        userId,
        query,
        error: error.message,
      });
      // Não lança erro - analytics não deve interromper fluxo
    }
  }

  /**
   * Registra evento de acesso a música
   */
  static async trackMusicAccess(musicId, userId = null) {
    try {
      const db = getDatabase();
      
      // Incrementa contador de acesso
      await db.run(
        `UPDATE music 
         SET access_count = access_count + 1,
             last_accessed = CURRENT_TIMESTAMP
         WHERE id = ?`,
        musicId
      );

      // Log de acesso
      await db.run(
        `INSERT INTO music_access_log (music_id, user_id, accessed_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)`,
        [musicId, userId]
      );

      logger.info('Music access tracked', { musicId, userId });
    } catch (error) {
      logger.error('Failed to track music access', {
        musicId,
        userId,
        error: error.message,
      });
    }
  }

  /**
   * Registra adição ao acesso rápido
   */
  static async trackQuickAccessAdd(userId, musicId) {
    try {
      const db = getDatabase();
      
      await db.run(
        `INSERT INTO quick_access_log (user_id, music_id, action, created_at)
         VALUES (?, ?, 'add', CURRENT_TIMESTAMP)`,
        [userId, musicId]
      );

      logger.info('Quick access add tracked', { userId, musicId });
    } catch (error) {
      logger.error('Failed to track quick access add', {
        userId,
        musicId,
        error: error.message,
      });
    }
  }

  /**
   * Busca músicas mais populares
   */
  static async getMostPopularMusic(limit = 10, timeframe = '30days') {
    try {
      const db = getDatabase();
      
      let dateFilter = '';
      
      if (timeframe === '7days') {
        dateFilter = "AND last_accessed >= date('now', '-7 days')";
      } else if (timeframe === '30days') {
        dateFilter = "AND last_accessed >= date('now', '-30 days')";
      } else if (timeframe === '90days') {
        dateFilter = "AND last_accessed >= date('now', '-90 days')";
      }

      const results = await db.all(
        `SELECT 
           id, 
           title, 
           artist, 
           genre,
           access_count,
           last_accessed,
           (SELECT COUNT(*) FROM music_access_log WHERE music_id = music.id ${dateFilter ? "AND accessed_at >= date('now', '-" + timeframe.replace('days', '') + " days')" : ''}) as recent_access_count
         FROM music
         WHERE access_count > 0 ${dateFilter}
         ORDER BY recent_access_count DESC, access_count DESC
         LIMIT ?`,
        limit
      );

      logger.info('Most popular music fetched', {
        limit,
        timeframe,
        resultsCount: results.length,
      });

      return results;
    } catch (error) {
      logger.error('Failed to get most popular music', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Busca termos de busca mais populares
   */
  static async getTopSearchTerms(limit = 20, timeframe = '30days') {
    try {
      const db = getDatabase();
      
      let dateFilter = '';
      
      if (timeframe === '7days') {
        dateFilter = "WHERE searched_at >= date('now', '-7 days')";
      } else if (timeframe === '30days') {
        dateFilter = "WHERE searched_at >= date('now', '-30 days')";
      } else if (timeframe === '90days') {
        dateFilter = "WHERE searched_at >= date('now', '-90 days')";
      }

      const results = await db.all(
        `SELECT 
           query,
           COUNT(*) as search_count,
           AVG(results_count) as avg_results,
           MAX(searched_at) as last_searched
         FROM search_history
         ${dateFilter}
         GROUP BY LOWER(query)
         ORDER BY search_count DESC
         LIMIT ?`,
        limit
      );

      logger.info('Top search terms fetched', {
        limit,
        timeframe,
        resultsCount: results.length,
      });

      return results;
    } catch (error) {
      logger.error('Failed to get top search terms', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Estatísticas gerais do sistema
   */
  static async getSystemStats() {
    try {
      const db = getDatabase();
      
      // Total de músicas
      const totalMusic = await db.get(
        'SELECT COUNT(*) as count FROM music'
      );

      // Total de usuários
      const totalUsers = await db.get(
        'SELECT COUNT(*) as count FROM users'
      );

      // Total de buscas (último mês)
      const totalSearches = await db.get(
        `SELECT COUNT(*) as count 
         FROM search_history 
         WHERE searched_at >= date('now', '-30 days')`
      );

      // Total de acessos (último mês)
      const totalAccesses = await db.get(
        `SELECT COUNT(*) as count 
         FROM music_access_log 
         WHERE accessed_at >= date('now', '-30 days')`
      );

      // Usuários ativos (último mês)
      const activeUsers = await db.get(
        `SELECT COUNT(DISTINCT user_id) as count 
         FROM search_history 
         WHERE searched_at >= date('now', '-30 days')`
      );

      // Gêneros mais populares
      const topGenres = await db.all(
        `SELECT 
           genre,
           COUNT(*) as count,
           SUM(access_count) as total_accesses
         FROM music
         WHERE genre IS NOT NULL
         GROUP BY genre
         ORDER BY total_accesses DESC
         LIMIT 5`
      );

      // Taxa de sucesso de buscas (com resultados)
      const searchSuccess = await db.get(
        `SELECT 
           COUNT(CASE WHEN results_count > 0 THEN 1 END) * 100.0 / COUNT(*) as success_rate
         FROM search_history
         WHERE searched_at >= date('now', '-30 days')`
      );

      const stats = {
        totalMusic: totalMusic.count,
        totalUsers: totalUsers.count,
        totalSearches: totalSearches.count,
        totalAccesses: totalAccesses.count,
        activeUsers: activeUsers.count,
        topGenres: topGenres,
        searchSuccessRate: parseFloat(searchSuccess.success_rate || 0).toFixed(2),
        timestamp: new Date().toISOString(),
      };

      logger.info('System stats fetched', stats);

      return stats;
    } catch (error) {
      logger.error('Failed to get system stats', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Estatísticas de usuário específico
   */
  static async getUserStats(userId) {
    try {
      const db = getDatabase();

      // Total de buscas do usuário
      const totalSearches = await db.get(
        'SELECT COUNT(*) as count FROM search_history WHERE user_id = ?',
        userId
      );

      // Total de acessos a músicas
      const totalAccesses = await db.get(
        'SELECT COUNT(*) as count FROM music_access_log WHERE user_id = ?',
        userId
      );

      // Músicas favoritas (mais acessadas)
      const favoriteMusic = await db.all(
        `SELECT 
           m.id,
           m.title,
           m.artist,
           COUNT(*) as access_count
         FROM music_access_log mal
         INNER JOIN music m ON mal.music_id = m.id
         WHERE mal.user_id = ?
         GROUP BY m.id
         ORDER BY access_count DESC
         LIMIT 10`,
        userId
      );

      // Gêneros preferidos
      const favoriteGenres = await db.all(
        `SELECT 
           m.genre,
           COUNT(*) as count
         FROM music_access_log mal
         INNER JOIN music m ON mal.music_id = m.id
         WHERE mal.user_id = ? AND m.genre IS NOT NULL
         GROUP BY m.genre
         ORDER BY count DESC
         LIMIT 5`,
        userId
      );

      // Último acesso
      const lastActivity = await db.get(
        `SELECT MAX(accessed_at) as last_access 
         FROM music_access_log 
         WHERE user_id = ?`,
        userId
      );

      const stats = {
        userId,
        totalSearches: totalSearches.count,
        totalAccesses: totalAccesses.count,
        favoriteMusic,
        favoriteGenres,
        lastActivity: lastActivity.last_access,
        timestamp: new Date().toISOString(),
      };

      logger.info('User stats fetched', { userId, stats });

      return stats;
    } catch (error) {
      logger.error('Failed to get user stats', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Trending músicas (crescimento recente)
   */
  static async getTrendingMusic(limit = 10) {
    try {
      const db = getDatabase();

      // Compara acessos dos últimos 7 dias com os 7 dias anteriores
      const results = await db.all(
        `SELECT 
           m.id,
           m.title,
           m.artist,
           m.genre,
           m.access_count as total_access_count,
           (SELECT COUNT(*) FROM music_access_log 
            WHERE music_id = m.id 
            AND accessed_at >= date('now', '-7 days')) as recent_access_count,
           (SELECT COUNT(*) FROM music_access_log 
            WHERE music_id = m.id 
            AND accessed_at >= date('now', '-14 days')
            AND accessed_at < date('now', '-7 days')) as previous_access_count
         FROM music m
         WHERE (SELECT COUNT(*) FROM music_access_log 
                WHERE music_id = m.id 
                AND accessed_at >= date('now', '-7 days')) > 0
         ORDER BY (recent_access_count - previous_access_count) DESC
         LIMIT ?`,
        limit
      );

      // Calcula taxa de crescimento
      const trending = results.map(item => ({
        ...item,
        growth_rate: item.previous_access_count > 0
          ? ((item.recent_access_count - item.previous_access_count) / 
             item.previous_access_count * 100).toFixed(2)
          : 100,
      }));

      logger.info('Trending music fetched', {
        limit,
        resultsCount: trending.length,
      });

      return trending;
    } catch (error) {
      logger.error('Failed to get trending music', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Relatório de atividade diária
   */
  static async getDailyActivityReport(days = 30) {
    try {
      const db = getDatabase();

      const report = await db.all(
        `SELECT 
           date(searched_at) as date,
           COUNT(DISTINCT user_id) as active_users,
           COUNT(*) as total_searches,
           AVG(results_count) as avg_results
         FROM search_history
         WHERE searched_at >= date('now', '-' || ? || ' days')
         GROUP BY date(searched_at)
         ORDER BY date DESC`,
        days
      );

      logger.info('Daily activity report fetched', {
        days,
        resultsCount: report.length,
      });

      return report;
    } catch (error) {
      logger.error('Failed to get daily activity report', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Limpa dados antigos de analytics (GDPR compliance)
   */
  static async cleanOldAnalyticsData(retentionDays = 365) {
    try {
      const db = getDatabase();

      // Remove logs de acesso antigos
      const deletedAccessLogs = await db.run(
        `DELETE FROM music_access_log 
         WHERE accessed_at < date('now', '-' || ? || ' days')`,
        retentionDays
      );

      // Remove histórico de busca antigo
      const deletedSearchHistory = await db.run(
        `DELETE FROM search_history 
         WHERE searched_at < date('now', '-' || ? || ' days')`,
        retentionDays
      );

      logger.info('Old analytics data cleaned', {
        retentionDays,
        deletedAccessLogs: deletedAccessLogs.changes,
        deletedSearchHistory: deletedSearchHistory.changes,
      });

      return {
        deletedAccessLogs: deletedAccessLogs.changes,
        deletedSearchHistory: deletedSearchHistory.changes,
      };
    } catch (error) {
      logger.error('Failed to clean old analytics data', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Exporta analytics para JSON
   */
  static async exportAnalytics(userId = null, startDate = null, endDate = null) {
    try {
      const db = getDatabase();
      
      let whereClause = '1=1';
      const params = [];

      if (userId) {
        whereClause += ' AND user_id = ?';
        params.push(userId);
      }

      if (startDate) {
        whereClause += ' AND searched_at >= ?';
        params.push(startDate);
      }

      if (endDate) {
        whereClause += ' AND searched_at <= ?';
        params.push(endDate);
      }

      const searches = await db.all(
        `SELECT * FROM search_history WHERE ${whereClause} ORDER BY searched_at DESC`,
        ...params
      );

      const accesses = await db.all(
        `SELECT * FROM music_access_log WHERE ${whereClause.replace('searched_at', 'accessed_at')} ORDER BY accessed_at DESC`,
        ...params
      );

      const exportData = {
        metadata: {
          exportedAt: new Date().toISOString(),
          userId,
          startDate,
          endDate,
          totalSearches: searches.length,
          totalAccesses: accesses.length,
        },
        searches,
        accesses,
      };

      logger.info('Analytics exported', {
        userId,
        searchCount: searches.length,
        accessCount: accesses.length,
      });

      return exportData;
    } catch (error) {
      logger.error('Failed to export analytics', {
        error: error.message,
      });
      throw error;
    }
  }
}
