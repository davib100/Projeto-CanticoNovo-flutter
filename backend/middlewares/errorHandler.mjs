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

import { config } from '../config/env.mjs';

export function errorHandler(err, req, res, next) {
  console.error('Error:', err);

  // Log para Sentry ou outro serviço de monitoramento
  if (config.SENTRY_DSN) {
    // TODO: Integrar com Sentry
  }

  // Erro de validação
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      success: false,
      error: 'Erro de validação',
      details: err.errors,
    });
  }

  // Erro de JWT
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      success: false,
      error: 'Token inválido',
    });
  }

  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({
      success: false,
      error: 'Token expirado',
    });
  }

  // Erro genérico
  res.status(err.status || 500).json({
    success: false,
    error: config.NODE_ENV === 'development' 
      ? err.message 
      : 'Erro interno do servidor',
    ...(config.NODE_ENV === 'development' && { stack: err.stack }),
  });
}

export default errorHandler;
