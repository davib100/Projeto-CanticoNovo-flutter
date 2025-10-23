import { AuthService } from '../services/authService.mjs';
import { UserModel } from '../models/userModel.mjs'; // ← ADICIONADO
import { formatSuccess, formatError } from '../utils/responseFormatter.mjs';
import { logger } from '../utils/logger.mjs';

export class AuthController {
  /**
   * POST /api/auth/login
   * Login via OAuth
   */
  static async login(req, res, next) {
    try {
      const { oauthData, deviceInfo } = req.body;

      // Validação aprimorada
      if (!oauthData) {
        logger.warning('Login attempt without oauthData');
        return res.status(400).json(
          formatError('INVALID_REQUEST', 'Missing oauthData')
        );
      }

      if (!deviceInfo || !deviceInfo.deviceId) {
        logger.warning('Login attempt without deviceInfo');
        return res.status(400).json(
          formatError('INVALID_REQUEST', 'Missing deviceInfo with deviceId')
        );
      }

      // Validação de campos obrigatórios do OAuth
      if (!oauthData.email || !oauthData.provider || !oauthData.id) {
        logger.warning('Login attempt with incomplete oauthData', { oauthData });
        return res.status(400).json(
          formatError(
            'INVALID_OAUTH_DATA',
            'oauthData must include email, provider, and id'
          )
        );
      }

      const result = await AuthService.loginOAuth(oauthData, deviceInfo);

      logger.info('User logged in successfully', {
        userId: result.user.id,
        provider: oauthData.provider,
        deviceId: deviceInfo.deviceId,
      });

      res.json(formatSuccess(result, 'Login successful'));
    } catch (error) {
      logger.error('Login failed', {
        error: error.message,
        stack: error.stack,
      });
      
      // Tratamento de erros específicos
      if (error.message.includes('OAuth')) {
        return res.status(401).json(
          formatError('OAUTH_ERROR', error.message)
        );
      }

      next(error);
    }
  }

  /**
   * POST /api/auth/refresh
   * Renova access token
   */
  static async refresh(req, res, next) {
    try {
      const { refreshToken } = req.body;

      if (!refreshToken) {
        logger.warning('Refresh attempt without token');
        return res.status(400).json(
          formatError('INVALID_REQUEST', 'Refresh token is required')
        );
      }

      const result = await AuthService.refreshAccessToken(refreshToken);

      logger.info('Access token refreshed successfully');

      res.json(formatSuccess(result, 'Token refreshed successfully'));
    } catch (error) {
      logger.warning('Token refresh failed', {
        error: error.message,
      });

      if (
        error.message.includes('Invalid') ||
        error.message.includes('expired') ||
        error.message.includes('Session')
      ) {
        return res.status(401).json(
          formatError('INVALID_TOKEN', error.message)
        );
      }

      next(error);
    }
  }

  /**
   * POST /api/auth/logout
   * Logout do dispositivo atual
   */
  static async logout(req, res, next) {
    try {
      const userId = req.user.userId;
      const { deviceId } = req.body;

      if (!deviceId) {
        logger.warning('Logout attempt without deviceId', { userId });
        return res.status(400).json(
          formatError('INVALID_REQUEST', 'Device ID is required')
        );
      }

      await AuthService.logout(userId, deviceId);

      logger.info('User logged out successfully', {
        userId,
        deviceId,
      });

      res.json(formatSuccess({ message: 'Logged out successfully' }));
    } catch (error) {
      logger.error('Logout failed', {
        userId: req.user?.userId,
        error: error.message,
      });

      next(error);
    }
  }

  /**
   * POST /api/auth/logout-all
   * Logout de todos os dispositivos
   */
  static async logoutAll(req, res, next) {
    try {
      const userId = req.user.userId;

      await AuthService.logoutAll(userId);

      logger.info('User logged out from all devices', { userId });

      res.json(
        formatSuccess({ message: 'Logged out from all devices successfully' })
      );
    } catch (error) {
      logger.error('Logout all failed', {
        userId: req.user?.userId,
        error: error.message,
      });

      next(error);
    }
  }

  /**
   * GET /api/auth/me
   * Retorna usuário autenticado
   */
  static async me(req, res, next) {
    try {
      const userId = req.user.userId;

      const user = await UserModel.findById(userId);

      if (!user) {
        logger.warning('User not found for me endpoint', { userId });
        return res.status(404).json(
          formatError('NOT_FOUND', 'User not found')
        );
      }

      // Remove dados sensíveis
      const { oauth_id, ...safeUser } = user;

      logger.info('User info fetched', { userId });

      res.json(formatSuccess({ user: safeUser }));
    } catch (error) {
      logger.error('Failed to fetch user info', {
        userId: req.user?.userId,
        error: error.message,
      });

      next(error);
    }
  }

