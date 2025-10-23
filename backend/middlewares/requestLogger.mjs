import { logger } from '../utils/logger.mjs';
import { addBreadcrumb } from '../config/sentry.mjs';

/**
 * Middleware de logging de requisições
 */
export function requestLogger(req, res, next) {
  const startTime = Date.now();

  // Log da requisição
  logger.info('Incoming request', {
    method: req.method,
    path: req.path,
    query: req.query,
    ip: req.ip,
    userAgent: req.get('user-agent'),
  });

  // Breadcrumb para Sentry
  addBreadcrumb(`${req.method} ${req.path}`, {
    method: req.method,
    url: req.originalUrl,
    query: req.query,
  });

  // Log da resposta
  res.on('finish', () => {
    const duration = Date.now() - startTime;

    logger.info('Request completed', {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
    });
  });

  next();
}

export function requestLogger(req, res, next) {
  const start = Date.now();

  // Interceptar o response
  res.on('finish', () => {
    const duration = Date.now() - start;
    const log = {
      timestamp: new Date().toISOString(),
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
      userAgent: req.headers['user-agent'],
    };

    console.log(JSON.stringify(log));
  });

  next();
}

export default requestLogger;
