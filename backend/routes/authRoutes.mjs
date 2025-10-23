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

import express from 'express';
import AuthController from '../controllers/authController.mjs';
import authMiddleware from '../middlewares/authMiddleware.mjs';
import {
  loginLimiter,
  registerLimiter,
  resetPasswordLimiter,
} from '../middlewares/rateLimitMiddleware.mjs';

const router = express.Router();

/**
 * @route   POST /api/v1/auth/register
 * @desc    Registrar novo usuário
 * @access  Public
 */
router.post('/register', registerLimiter, AuthController.register);

/**
 * @route   POST /api/v1/auth/login
 * @desc    Login com email e senha
 * @access  Public
 */
router.post('/login', loginLimiter, AuthController.login);

/**
 * @route   POST /api/v1/auth/google
 * @desc    Login com Google OAuth
 * @access  Public
 */
router.post('/google', AuthController.loginWithGoogle);

/**
 * @route   POST /api/v1/auth/microsoft
 * @desc    Login com Microsoft OAuth
 * @access  Public
 */
router.post('/microsoft', AuthController.loginWithMicrosoft);

/**
 * @route   POST /api/v1/auth/facebook
 * @desc    Login com Facebook OAuth
 * @access  Public
 */
router.post('/facebook', AuthController.loginWithFacebook);

/**
 * @route   POST /api/v1/auth/refresh
 * @desc    Renovar access token
 * @access  Public
 */
router.post('/refresh', AuthController.refreshToken);

/**
 * @route   POST /api/v1/auth/logout
 * @desc    Fazer logout
 * @access  Public
 */
router.post('/logout', AuthController.logout);

/**
 * @route   POST /api/v1/auth/revoke-session
 * @desc    Revogar sessão específica
 * @access  Private
 */
router.post('/revoke-session', authMiddleware, AuthController.revokeSession);

/**
 * @route   POST /api/v1/auth/reset-password
 * @desc    Solicitar redefinição de senha
 * @access  Public
 */
router.post('/reset-password', resetPasswordLimiter, AuthController.resetPassword);

/**
 * @route   POST /api/v1/auth/reset-password/confirm
 * @desc    Confirmar redefinição de senha
 * @access  Public
 */
router.post('/reset-password/confirm', AuthController.confirmResetPassword);

/**
 * @route   GET /api/v1/auth/me
 * @desc    Obter dados do usuário autenticado
 * @access  Private
 */
router.get('/me', authMiddleware, AuthController.getMe);

/**
 * @route   GET /api/v1/auth/sessions
 * @desc    Listar sessões ativas
 * @access  Private
 */
router.get('/sessions', authMiddleware, AuthController.getSessions);

export default router;