  /**
   * POST /api/auth/accept-terms
   * Aceita termos de uso
   */
  static async acceptTerms(req, res, next) {
    try {
      const userId = req.user.userId;

      await UserModel.acceptTerms(userId);

      logger.info('User accepted terms', { userId });

      res.json(formatSuccess({ message: 'Terms accepted successfully' }));
    } catch (error) {
      logger.error('Failed to accept terms', {
        userId: req.user?.userId,
        error: error.message,
      });

      next(error);
    }
  }
}

import AuthService from '../services/authService.mjs';
import OAuthService from '../services/oauthService.mjs';
import UserModel from '../models/userModel.mjs';
import TokenService from '../services/tokenService.mjs';
import EmailService from '../services/emailService.mjs';
import { getDatabase } from '../config/database.mjs';
import { v4 as uuidv4 } from 'uuid';
import { hashPassword } from '../utils/passwordUtils.mjs';

export class AuthController {
  /**
   * POST /auth/register
   * Registrar novo usuário
   */
  static async register(req, res, next) {
    try {
      const { fullName, email, password, deviceId } = req.body;

      // Validações
      if (!fullName || fullName.trim().length < 2) {
        return res.status(400).json({
          success: false,
          error: 'Nome deve ter pelo menos 2 caracteres',
        });
      }

      if (!email || !/^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/.test(email)) {
        return res.status(400).json({
          success: false,
          error: 'Email inválido',
        });
      }

      if (!password || password.length < 8) {
        return res.status(400).json({
          success: false,
          error: 'Senha deve ter pelo menos 8 caracteres',
        });
      }

      if (!deviceId) {
        return res.status(400).json({
          success: false,
          error: 'Device ID é obrigatório',
        });
      }

      // Registrar usuário
      const result = await AuthService.register({
        fullName: fullName.trim(),
        email: email.toLowerCase().trim(),
        password,
        deviceId,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent'],
      });

      // Enviar email de boas-vindas (não bloquear resposta)
      EmailService.sendWelcomeEmail(result.user.email, result.user.fullName).catch(err => {
        console.error('Erro ao enviar email de boas-vindas:', err);
      });

      res.status(201).json({
        success: true,
        data: result,
      });
    } catch (error) {
      console.error('Register error:', error);
      
      if (error.message === 'Email já cadastrado') {
        return res.status(409).json({
          success: false,
          error: error.message,
        });
      }

      res.status(500).json({
        success: false,
        error: 'Erro ao criar conta',
      });
    }
  }

  /**
   * POST /auth/login
   * Login com email e senha
   */
  static async login(req, res, next) {
    try {
      const { email, password, deviceId, rememberMe = false } = req.body;

      // Validações
      if (!email || !password) {
        return res.status(400).json({
          success: false,
          error: 'Email e senha são obrigatórios',
        });
      }

      if (!deviceId) {
        return res.status(400).json({
          success: false,
          error: 'Device ID é obrigatório',
        });
      }

      // Login
      const result = await AuthService.login({
        email: email.toLowerCase().trim(),
        password,
        deviceId,
        rememberMe,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent'],
      });

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      console.error('Login error:', error);

      if (
        error.message.includes('Email ou senha incorretos') ||
        error.message.includes('tentativas restantes')
      ) {
        return res.status(401).json({
          success: false,
          error: error.message,
        });
      }

      if (error.message.includes('bloqueada')) {
        return res.status(403).json({
          success: false,
          error: error.message,
        });
      }

      if (error.message.includes('Dispositivo não autorizado')) {
        return res.status(403).json({
          success: false,
          error: error.message,
        });
      }

      res.status(500).json({
        success: false,
        error: 'Erro ao fazer login',
      });
    }
  }

  /**
   * POST /auth/google
   * Login com Google OAuth
   */
  static async loginWithGoogle(req, res, next) {
    try {
      const { idToken, deviceId } = req.body;

      if (!idToken) {
        return res.status(400).json({
          success: false,
          error: 'ID Token do Google é obrigatório',
        });
      }

      if (!deviceId) {
        return res.status(400).json({
          success: false,
          error: 'Device ID é obrigatório',
        });
      }

      // Verificar token do Google
      const googleUser = await OAuthService.verifyGoogleToken(idToken);

      // Login/Registro com OAuth
      const result = await AuthService.loginWithOAuth({
        provider: 'google',
        oauthId: googleUser.oauthId,
        email: googleUser.email,
        fullName: googleUser.fullName,
        photoUrl: googleUser.photoUrl,
        deviceId,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent'],
      });

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      console.error('Google login error:', error);

      if (error.message.includes('Email já cadastrado')) {
        return res.status(409).json({
          success: false,
          error: error.message,
        });
      }

      res.status(500).json({
        success: false,
        error: 'Erro ao fazer login com Google',
      });
    }
  }

