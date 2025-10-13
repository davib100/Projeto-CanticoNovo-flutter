import { formatError } from '../utils/responseFormatter.mjs';
import { logger } from '../utils/logger.mjs';
import { captureException } from '../config/sentry.mjs';

/**
 * Middleware global de tratamento de erros
 */
export function errorHandler(err, req, res, next) {
  // Log do erro
  logger.error('Unhandled error', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    body: req.body,
    query: req.query,
  });

  // Envia para Sentry
  captureException(err, {
    path: req.path,
    method: req.method,
    userId: req.user?.userId,
  });

  // Determina código de status
  const statusCode = err.statusCode || err.status || 500;

  // Formata resposta
  const errorResponse = formatError(
    err.code || 'INTERNAL_ERROR',
    err.message || 'An unexpected error occurred',
    err.details
  );

  res.status(statusCode).json(errorResponse);
}
