import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { config } from './env.mjs';
import { initSentry, sentryRequestHandler, sentryErrorHandler } from './sentry.mjs';
import { requestLogger } from '../middlewares/requestLogger.mjs';
import { errorHandler } from '../middlewares/errorHandler.mjs';
import { rateLimiter } from '../middlewares/rateLimiter.mjs';
import { logger } from '../utils/logger.mjs';

// Routes
import authRoutes from '../routes/authRoutes.mjs';
import musicRoutes from '../routes/musicRoutes.mjs';
import searchRoutes from '../routes/searchRoutes.mjs';

/**
 * Configura aplicação Express
 */
export function createApp() {
  const app = express();

  // Sentry (deve vir antes de qualquer middleware)
  initSentry(app);
  app.use(sentryRequestHandler);

  // Security
  app.use(helmet({
    contentSecurityPolicy: false, // Desabilita CSP para APIs
    crossOriginEmbedderPolicy: false,
  }));

  // CORS
  app.use(cors({
    origin: config.CORS_ORIGIN,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  }));

  // Compression
  app.use(compression());

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Request logging
  app.use(requestLogger);

  // Rate limiting
  app.use('/api', rateLimiter);

  // Health check
  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      environment: config.NODE_ENV,
      uptime: process.uptime(),
    });
  });

  // API Routes
  app.use('/api/auth', authRoutes);
  app.use('/api/music', musicRoutes);
  app.use('/api/search', searchRoutes);

  // 404 Handler
  app.use((req, res) => {
    res.status(404).json({
      success: false,
      error: {
        code: 'NOT_FOUND',
        message: `Route ${req.method} ${req.path} not found`,
      },
    });
  });

  // Sentry error handler (deve vir antes do errorHandler)
  app.use(sentryErrorHandler);

  // Global error handler
  app.use(errorHandler);

  return app;
}

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import { config } from './env.mjs';

export function configureApp(app) {
  // Security
  app.use(helmet());
  
  // CORS
  app.use(cors({
    origin: config.CORS_ORIGIN,
    credentials: true,
  }));

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Compression
  app.use(compression());

  // Logging
  if (config.NODE_ENV === 'development') {
    app.use(morgan('dev'));
  } else {
    app.use(morgan('combined'));
  }

  // Health check
  app.get('/health', (req, res) => {
    res.status(200).json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });
  });

  return app;
}

export default configureApp;
