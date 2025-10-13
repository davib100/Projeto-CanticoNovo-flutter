import { getDatabase } from '../config/database.mjs';
import { v4 as uuidv4 } from 'uuid';

export class SessionModel {
  /**
   * Cria nova sessão
   */
  static async create(data) {
    const db = getDatabase();
    const sessionId = uuidv4();
    
    // Remove sessões antigas do mesmo dispositivo
    await db.run(
      'DELETE FROM sessions WHERE user_id = ? AND device_id = ?',
      [data.userId, data.deviceId]
    );
    
    // Cria nova sessão
    await db.run(
      `INSERT INTO sessions (
        id, user_id, device_id, device_name, device_os, 
        refresh_token, expires_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        sessionId,
        data.userId,
        data.deviceId,
        data.deviceName || null,
        data.deviceOs || null,
        data.refreshToken,
        data.expiresAt,
      ]
    );
    
    return await db.get('SELECT * FROM sessions WHERE id = ?', sessionId);
  }

  /**
   * Busca sessão por refresh token
   */
  static async findByRefreshToken(refreshToken) {
    const db = getDatabase();
    return await db.get(
      'SELECT * FROM sessions WHERE refresh_token = ? AND expires_at > CURRENT_TIMESTAMP',
      refreshToken
    );
  }

  /**
   * Busca sessão por usuário e dispositivo
   */
  static async findByUserAndDevice(userId, deviceId) {
    const db = getDatabase();
    return await db.get(
      'SELECT * FROM sessions WHERE user_id = ? AND device_id = ?',
      [userId, deviceId]
    );
  }

  /**
   * Atualiza última utilização
   */
  static async updateLastUsed(sessionId) {
    const db = getDatabase();
    await db.run(
      'UPDATE sessions SET last_used = CURRENT_TIMESTAMP WHERE id = ?',
      sessionId
    );
  }

  /**
   * Deleta sessão
   */
  static async delete(sessionId) {
    const db = getDatabase();
    await db.run('DELETE FROM sessions WHERE id = ?', sessionId);
  }

  /**
   * Deleta todas as sessões do usuário
   */
  static async deleteAllByUser(userId) {
    const db = getDatabase();
    await db.run('DELETE FROM sessions WHERE user_id = ?', userId);
  }

  /**
   * Limpa sessões expiradas
   */
  static async cleanExpired() {
    const db = getDatabase();
    const result = await db.run(
      'DELETE FROM sessions WHERE expires_at < CURRENT_TIMESTAMP'
    );
    return result.changes;
  }
}
