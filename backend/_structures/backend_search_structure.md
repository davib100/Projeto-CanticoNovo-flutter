/backend
├── server.mjs
├── /config
│   ├── database.mjs
│   ├── sentry.mjs
│   ├── env.mjs
│   └── app.mjs
├── /models
│   ├── userModel.mjs
│   ├── musicModel.mjs
│   ├── searchHistoryModel.mjs
│   └── sessionModel.mjs
├── /services
│   ├── authService.mjs
│   ├── musicService.mjs
│   ├── searchService.mjs
│   └── analyticsService.mjs
├── /controllers
│   ├── authController.mjs
│   ├── musicController.mjs
│   └── searchController.mjs
├── /routes
│   ├── authRoutes.mjs
│   ├── musicRoutes.mjs
│   └── searchRoutes.mjs
├── /middlewares
│   ├── authMiddleware.mjs
│   ├── errorHandler.mjs
│   ├── requestLogger.mjs
│   └── rateLimiter.mjs
├── /utils
│   ├── logger.mjs
│   ├── validators.mjs
│   └── responseFormatter.mjs
└── /migrations
    ├── 001_create_users.mjs
    ├── 002_create_music.mjs
    ├── 003_create_search_history.mjs
    └── 004_create_sessions.mjs
