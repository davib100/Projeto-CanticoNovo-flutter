import { MusicModel } from '../models/musicModel.mjs';
import { SearchHistoryModel } from '../models/searchHistoryModel.mjs';
import { config } from '../config/env.mjs';
import { logger } from '../utils/logger.mjs';

export class SearchService {
  /**
   * Busca músicas
   */
  static async searchMusic(query, userId, options = {}) {
    try {
      // Validação
      if (query.length < config.SEARCH_MIN_QUERY_LENGTH) {
        throw new Error(
          `Query must be at least ${config.SEARCH_MIN_QUERY_LENGTH} characters`
        );
      }

      const limit = Math.min(
        options.limit || config.DEFAULT_PAGE_SIZE,
        config.SEARCH_MAX_RESULTS
      );
      const offset = options.offset || 0;

      // Busca no banco
      const results = await MusicModel.search(query, { limit, offset });

      // Registra no histórico (async, não bloqueia resposta)
      if (userId) {
        SearchHistoryModel.create(userId, query, results.length).catch(err => {
          logger.error('Failed to save search history', { error: err.message });
        });
      }

      logger.info('Search performed', {
        query,
        userId,
        resultsCount: results.length,
        limit,
        offset,
      });

      return {
        results,
        total: results.length,
        query,
        limit,
        offset,
      };
    } catch (error) {
      logger.error('Search failed', {
        query,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Busca sugestões (autocomplete)
   */
  static async getSuggestions(query) {
    try {
      if (query.length < config.SEARCH_MIN_QUERY_LENGTH) {
        return [];
      }

      const suggestions = await MusicModel.getSuggestions(
        query,
        config.SEARCH_SUGGESTIONS_LIMIT
      );

      return suggestions.map(s => s.title);
    } catch (error) {
      logger.error('Failed to get suggestions', {
        query,
        error: error.message,
      });
      return [];
    }
  }

  /**
   * Busca histórico do usuário
   */
  static async getUserHistory(userId, limit = 20) {
    try {
      return await SearchHistoryModel.findByUser(userId, limit);
    } catch (error) {
      logger.error('Failed to get user history', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Limpa histórico do usuário
   */
  static async clearUserHistory(userId) {
    try {
      await SearchHistoryModel.clearUserHistory(userId);
      logger.info('User history cleared', { userId });
    } catch (error) {
      logger.error('Failed to clear user history', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Busca termos mais pesquisados (analytics)
   */
  static async getTopSearches(limit = 10) {
    try {
      return await SearchHistoryModel.getTopSearches(limit);
    } catch (error) {
      logger.error('Failed to get top searches', { error: error.message });
      throw error;
    }
  }
}
