import { getDatabase } from '../config/database.mjs';
import { v4 as uuidv4 } from 'uuid';

export class MusicModel {
  /**
   * Busca música por ID
   */
  static async findById(musicId) {
    const db = getDatabase();
    const music = await db.get('SELECT * FROM music WHERE id = ?', musicId);
    
    if (music && music.tags) {
      music.tags = JSON.parse(music.tags);
    }
    
    return music;
  }

  /**
   * Busca todas as músicas (com paginação)
   */
  static async findAll({ limit = 50, offset = 0, genre, categoryId } = {}) {
    const db = getDatabase();
    
    let query = 'SELECT * FROM music WHERE 1=1';
    const params = [];
    
    if (genre) {
      query += ' AND genre = ?';
      params.push(genre);
    }
    
    if (categoryId) {
      query += ' AND category_id = ?';
      params.push(categoryId);
    }
    
    query += ' ORDER BY access_count DESC, last_accessed DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);
    
    const results = await db.all(query, ...params);
    
    return results.map(music => ({
      ...music,
      tags: music.tags ? JSON.parse(music.tags) : [],
    }));
  }

  /**
   * Busca full-text (título, artista, letra)
   */
  static async search(query, { limit = 50, offset = 0 } = {}) {
    const db = getDatabase();
    
    // Busca usando FTS5
    const results = await db.all(
      `SELECT m.* 
       FROM music_fts fts
       INNER JOIN music m ON fts.id = m.id
       WHERE music_fts MATCH ?
       ORDER BY rank, m.access_count DESC
       LIMIT ? OFFSET ?`,
      [query, limit, offset]
    );
    
    return results.map(music => ({
      ...music,
      tags: music.tags ? JSON.parse(music.tags) : [],
    }));
  }

  /**
   * Cria nova música
   */
  static async create(data) {
    const db = getDatabase();
    const musicId = uuidv4();
    
    await db.run(
      `INSERT INTO music (
        id, title, artist, lyrics, chords, category_id, genre, 
        key, tempo, duration, sheet_music_url, audio_url, tags
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        musicId,
        data.title,
        data.artist || null,
        data.lyrics,
        data.chords || null,
        data.categoryId || null,
        data.genre || null,
        data.key || null,
        data.tempo || null,
        data.duration || null,
        data.sheetMusicUrl || null,
        data.audioUrl || null,
        data.tags ? JSON.stringify(data.tags) : null,
      ]
    );
    
    return await this.findById(musicId);
  }

  /**
   * Atualiza música
   */
  static async update(musicId, data) {
    const db = getDatabase();
    
    const fields = [];
    const values = [];
    
    if (data.title !== undefined) {
      fields.push('title = ?');
      values.push(data.title);
    }
    if (data.artist !== undefined) {
      fields.push('artist = ?');
      values.push(data.artist);
    }
    if (data.lyrics !== undefined) {
      fields.push('lyrics = ?');
      values.push(data.lyrics);
    }
    if (data.chords !== undefined) {
      fields.push('chords = ?');
      values.push(data.chords);
    }
    if (data.genre !== undefined) {
      fields.push('genre = ?');
      values.push(data.genre);
    }
    if (data.tags !== undefined) {
      fields.push('tags = ?');
      values.push(JSON.stringify(data.tags));
    }
    if (data.lastAccessed !== undefined) {
      fields.push('last_accessed = ?');
      values.push(data.lastAccessed);
    }
    if (data.accessCount !== undefined) {
      fields.push('access_count = ?');
      values.push(data.accessCount);
    }
    
    fields.push('updated_at = CURRENT_TIMESTAMP');
    values.push(musicId);
    
    await db.run(
      `UPDATE music SET ${fields.join(', ')} WHERE id = ?`,
      ...values
    );
    
    return await this.findById(musicId);
  }

  /**
   * Incrementa contador de acesso
   */
  static async incrementAccessCount(musicId) {
    const db = getDatabase();
    
    await db.run(
      `UPDATE music 
       SET access_count = access_count + 1, 
           last_accessed = CURRENT_TIMESTAMP
       WHERE id = ?`,
      musicId
    );
  }

  /**
   * Deleta música
   */
  static async delete(musicId) {
    const db = getDatabase();
    await db.run('DELETE FROM music WHERE id = ?', musicId);
  }

  /**
   * Busca sugestões (autocomplete)
   */
  static async getSuggestions(query, limit = 5) {
    const db = getDatabase();
    
    return await db.all(
      `SELECT DISTINCT title 
       FROM music 
       WHERE title LIKE ? 
       ORDER BY access_count DESC 
       LIMIT ?`,
      [`%${query}%`, limit]
    );
  }
}
