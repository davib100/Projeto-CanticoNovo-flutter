import * as Sentry from '@sentry/node';
import { config } from './env.mjs';
import { logger } from '../utils/logger.mjs';

/**
 * Inicializa Sentry para observabilidade
 */
export function initSentry(app) {
  if (!config.SENTRY_DSN) {
    logger.warn('⚠️  Sentry DSN not configured. Skipping initialization.');
    return;
  }

  try {
    Sentry.init({
      dsn: config.SENTRY_DSN,
      environment: config.SENTRY_ENVIRONMENT,
      tracesSampleRate: config.SENTRY_TRACES_SAMPLE_RATE,
      integrations: [
        new Sentry.Integrations.Http({ tracing: true }),
        new Sentry.Integrations.Express({ app }),
      ],
      beforeSend(event, hint) {
        // Filtra informações sensíveis
        if (event.request) {
          delete event.request.cookies;
          if (event.request.headers) {
            delete event.request.headers['authorization'];
            delete event.request.headers['cookie'];
          }
        }
        return event;
      },
    });

    logger.info('✅ Sentry initialized', {
      environment: config.SENTRY_ENVIRONMENT,
      tracesSampleRate: config.SENTRY_TRACES_SAMPLE_RATE,
    });
  } catch (error) {
    logger.error('❌ Failed to initialize Sentry', { error: error.message });
  }
}

/**
 * Middleware para request tracing
 */
export const sentryRequestHandler = Sentry.Handlers.requestHandler();

/**
 * Middleware para error tracking
 */
export const sentryErrorHandler = Sentry.Handlers.errorHandler();

/**
 * Captura exceção manualmente
 */
export function captureException(error, context = {}) {
  Sentry.captureException(error, {
    contexts: { custom: context },
  });
  logger.error('Exception captured by Sentry', {
    error: error.message,
    context,
  });
}

/**
 * Adiciona breadcrumb
 */
export function addBreadcrumb(message, data = {}, level = 'info') {
  Sentry.addBreadcrumb({
    message,
    level,
    data,
    timestamp: Date.now() / 1000,
  });
}
