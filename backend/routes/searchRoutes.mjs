import express from 'express';
import { SearchController } from '../controllers/searchController.mjs';
import { authMiddleware, optionalAuth } from '../middlewares/authMiddleware.mjs';

const router = express.Router();

// Busca músicas (autenticação opcional)
router.post('/', optionalAuth, SearchController.search);

// Sugestões (sem autenticação)
router.get('/suggestions', SearchController.getSuggestions);

// Histórico (requer autenticação)
router.get('/history', authMiddleware, SearchController.getHistory);
router.delete('/history', authMiddleware, SearchController.clearHistory);

// Analytics (sem autenticação)
router.get('/top', SearchController.getTopSearches);

export default router;
