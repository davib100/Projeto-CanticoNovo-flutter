import { getDatabase } from '../config/database.mjs';

export class SearchHistoryModel {
  /**
   * Registra busca no histórico
   */
  static async create(userId, query, resultsCount) {
    const db = getDatabase();
    
    await db.run(
      `INSERT INTO search_history (user_id, query, results_count)
       VALUES (?, ?, ?)`,
      [userId, query, resultsCount]
    );
  }

  /**
   * Busca histórico do usuário
   */
  static async findByUser(userId, limit = 20) {
    const db = getDatabase();
    
    return await db.all(
      `SELECT query, results_count, searched_at 
       FROM search_history 
       WHERE user_id = ? 
       ORDER BY searched_at DESC 
       LIMIT ?`,
      [userId, limit]
    );
  }

  /**
   * Busca termos mais pesquisados
   */
  static async getTopSearches(limit = 10) {
    const db = getDatabase();
    
    return await db.all(
      `SELECT query, COUNT(*) as search_count 
       FROM search_history 
       GROUP BY query 
       ORDER BY search_count DESC 
       LIMIT ?`,
      limit
    );
  }

  /**
   * Limpa histórico do usuário
   */
  static async clearUserHistory(userId) {
    const db = getDatabase();
    await db.run('DELETE FROM search_history WHERE user_id = ?', userId);
  }
}