  /**
   * POST /auth/microsoft
   * Login com Microsoft OAuth
   */
  static async loginWithMicrosoft(req, res, next) {
    try {
      const { accessToken, deviceId } = req.body;

      if (!accessToken) {
        return res.status(400).json({
          success: false,
          error: 'Access Token da Microsoft é obrigatório',
        });
      }

      if (!deviceId) {
        return res.status(400).json({
          success: false,
          error: 'Device ID é obrigatório',
        });
      }

      // Verificar token da Microsoft
      const microsoftUser = await OAuthService.verifyMicrosoftToken(accessToken);

      // Login/Registro com OAuth
      const result = await AuthService.loginWithOAuth({
        provider: 'microsoft',
        oauthId: microsoftUser.oauthId,
        email: microsoftUser.email,
        fullName: microsoftUser.fullName,
        photoUrl: microsoftUser.photoUrl,
        deviceId,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent'],
      });

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      console.error('Microsoft login error:', error);

      res.status(500).json({
        success: false,
        error: 'Erro ao fazer login com Microsoft',
      });
    }
  }

  /**
   * POST /auth/facebook
   * Login com Facebook OAuth
   */
  static async loginWithFacebook(req, res, next) {
    try {
      const { accessToken, deviceId } = req.body;

      if (!accessToken) {
        return res.status(400).json({
          success: false,
          error: 'Access Token do Facebook é obrigatório',
        });
      }

      if (!deviceId) {
        return res.status(400).json({
          success: false,
          error: 'Device ID é obrigatório',
        });
      }

      // Verificar token do Facebook
      const facebookUser = await OAuthService.verifyFacebookToken(accessToken);

      // Login/Registro com OAuth
      const result = await AuthService.loginWithOAuth({
        provider: 'facebook',
        oauthId: facebookUser.oauthId,
        email: facebookUser.email,
        fullName: facebookUser.fullName,
        photoUrl: facebookUser.photoUrl,
        deviceId,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent'],
      });

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      console.error('Facebook login error:', error);

      res.status(500).json({
        success: false,
        error: 'Erro ao fazer login com Facebook',
      });
    }
  }

  /**
   * POST /auth/refresh
   * Renovar access token usando refresh token
   */
  static async refreshToken(req, res, next) {
    try {
      const { refreshToken } = req.body;

      if (!refreshToken) {
        return res.status(400).json({
          success: false,
          error: 'Refresh token é obrigatório',
        });
      }

      const result = await AuthService.refreshToken({ refreshToken });

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      console.error('Refresh token error:', error);

      if (
        error.message.includes('inválido') ||
        error.message.includes('expirado') ||
        error.message.includes('Sessão')
      ) {
        return res.status(401).json({
          success: false,
          error: error.message,
        });
      }

      res.status(500).json({
        success: false,
        error: 'Erro ao renovar token',
      });
    }
  }

  /**
   * POST /auth/logout
   * Fazer logout (revogar sessão atual)
   */
  static async logout(req, res, next) {
    try {
      const { deviceId } = req.body;

      if (!deviceId) {
        return res.status(400).json({
          success: false,
          error: 'Device ID é obrigatório',
        });
      }

      await AuthService.logout({ deviceId });

      res.status(200).json({
        success: true,
        message: 'Logout realizado com sucesso',
      });
    } catch (error) {
      console.error('Logout error:', error);

      res.status(500).json({
        success: false,
        error: 'Erro ao fazer logout',
      });
    }
  }

  /**
   * POST /auth/revoke-session
   * Revogar sessão específica (single-device enforcement)
   */
  static async revokeSession(req, res, next) {
    try {
      const { deviceId } = req.body;
      const userId = req.user.userId; // Do authMiddleware

      if (!deviceId) {
        return res.status(400).json({
          success: false,
          error: 'Device ID é obrigatório',
        });
      }

      await AuthService.revokeSession({ deviceId, userId });

      res.status(200).json({
        success: true,
        message: 'Sessão revogada com sucesso',
      });
    } catch (error) {
      console.error('Revoke session error:', error);

      if (error.message.includes('Não autorizado')) {
        return res.status(403).json({
          success: false,
          error: error.message,
        });
      }

      res.status(500).json({
        success: false,
        error: 'Erro ao revogar sessão',
      });
    }
  }

