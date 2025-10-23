import { AuthService } from '../services/authService.mjs';
import { formatError } from '../utils/responseFormatter.mjs';
import { logger } from '../utils/logger.mjs';

/**
 * Middleware de autenticação obrigatória
 */
export function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json(
        formatError('UNAUTHORIZED', 'Missing or invalid authorization header')
      );
    }

    const token = authHeader.substring(7);
    const decoded = AuthService.verifyToken(token);

    if (decoded.type !== 'access') {
      return res.status(401).json(
        formatError('UNAUTHORIZED', 'Invalid token type')
      );
    }

    req.user = decoded;
    next();
  } catch (error) {
    logger.error('Authentication failed', { error: error.message });
    return res.status(401).json(
      formatError('UNAUTHORIZED', 'Invalid or expired token')
    );
  }
}

/**
 * Middleware de autenticação opcional
 */
export function optionalAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      const decoded = AuthService.verifyToken(token);

      if (decoded.type === 'access') {
        req.user = decoded;
      }
    }

    next();
  } catch (error) {
    // Ignora erro e continua sem autenticação
    next();
  }
}

import TokenService from '../services/tokenService.mjs';
import SessionModel from '../models/sessionModel.mjs';

export async function authMiddleware(req, res, next) {
  try {
    // Extrair token do header Authorization
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Token não fornecido',
      });
    }

    const token = authHeader.substring(7); // Remove "Bearer "

    // Verificar token
    let decoded;
    try {
      decoded = TokenService.verifyAccessToken(token);
    } catch (error) {
      return res.status(401).json({
        success: false,
        error: 'Token inválido ou expirado',
      });
    }

    // Verificar se sessão está ativa
    const session = await SessionModel.findByDeviceId(decoded.deviceId);

    if (!session || !session.is_active) {
      return res.status(401).json({
        success: false,
        error: 'Sessão inválida',
      });
    }

    // Verificar se sessão expirou
    if (await SessionModel.isExpired(session)) {
      await SessionModel.revokeById(session.id);
      return res.status(401).json({
        success: false,
        error: 'Sessão expirada',
      });
    }

    // Atualizar última atividade
    await SessionModel.updateLastActivity(session.id);

    // Anexar dados do usuário ao request
    req.user = {
      userId: decoded.userId,
      email: decoded.email,
      deviceId: decoded.deviceId,
    };

    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    
    res.status(500).json({
      success: false,
      error: 'Erro ao validar autenticação',
    });
  }
}

export default authMiddleware;
