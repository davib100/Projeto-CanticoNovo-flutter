import express from 'express';
import { AnalyticsController } from '../controllers/analyticsController.mjs';
import { authMiddleware, optionalAuth } from '../middlewares/authMiddleware.mjs';

const router = express.Router();

// Estatísticas gerais (sem autenticação)
router.get('/stats/system', AnalyticsController.getSystemStats);

// Músicas mais populares (sem autenticação)
router.get('/popular/music', AnalyticsController.getMostPopularMusic);

// Trending músicas (sem autenticação)
router.get('/trending/music', AnalyticsController.getTrendingMusic);

// Termos de busca mais populares (sem autenticação)
router.get('/top/searches', AnalyticsController.getTopSearchTerms);

// Estatísticas do usuário (requer autenticação)
router.get('/stats/user', authMiddleware, AnalyticsController.getUserStats);

// Relatório de atividade diária (sem autenticação)
router.get('/report/daily', AnalyticsController.getDailyActivityReport);

// Exportar analytics (requer autenticação)
router.get('/export', authMiddleware, AnalyticsController.exportAnalytics);

// Limpar dados antigos (requer autenticação - admin apenas)
router.delete('/cleanup', authMiddleware, AnalyticsController.cleanOldData);

export default router;
