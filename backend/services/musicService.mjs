import { MusicModel } from '../models/musicModel.mjs';
import { logger } from '../utils/logger.mjs';

export class MusicService {
  /**
   * Busca música por ID
   */
  static async getMusicById(musicId) {
    try {
      const music = await MusicModel.findById(musicId);

      if (!music) {
        throw new Error('Music not found');
      }

      return music;
    } catch (error) {
      logger.error('Failed to get music', { musicId, error: error.message });
      throw error;
    }
  }

  /**
   * Lista todas as músicas
   */
  static async getAllMusic(options = {}) {
    try {
      return await MusicModel.findAll(options);
    } catch (error) {
      logger.error('Failed to get all music', { error: error.message });
      throw error;
    }
  }

  /**
   * Cria nova música
   */
  static async createMusic(data) {
    try {
      const music = await MusicModel.create(data);
      logger.info('Music created', { musicId: music.id });
      return music;
    } catch (error) {
      logger.error('Failed to create music', { error: error.message });
      throw error;
    }
  }

  /**
   * Atualiza música
   */
  static async updateMusic(musicId, data) {
    try {
      const music = await MusicModel.update(musicId, data);
      logger.info('Music updated', { musicId });
      return music;
    } catch (error) {
      logger.error('Failed to update music', { musicId, error: error.message });
      throw error;
    }
  }

  /**
   * Deleta música
   */
  static async deleteMusic(musicId) {
    try {
      await MusicModel.delete(musicId);
      logger.info('Music deleted', { musicId });
    } catch (error) {
      logger.error('Failed to delete music', { musicId, error: error.message });
      throw error;
    }
  }

  /**
   * Registra acesso à música
   */
  static async trackMusicAccess(musicId) {
    try {
      await MusicModel.incrementAccessCount(musicId);
      logger.info('Music access tracked', { musicId });
    } catch (error) {
      logger.error('Failed to track music access', {
        musicId,
        error: error.message,
      });
      // Não lança erro - é operação secundária
    }
  }
}
