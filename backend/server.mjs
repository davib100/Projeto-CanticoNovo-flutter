import { createApp } from './config/app.mjs';
import { initDatabase, closeDatabase } from './config/database.mjs';
import { config } from './config/env.mjs';
import { logger } from './utils/logger.mjs';
import { SessionModel } from './models/sessionModel.mjs';
import analyticsRoutes from '../routes/analyticsRoutes.mjs';

let server = null;
app.use('/api/analytics', analyticsRoutes);
/**
 * Inicia servidor
 */
async function startServer() {
  try {
    // Inicializa banco de dados
    await initDatabase();

    // Cria app Express
    const app = createApp();

    // Inicia servidor
    server = app.listen(config.PORT, config.HOST, () => {
      logger.info('🚀 Server started successfully', {
        environment: config.NODE_ENV,
        host: config.HOST,
        port: config.PORT,
        url: `http://${config.HOST}:${config.PORT}`,
      });
    });

    // Limpa sessões expiradas periodicamente (1x por hora)
    setInterval(async () => {
      try {
        const deleted = await SessionModel.cleanExpired();
        if (deleted > 0) {
          logger.info('Expired sessions cleaned', { count: deleted });
        }
      } catch (error) {
        logger.error('Failed to clean expired sessions', { error: error.message });
      }
    }, 60 * 60 * 1000);

  } catch (error) {
    logger.error('❌ Failed to start server', { error: error.message });
    process.exit(1);
  }
}

/**
 * Graceful shutdown
 */
async function shutdown(signal) {
  logger.info(`${signal} received, shutting down gracefully...`);

  if (server) {
    server.close(async () => {
      logger.info('HTTP server closed');

      await closeDatabase();
      logger.info('Database connection closed');

      logger.info('✅ Shutdown complete');
      process.exit(0);
    });

    // Força encerramento após 30s
    setTimeout(() => {
      logger.error('Forced shutdown after timeout');
      process.exit(1);
    }, 30000);
  } else {
    process.exit(0);
  }
}

// Tratamento de sinais
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Tratamento de erros não capturados
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception', { error: error.message, stack: error.stack });
  shutdown('UNCAUGHT_EXCEPTION');
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection', { reason, promise });
  shutdown('UNHANDLED_REJECTION');
});

// Inicia servidor
startServer();
