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
