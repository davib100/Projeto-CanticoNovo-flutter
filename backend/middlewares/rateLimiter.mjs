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
