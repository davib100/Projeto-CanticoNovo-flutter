import { SearchService } from '../services/searchService.mjs';
import { formatSuccess, formatError } from '../utils/responseFormatter.mjs';
import { logger } from '../utils/logger.mjs';

export class SearchController {
  /**
   * POST /api/search
   * Busca músicas
   */
  static async search(req, res, next) {
    try {
      const { query } = req.body;
      const { limit, offset } = req.query;
      const userId = req.user?.userId; // Opcional

      if (!query || typeof query !== 'string') {
        return res.status(400).json(
          formatError('INVALID_QUERY', 'Query parameter is required')
        );
      }

      const results = await SearchService.searchMusic(query, userId, {
        limit: limit ? parseInt(limit, 10) : undefined,
        offset: offset ? parseInt(offset, 10) : undefined,
      });

      res.json(formatSuccess(results));
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/search/suggestions
   * Busca sugestões (autocomplete)
   */
  static async getSuggestions(req, res, next) {
    try {
      const { query } = req.query;

      if (!query || typeof query !== 'string') {
        return res.status(400).json(
          formatError('INVALID_QUERY', 'Query parameter is required')
        );
      }

      const suggestions = await SearchService.getSuggestions(query);

      res.json(formatSuccess({ suggestions }));
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/search/history
   * Busca histórico do usuário
   */
  static async getHistory(req, res, next) {
    try {
      const userId = req.user.userId;
      const { limit } = req.query;

      const history = await SearchService.getUserHistory(
        userId,
        limit ? parseInt(limit, 10) : undefined
      );

      res.json(formatSuccess({ history }));
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/search/history
   * Limpa histórico do usuário
   */
  static async clearHistory(req, res, next) {
    try {
      const userId = req.user.userId;

      await SearchService.clearUserHistory(userId);

      res.json(formatSuccess({ message: 'History cleared successfully' }));
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/search/top
   * Busca termos mais pesquisados (analytics)
   */
  static async getTopSearches(req, res, next) {
    try {
      const { limit } = req.query;

      const topSearches = await SearchService.getTopSearches(
        limit ? parseInt(limit, 10) : undefined
      );

      res.json(formatSuccess({ topSearches }));
    } catch (error) {
      next(error);
    }
  }
}
