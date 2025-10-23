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

import { getDatabase } from '../config/database.mjs';
import { v4 as uuidv4 } from 'uuid';

export class SessionModel {
  static async create({
    userId,
    deviceId,
    deviceName,
    deviceType,
    deviceOs,
    refreshToken,
    ipAddress,
    userAgent,
    expiresAt,
  }) {
    const db = getDatabase();
    const id = uuidv4();

    // Verificar se já existe sessão ativa para este dispositivo
    const existingSession = await this.findByDeviceId(deviceId);
    
    if (existingSession && existingSession.is_active) {
      // Desativar sessão anterior (single-device enforcement)
      await this.revokeByDeviceId(deviceId);
    }

    await db.run(
      `INSERT INTO sessions (
        id, user_id, device_id, device_name, device_type, device_os,
        refresh_token, ip_address, user_agent, expires_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        userId,
        deviceId,
        deviceName,
        deviceType,
        deviceOs,
        refreshToken,
        ipAddress,
        userAgent,
        expiresAt,
      ]
    );

    return await this.findById(id);
  }

  static async findById(id) {
    const db = getDatabase();
    return await db.get('SELECT * FROM sessions WHERE id = ?', [id]);
  }

  static async findByDeviceId(deviceId) {
    const db = getDatabase();
    return await db.get(
      'SELECT * FROM sessions WHERE device_id = ? AND is_active = 1',
      [deviceId]
    );
  }

  static async findByRefreshToken(refreshToken) {
    const db = getDatabase();
    return await db.get(
      'SELECT * FROM sessions WHERE refresh_token = ? AND is_active = 1',
      [refreshToken]
    );
  }

  static async findActiveByUserId(userId) {
    const db = getDatabase();
    return await db.all(
      'SELECT * FROM sessions WHERE user_id = ? AND is_active = 1',
      [userId]
    );
  }

  static async updateRefreshToken(sessionId, newRefreshToken) {
    const db = getDatabase();
    await db.run(
      'UPDATE sessions SET refresh_token = ?, last_activity_at = CURRENT_TIMESTAMP WHERE id = ?',
      [newRefreshToken, sessionId]
    );
  }

  static async updateLastActivity(sessionId) {
    const db = getDatabase();
    await db.run(
      'UPDATE sessions SET last_activity_at = CURRENT_TIMESTAMP WHERE id = ?',
      [sessionId]
    );
  }

  static async revokeById(sessionId) {
    const db = getDatabase();
    await db.run(
      'UPDATE sessions SET is_active = 0 WHERE id = ?',
      [sessionId]
    );
  }

  static async revokeByDeviceId(deviceId) {
    const db = getDatabase();
    await db.run(
      'UPDATE sessions SET is_active = 0 WHERE device_id = ?',
      [deviceId]
    );
  }

  static async revokeAllByUserId(userId) {
    const db = getDatabase();
    await db.run(
      'UPDATE sessions SET is_active = 0 WHERE user_id = ?',
      [userId]
    );
  }

  static async cleanupExpired() {
    const db = getDatabase();
    await db.run(
      'UPDATE sessions SET is_active = 0 WHERE expires_at < CURRENT_TIMESTAMP'
    );
  }

  static async isExpired(session) {
    const expiresAt = new Date(session.expires_at);
    return new Date() > expiresAt;
  }
}

export default SessionModel;
