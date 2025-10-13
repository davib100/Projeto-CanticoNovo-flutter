import jwt from 'jsonwebtoken';
import { config } from '../config/env.mjs';
import { UserModel } from '../models/userModel.mjs';
import { SessionModel } from '../models/sessionModel.mjs';
import { logger } from '../utils/logger.mjs';

export class AuthService {
  /**
   * Gera access token (JWT)
   */
  static generateAccessToken(userId) {
    return jwt.sign(
      { userId, type: 'access' },
      config.JWT_SECRET,
      { expiresIn: config.JWT_EXPIRES_IN }
    );
  }

  /**
   * Gera refresh token
   */
  static generateRefreshToken(userId) {
    return jwt.sign(
      { userId, type: 'refresh' },
      config.JWT_SECRET,
      { expiresIn: config.JWT_REFRESH_EXPIRES_IN }
    );
  }

  /**
   * Verifica token
   */
  static verifyToken(token) {
    try {
      return jwt.verify(token, config.JWT_SECRET);
    } catch (error) {
      throw new Error('Invalid or expired token');
    }
  }

  /**
   * Login via OAuth
   */
  static async loginOAuth(oauthData, deviceInfo) {
    try {
      // Cria ou atualiza usuário
      const user = await UserModel.upsertOAuthUser({
        email: oauthData.email,
        fullName: oauthData.name,
        profilePicture: oauthData.picture,
        provider: oauthData.provider,
        oauthId: oauthData.id,
      });

      // Gera tokens
      const accessToken = this.generateAccessToken(user.id);
      const refreshToken = this.generateRefreshToken(user.id);

      // Cria sessão
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 7); // 7 dias

      await SessionModel.create({
        userId: user.id,
        deviceId: deviceInfo.deviceId,
        deviceName: deviceInfo.deviceName,
        deviceOs: deviceInfo.deviceOs,
        refreshToken,
        expiresAt: expiresAt.toISOString(),
      });

      logger.info('User logged in via OAuth', {
        userId: user.id,
        provider: oauthData.provider,
        deviceId: deviceInfo.deviceId,
      });

      return {
        user,
        accessToken,
        refreshToken,
      };
    } catch (error) {
      logger.error('OAuth login failed', { error: error.message });
      throw error;
    }
  }

  /**
   * Refresh access token
   */
  static async refreshAccessToken(refreshToken) {
    try {
      // Verifica refresh token
      const decoded = this.verifyToken(refreshToken);

      if (decoded.type !== 'refresh') {
        throw new Error('Invalid token type');
      }

      // Busca sessão
      const session = await SessionModel.findByRefreshToken(refreshToken);

      if (!session) {
        throw new Error('Session not found or expired');
      }

      // Atualiza última utilização
      await SessionModel.updateLastUsed(session.id);

      // Gera novo access token
      const accessToken = this.generateAccessToken(session.user_id);

      // Opcionalmente, gera novo refresh token (rotação)
      const newRefreshToken = this.generateRefreshToken(session.user_id);
      
      await SessionModel.delete(session.id);
      
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 7);
      
      await SessionModel.create({
        userId: session.user_id,
        deviceId: session.device_id,
        deviceName: session.device_name,
        deviceOs: session.device_os,
        refreshToken: newRefreshToken,
        expiresAt: expiresAt.toISOString(),
      });

      return {
        accessToken,
        refreshToken: newRefreshToken,
      };
    } catch (error) {
      logger.error('Token refresh failed', { error: error.message });
      throw error;
    }
  }

  /**
   * Logout
   */
  static async logout(userId, deviceId) {
    try {
      const session = await SessionModel.findByUserAndDevice(userId, deviceId);

      if (session) {
        await SessionModel.delete(session.id);
      }

      logger.info('User logged out', { userId, deviceId });
    } catch (error) {
      logger.error('Logout failed', { error: error.message });
      throw error;
    }
  }

  /**
   * Logout de todos os dispositivos
   */
  static async logoutAll(userId) {
    try {
      await SessionModel.deleteAllByUser(userId);
      logger.info('User logged out from all devices', { userId });
    } catch (error) {
      logger.error('Logout all failed', { error: error.message });
      throw error;
    }
  }
}
