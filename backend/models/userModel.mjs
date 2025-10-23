import { getDatabase } from '../config/database.mjs';
import { v4 as uuidv4 } from 'uuid';

export class UserModel {
  /**
   * Cria ou atualiza usuário via OAuth
   */
  static async upsertOAuthUser(data) {
    const db = getDatabase();
    const userId = uuidv4();
    
    const user = await db.get(
      `SELECT * FROM users WHERE oauth_provider = ? AND oauth_id = ?`,
      [data.provider, data.oauthId]
    );

    if (user) {
      // Atualiza usuário existente
      await db.run(
        `UPDATE users 
         SET full_name = ?, profile_picture = ?, last_login = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
         WHERE id = ?`,
        [data.fullName, data.profilePicture, user.id]
      );
      return { ...user, full_name: data.fullName, profile_picture: data.profilePicture };
    } else {
      // Cria novo usuário
      await db.run(
        `INSERT INTO users (id, email, full_name, profile_picture, oauth_provider, oauth_id, last_login)
         VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
        [userId, data.email, data.fullName, data.profilePicture, data.provider, data.oauthId]
      );
      return await db.get('SELECT * FROM users WHERE id = ?', userId);
    }
  }

  /**
   * Busca usuário por ID
   */
  static async findById(userId) {
    const db = getDatabase();
    return await db.get('SELECT * FROM users WHERE id = ?', userId);
  }

  /**
   * Busca usuário por email
   */
  static async findByEmail(email) {
    const db = getDatabase();
    return await db.get('SELECT * FROM users WHERE email = ?', email);
  }

  /**
   * Atualiza aceite de termos
   */
  static async acceptTerms(userId) {
    const db = getDatabase();
    await db.run(
      `UPDATE users SET terms_accepted = 1, terms_accepted_at = CURRENT_TIMESTAMP WHERE id = ?`,
      userId
    );
  }

  /**
   * Atualiza último login
   */
  static async updateLastLogin(userId) {
    const db = getDatabase();
    await db.run(
      `UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?`,
      userId
    );
  }
}

import { getDatabase } from '../config/database.mjs';
import { v4 as uuidv4 } from 'uuid';

export class UserModel {
  static async create({
    fullName,
    email,
    passwordHash,
    oauthProvider = null,
    oauthId = null,
    photoUrl = null,
  }) {
    const db = getDatabase();
    const id = uuidv4();

    await db.run(
      `INSERT INTO users (
        id, full_name, email, password_hash, 
        oauth_provider, oauth_id, photo_url, email_verified
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        fullName,
        email.toLowerCase(),
        passwordHash,
        oauthProvider,
        oauthId,
        photoUrl,
        oauthProvider ? 1 : 0, // OAuth users are auto-verified
      ]
    );

    return await this.findById(id);
  }

  static async findById(id) {
    const db = getDatabase();
    return await db.get('SELECT * FROM users WHERE id = ?', [id]);
  }

  static async findByEmail(email) {
    const db = getDatabase();
    return await db.get(
      'SELECT * FROM users WHERE email = ? AND is_active = 1',
      [email.toLowerCase()]
    );
  }

  static async findByOAuth(provider, oauthId) {
    const db = getDatabase();
    return await db.get(
      'SELECT * FROM users WHERE oauth_provider = ? AND oauth_id = ? AND is_active = 1',
      [provider, oauthId]
    );
  }

  static async updateLastLogin(userId) {
    const db = getDatabase();
    await db.run(
      'UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = ?',
      [userId]
    );
  }

  static async incrementFailedAttempts(userId) {
    const db = getDatabase();
    await db.run(
      'UPDATE users SET failed_login_attempts = failed_login_attempts + 1 WHERE id = ?',
      [userId]
    );
  }

  static async resetFailedAttempts(userId) {
    const db = getDatabase();
    await db.run(
      'UPDATE users SET failed_login_attempts = 0, locked_until = NULL WHERE id = ?',
      [userId]
    );
  }

  static async lockAccount(userId, duration) {
    const db = getDatabase();
    const lockedUntil = new Date(Date.now() + duration * 60 * 1000).toISOString();
    
    await db.run(
      'UPDATE users SET locked_until = ? WHERE id = ?',
      [lockedUntil, userId]
    );
  }

  static async isAccountLocked(userId) {
    const db = getDatabase();
    const user = await db.get(
      'SELECT locked_until FROM users WHERE id = ?',
      [userId]
    );

    if (!user || !user.locked_until) return false;

    const lockedUntil = new Date(user.locked_until);
    const now = new Date();

    if (now < lockedUntil) {
      return true;
    }

    // Desbloquear automaticamente se o tempo expirou
    await this.resetFailedAttempts(userId);
    return false;
  }

  static async updatePassword(userId, newPasswordHash) {
    const db = getDatabase();
    await db.run(
      'UPDATE users SET password_hash = ? WHERE id = ?',
      [newPasswordHash, userId]
    );
  }

  static async verifyEmail(userId) {
    const db = getDatabase();
    await db.run(
      'UPDATE users SET email_verified = 1 WHERE id = ?',
      [userId]
    );
  }

  static async update(userId, data) {
    const db = getDatabase();
    const fields = [];
    const values = [];

    if (data.fullName) {
      fields.push('full_name = ?');
      values.push(data.fullName);
    }
    if (data.photoUrl !== undefined) {
      fields.push('photo_url = ?');
      values.push(data.photoUrl);
    }

    if (fields.length === 0) return;

    values.push(userId);

    await db.run(
      `UPDATE users SET ${fields.join(', ')} WHERE id = ?`,
      values
    );

    return await this.findById(userId);
  }

  static async delete(userId) {
    const db = getDatabase();
    await db.run('UPDATE users SET is_active = 0 WHERE id = ?', [userId]);
  }

  static sanitize(user) {
    if (!user) return null;

    const { password_hash, failed_login_attempts, locked_until, ...sanitized } = user;
    
    return {
      id: sanitized.id,
      fullName: sanitized.full_name,
      email: sanitized.email,
      photoUrl: sanitized.photo_url,
      oauthProvider: sanitized.oauth_provider,
      emailVerified: Boolean(sanitized.email_verified),
      createdAt: sanitized.created_at,
      lastLoginAt: sanitized.last_login_at,
    };
  }
}

export default UserModel;
