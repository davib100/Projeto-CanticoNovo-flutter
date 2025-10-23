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

import express from 'express';
import { config } from './config/env.mjs';
import { configureApp } from './config/app.mjs';
import { initDatabase, closeDatabase } from './config/database.mjs';
import authRoutes from './routes/authRoutes.mjs';
import errorHandler from './middlewares/errorHandler.mjs';
import requestLogger from './middlewares/requestLogger.mjs';
import { generalLimiter } from './middlewares/rateLimitMiddleware.mjs';

const app = express();

// Configurar app
configureApp(app);

// Request logging
app.use(requestLogger);

// Rate limiting geral
app.use('/api', generalLimiter);

// Routes
app.use(`/api/${config.API_VERSION}/auth`, authRoutes);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint não encontrado',
  });
});

// Error handler (deve ser o último middleware)
app.use(errorHandler);

// Inicializar servidor
async function startServer() {
  try {
    // Inicializar banco de dados
    await initDatabase();

    // Iniciar servidor
    app.listen(config.PORT, () => {
      console.log('🚀 ==========================================');
      console.log(`🎵 Cântico Novo Backend - ${config.NODE_ENV}`);
      console.log(`📡 Server running on port ${config.PORT}`);
      console.log(`🔗 http://localhost:${config.PORT}`);
      console.log(`💾 Database: ${config.DB_PATH}`);
      console.log('🚀 ==========================================');
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('⚠️  SIGTERM signal received: closing server');
  await closeDatabase();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('⚠️  SIGINT signal received: closing server');
  await closeDatabase();
  process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Start
startServer();

export default app;
otimo, adfi