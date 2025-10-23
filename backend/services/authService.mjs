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

import UserModel from '../models/userModel.mjs';
import SessionModel from '../models/sessionModel.mjs';
import TokenService from './tokenService.mjs';
import { hashPassword, comparePassword } from '../utils/passwordUtils.mjs';
import { parseUserAgent } from '../utils/deviceUtils.mjs';
import { config } from '../config/env.mjs';

export class AuthService {
  static async register({ fullName, email, password, deviceId, ipAddress, userAgent }) {
    // Verificar se usuário já existe
    const existingUser = await UserModel.findByEmail(email);
    if (existingUser) {
      throw new Error('Email já cadastrado');
    }

    // Hash da senha
    const passwordHash = await hashPassword(password);

    // Criar usuário
    const user = await UserModel.create({
      fullName,
      email,
      passwordHash,
    });

    // Criar sessão
    const session = await this.createSession(user.id, deviceId, ipAddress, userAgent);

    // Gerar tokens
    const accessToken = TokenService.generateAccessToken({
      userId: user.id,
      email: user.email,
      deviceId,
    });

    return {
      user: UserModel.sanitize(user),
      session: {
        token: accessToken,
        refreshToken: session.refresh_token,
        deviceId: session.device_id,
        expiresAt: session.expires_at,
        createdAt: session.created_at,
      },
    };
  }

  static async login({ email, password, deviceId, rememberMe, ipAddress, userAgent }) {
    // Buscar usuário
    const user = await UserModel.findByEmail(email);
    if (!user) {
      throw new Error('Email ou senha incorretos');
    }

    // Verificar se conta está bloqueada
    const isLocked = await UserModel.isAccountLocked(user.id);
    if (isLocked) {
      throw new Error('Conta temporariamente bloqueada devido a múltiplas tentativas de login');
    }

    // Verificar senha
    const isPasswordValid = await comparePassword(password, user.password_hash);
    if (!isPasswordValid) {
      await UserModel.incrementFailedAttempts(user.id);

      const attemptsLeft = config.MAX_LOGIN_ATTEMPTS - (user.failed_login_attempts + 1);
      
      if (attemptsLeft <= 0) {
        await UserModel.lockAccount(user.id, config.LOCKOUT_DURATION);
        throw new Error('Conta bloqueada devido a múltiplas tentativas incorretas');
      }

      throw new Error(`Email ou senha incorretos. ${attemptsLeft} tentativas restantes`);
    }

    // Resetar tentativas falhas
    await UserModel.resetFailedAttempts(user.id);
    await UserModel.updateLastLogin(user.id);

    // Verificar sessão ativa em outro dispositivo
    const existingSession = await SessionModel.findByDeviceId(deviceId);
    if (existingSession && existingSession.user_id !== user.id) {
      // Device ID pertence a outro usuário - possível tentativa de fraude
      throw new Error('Dispositivo não autorizado');
    }

    // Criar nova sessão (revoga sessões anteriores do mesmo dispositivo)
    const session = await this.createSession(user.id, deviceId, ipAddress, userAgent, rememberMe);

    // Gerar tokens
    const accessToken = TokenService.generateAccessToken({
      userId: user.id,
      email: user.email,
      deviceId,
    });

    return {
      user: UserModel.sanitize(user),
      session: {
        token: accessToken,
        refreshToken: session.refresh_token,
        deviceId: session.device_id,
        expiresAt: session.expires_at,
        createdAt: session.created_at,
      },
    };
  }

  static async loginWithOAuth({ provider, oauthId, email, fullName, photoUrl, deviceId, ipAddress, userAgent }) {
    let user = await UserModel.findByOAuth(provider, oauthId);

    if (!user) {
      // Verificar se email já existe com outro provider
      const existingUser = await UserModel.findByEmail(email);
      if (existingUser) {
        throw new Error('Email já cadastrado com outro método de login');
      }

      // Criar novo usuário
      user = await UserModel.create({
        fullName,
        email,
        oauthProvider: provider,
        oauthId,
        photoUrl,
      });
    }

    await UserModel.updateLastLogin(user.id);

    // Criar sessão
    const session = await this.createSession(user.id, deviceId, ipAddress, userAgent);

    // Gerar tokens
    const accessToken = TokenService.generateAccessToken({
      userId: user.id,
      email: user.email,
      deviceId,
    });

    return {
      user: UserModel.sanitize(user),
      session: {
        token: accessToken,
        refreshToken: session.refresh_token,
        deviceId: session.device_id,
        expiresAt: session.expires_at,
        createdAt: session.created_at,
      },
    };
  }

  static async refreshToken({ refreshToken }) {
    // Verificar refresh token
    let decoded;
    try {
      decoded = TokenService.verifyRefreshToken(refreshToken);
    } catch (error) {
      throw new Error('Refresh token inválido ou expirado');
    }

    // Buscar sessão
    const session = await SessionModel.findByRefreshToken(refreshToken);
    if (!session || !session.is_active) {
      throw new Error('Sessão inválida');
    }

    // Verificar se sessão expirou
    if (await SessionModel.isExpired(session)) {
      await SessionModel.revokeById(session.id);
      throw new Error('Sessão expirada');
    }

    // Buscar usuário
    const user = await UserModel.findById(session.user_id);
    if (!user) {
      throw new Error('Usuário não encontrado');
    }

    // Gerar novo refresh token (rotativo)
    const newRefreshToken = TokenService.generateRefreshToken({
      userId: user.id,
      deviceId: session.device_id,
    });

    // Atualizar sessão
    await SessionModel.updateRefreshToken(session.id, newRefreshToken);

    // Gerar novo access token
    const accessToken = TokenService.generateAccessToken({
      userId: user.id,
      email: user.email,
      deviceId: session.device_id,
    });

    return {
      token: accessToken,
      refreshToken: newRefreshToken,
    };
  }

  static async logout({ deviceId }) {
    await SessionModel.revokeByDeviceId(deviceId);
  }

  static async revokeSession({ deviceId, userId }) {
    const session = await SessionModel.findByDeviceId(deviceId);
    
    if (!session) {
      throw new Error('Sessão não encontrada');
    }

    if (session.user_id !== userId) {
      throw new Error('Não autorizado');
    }

    await SessionModel.revokeById(session.id);
  }

  static async createSession(userId, deviceId, ipAddress, userAgent, rememberMe = false) {
    const deviceInfo = parseUserAgent(userAgent);
    
    const refreshToken = TokenService.generateRefreshToken({
      userId,
      deviceId,
    });

    const expirationString = rememberMe ? config.JWT_REFRESH_EXPIRATION : config.JWT_EXPIRATION;
    const expiresAt = TokenService.calculateExpirationDate(expirationString);

    return await SessionModel.create({
      userId,
      deviceId,
      deviceName: deviceInfo.deviceName,
      deviceType: deviceInfo.deviceType,
      deviceOs: deviceInfo.deviceOs,
      refreshToken,
      ipAddress,
      userAgent,
      expiresAt: expiresAt.toISOString(),
    });
  }
}

export default AuthService;
