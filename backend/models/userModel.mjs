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
