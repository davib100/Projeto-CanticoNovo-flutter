import jwt from 'jsonwebtoken';
import { config } from '../config/env.mjs';
import { v4 as uuidv4 } from 'uuid';

export class TokenService {
  static generateAccessToken(payload) {
    return jwt.sign(
      {
        userId: payload.userId,
        email: payload.email,
        deviceId: payload.deviceId,
        type: 'access',
      },
      config.JWT_SECRET,
      { expiresIn: config.JWT_EXPIRATION }
    );
  }

  static generateRefreshToken(payload) {
    return jwt.sign(
      {
        userId: payload.userId,
        deviceId: payload.deviceId,
        tokenId: uuidv4(),
        type: 'refresh',
      },
      config.JWT_REFRESH_SECRET,
      { expiresIn: config.JWT_REFRESH_EXPIRATION }
    );
  }

  static verifyAccessToken(token) {
    try {
      return jwt.verify(token, config.JWT_SECRET);
    } catch (error) {
      throw new Error('Token inválido ou expirado');
    }
  }

  static verifyRefreshToken(token) {
    try {
      return jwt.verify(token, config.JWT_REFRESH_SECRET);
    } catch (error) {
      throw new Error('Refresh token inválido ou expirado');
    }
  }

  static generatePasswordResetToken() {
    return uuidv4();
  }

  static generateEmailVerificationToken() {
    return uuidv4();
  }

  static calculateExpirationDate(expirationString) {
    const match = expirationString.match(/^(\d+)([mhd])$/);
    if (!match) return new Date(Date.now() + 60 * 60 * 1000); // 1 hour default

    const value = parseInt(match[1], 10);
    const unit = match[2];

    let milliseconds;
    switch (unit) {
      case 'm':
        milliseconds = value * 60 * 1000;
        break;
      case 'h':
        milliseconds = value * 60 * 60 * 1000;
        break;
      case 'd':
        milliseconds = value * 24 * 60 * 60 * 1000;
        break;
      default:
        milliseconds = 60 * 60 * 1000;
    }

    return new Date(Date.now() + milliseconds);
  }
}

export default TokenService;
