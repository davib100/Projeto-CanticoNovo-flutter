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
