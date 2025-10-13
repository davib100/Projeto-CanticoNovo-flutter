import { AnalyticsService } from '../services/analyticsService.mjs';
import { formatSuccess, formatError } from '../utils/responseFormatter.mjs';
import { logger } from '../utils/logger.mjs';

export class AnalyticsController {
  /**
   * GET /api/analytics/stats/system
   * Estatísticas gerais do sistema
   */
  static async getSystemStats(req, res, next) {
    try {
      const stats = await AnalyticsService.getSystemStats();
      res.json(formatSuccess(stats));
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/analytics/popular/music
   * Músicas mais populares
   */
  static async getMostPopularMusic(req, res, next) {
    try {
      const { limit = 10, timeframe = '30days' } = req.query;
      
      const results = await AnalyticsService.getMostPopularMusic(
        parseInt(limit, 10),
        timeframe
      );

      res.json(formatSuccess({ results, timeframe }));
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/analytics/trending/music
   * Músicas em alta (trending)
   */
  static async getTrendingMusic(req, res, next) {
    try {
      const { limit = 10 } = req.query;
      
      const results = await AnalyticsService.getTrendingMusic(
        parseInt(limit, 10)
      );

      res.json(formatSuccess({ results }));
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/analytics/top/searches
   * Termos de busca mais populares
   */
  static async getTopSearchTerms(req, res, next) {
    try {
      const { limit = 20, timeframe = '30days' } = req.query;
      
      const results = await AnalyticsService.getTopSearchTerms(
        parseInt(limit, 10),
        timeframe
      );

      res.json(formatSuccess({ results, timeframe }));
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/analytics/stats/user
   * Estatísticas do usuário autenticado
   */
  static async getUserStats(req, res, next) {
    try {
      const userId = req.user.userId;
      
      const stats = await AnalyticsService.getUserStats(userId);

      res.json(formatSuccess(stats));
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/analytics/report/daily
   * Relatório de atividade diária
   */
  static async getDailyActivityReport(req, res, next) {
    try {
      const { days = 30 } = req.query;
      
      const report = await AnalyticsService.getDailyActivityReport(
        parseInt(days, 10)
      );

      res.json(formatSuccess({ report, days }));
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/analytics/export
   * Exporta analytics do usuário
   */
  static async exportAnalytics(req, res, next) {
    try {
      const userId = req.user.userId;
      const { startDate, endDate } = req.query;
      
      const data = await AnalyticsService.exportAnalytics(
        userId,
        startDate,
        endDate
      );

      // Define headers para download
      res.setHeader('Content-Type', 'application/json');
      res.setHeader(
        'Content-Disposition',
        `attachment; filename=analytics_${userId}_${Date.now()}.json`
      );

      res.json(data);
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/analytics/cleanup
   * Limpa dados antigos (GDPR compliance)
   */
  static async cleanOldData(req, res, next) {
    try {
      const { retentionDays = 365 } = req.query;
      
      const result = await AnalyticsService.cleanOldAnalyticsData(
        parseInt(retentionDays, 10)
      );

      logger.info('Old analytics data cleaned', result);

      res.json(
        formatSuccess(result, 'Old analytics data cleaned successfully')
      );
    } catch (error) {
      next(error);
    }
  }
}