  /**
   * POST /auth/reset-password
   * Solicitar redefinição de senha
   */
  static async resetPassword(req, res, next) {
    try {
      const { email } = req.body;

      if (!email) {
        return res.status(400).json({
          success: false,
          error: 'Email é obrigatório',
        });
      }

      // Buscar usuário
      const user = await UserModel.findByEmail(email);

      if (!user) {
        // Por segurança, não revelar se o email existe
        return res.status(200).json({
          success: true,
          message: 'Se o email existir, você receberá instruções de redefinição',
        });
      }

      // Gerar token de redefinição
      const resetToken = TokenService.generatePasswordResetToken();
      const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hora

      // Salvar token no banco
      const db = getDatabase();
      await db.run(
        `INSERT INTO password_reset_tokens (id, user_id, token, expires_at)
         VALUES (?, ?, ?, ?)`,
        [uuidv4(), user.id, resetToken, expiresAt.toISOString()]
      );

      // Enviar email
      await EmailService.sendPasswordResetEmail(user.email, resetToken);

      res.status(200).json({
        success: true,
        message: 'Se o email existir, você receberá instruções de redefinição',
      });
    } catch (error) {
      console.error('Reset password error:', error);

      res.status(500).json({
        success: false,
        error: 'Erro ao processar solicitação',
      });
    }
  }

  /**
   * POST /auth/reset-password/confirm
   * Confirmar redefinição de senha com token
   */
  static async confirmResetPassword(req, res, next) {
    try {
      const { token, newPassword } = req.body;

      if (!token || !newPassword) {
        return res.status(400).json({
          success: false,
          error: 'Token e nova senha são obrigatórios',
        });
      }

      if (newPassword.length < 8) {
        return res.status(400).json({
          success: false,
          error: 'Senha deve ter pelo menos 8 caracteres',
        });
      }

      // Buscar token
      const db = getDatabase();
      const resetToken = await db.get(
        `SELECT * FROM password_reset_tokens 
         WHERE token = ? AND used = 0 AND expires_at > datetime('now')`,
        [token]
      );

      if (!resetToken) {
        return res.status(400).json({
          success: false,
          error: 'Token inválido ou expirado',
        });
      }

      // Hash da nova senha
      const passwordHash = await hashPassword(newPassword);

      // Atualizar senha
      await UserModel.updatePassword(resetToken.user_id, passwordHash);

      // Marcar token como usado
      await db.run(
        'UPDATE password_reset_tokens SET used = 1 WHERE id = ?',
        [resetToken.id]
      );

      // Revogar todas as sessões do usuário (forçar novo login)
      const SessionModel = (await import('../models/sessionModel.mjs')).default;
      await SessionModel.revokeAllByUserId(resetToken.user_id);

      res.status(200).json({
        success: true,
        message: 'Senha redefinida com sucesso',
      });
    } catch (error) {
      console.error('Confirm reset password error:', error);

      res.status(500).json({
        success: false,
        error: 'Erro ao redefinir senha',
      });
    }
  }

  /**
   * GET /auth/me
   * Obter dados do usuário autenticado
   */
  static async getMe(req, res, next) {
    try {
      const userId = req.user.userId; // Do authMiddleware

      const user = await UserModel.findById(userId);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: 'Usuário não encontrado',
        });
      }

      res.status(200).json({
        success: true,
        data: UserModel.sanitize(user),
      });
    } catch (error) {
      console.error('Get me error:', error);

      res.status(500).json({
        success: false,
        error: 'Erro ao buscar dados do usuário',
      });
    }
  }

  /**
   * GET /auth/sessions
   * Listar todas as sessões ativas do usuário
   */
  static async getSessions(req, res, next) {
    try {
      const userId = req.user.userId;

      const SessionModel = (await import('../models/sessionModel.mjs')).default;
      const sessions = await SessionModel.findActiveByUserId(userId);

      res.status(200).json({
        success: true,
        data: sessions.map(session => ({
          id: session.id,
          deviceId: session.device_id,
          deviceName: session.device_name,
          deviceType: session.device_type,
          deviceOs: session.device_os,
          ipAddress: session.ip_address,
          lastActivity: session.last_activity_at,
          createdAt: session.created_at,
        })),
      });
    } catch (error) {
      console.error('Get sessions error:', error);

      res.status(500).json({
        success: false,
        error: 'Erro ao buscar sessões',
      });
    }
  }
}

export default AuthController;
