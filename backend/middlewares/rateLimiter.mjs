import rateLimit from 'express-rate-limit';
import { config } from '../config/env.mjs';
import { formatError } from '../utils/responseFormatter.mjs';

/**
 * Rate limiter global
 */
export const rateLimiter = rateLimit({
  windowMs: config.RATE_LIMIT_WINDOW_MS,
  max: config.RATE_LIMIT_MAX_REQUESTS,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    res.status(429).json(
      formatError(
        'RATE_LIMIT_EXCEEDED',
        'Too many requests, please try again later'
      )
    );
  },
  skip: (req) => {
    // Ignora health check
    return req.path === '/health';
  },
});

/**
 * Rate limiter específico para busca
 */
export const searchRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minuto
  max: 30, // 30 requisições por minuto
  message: formatError(
    'SEARCH_RATE_LIMIT_EXCEEDED',
    'Too many search requests, please slow down'
  ),
});

import rateLimit from 'express-rate-limit';
import { config } from '../config/env.mjs';

// Rate limiter geral
export const generalLimiter = rateLimit({
  windowMs: config.RATE_LIMIT_WINDOW * 60 * 1000,
  max: config.RATE_LIMIT_MAX_REQUESTS,
  message: {
    success: false,
    error: 'Muitas requisições. Tente novamente mais tarde.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Rate limiter para login (mais restritivo)
export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 5, // 5 tentativas
  skipSuccessfulRequests: true,
  message: {
    success: false,
    error: 'Muitas tentativas de login. Tente novamente em 15 minutos.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Rate limiter para registro
export const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hora
  max: 3, // 3 registros por hora
  message: {
    success: false,
    error: 'Muitas tentativas de registro. Tente novamente mais tarde.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Rate limiter para reset de senha
export const resetPasswordLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hora
  max: 3,
  message: {
    success: false,
    error: 'Muitas solicitações de redefinição. Tente novamente mais tarde.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

export default {
  generalLimiter,
  loginLimiter,
  registerLimiter,
  resetPasswordLimiter,
};
