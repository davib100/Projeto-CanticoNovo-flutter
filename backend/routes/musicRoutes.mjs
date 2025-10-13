import express from 'express';
import { MusicController } from '../controllers/musicController.mjs';
import { authMiddleware, optionalAuth } from '../middlewares/authMiddleware.mjs';

const router = express.Router();

// Buscar por ID (sem autenticação)
router.get('/:id', MusicController.getById);

// Listar todas (sem autenticação)
router.get('/', MusicController.getAll);

// Criar (requer autenticação - admin)
router.post('/', authMiddleware, MusicController.create);

// Atualizar (requer autenticação - admin)
router.put('/:id', authMiddleware, MusicController.update);

// Deletar (requer autenticação - admin)
router.delete('/:id', authMiddleware, MusicController.delete);

// Registrar acesso (autenticação opcional)
router.post('/:id/access', optionalAuth, MusicController.trackAccess);

export default router;
