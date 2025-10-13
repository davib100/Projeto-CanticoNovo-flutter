import express from 'express';
import { AuthController } from '../controllers/authController.mjs';
import { authMiddleware } from '../middlewares/authMiddleware.mjs';

const router = express.Router();

// Login via OAuth
router.post('/login', AuthController.login);

// Refresh token
router.post('/refresh', AuthController.refresh);

// Logout
router.post('/logout', authMiddleware, AuthController.logout);
router.post('/logout-all', authMiddleware, AuthController.logoutAll);

// Me
router.get('/me', authMiddleware, AuthController.me);

export default router;
