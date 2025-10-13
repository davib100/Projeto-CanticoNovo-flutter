import { MusicService } from '../services/musicService.mjs';
import { formatSuccess, formatError } from '../utils/responseFormatter.mjs';

export class MusicController {
  /**
   * GET /api/music/:id
   * Busca música por ID
   */
  static async getById(req, res, next) {
    try {
      const { id } = req.params;

      const music = await MusicService.getMusicById(id);

      res.json(formatSuccess(music));
    } catch (error) {
      if (error.message === 'Music not found') {
        return res.status(404).json(
          formatError('NOT_FOUND', 'Music not found')
        );
      }
      next(error);
    }
  }

  /**
   * GET /api/music
   * Lista todas as músicas
   */
  static async getAll(req, res, next) {
    try {
      const { limit, offset, genre, categoryId } = req.query;

      const results = await MusicService.getAllMusic({
        limit: limit ? parseInt(limit, 10) : undefined,
        offset: offset ? parseInt(offset, 10) : undefined,
        genre,
        categoryId,
      });

      res.json(formatSuccess({ results, total: results.length }));
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/music
   * Cria nova música
   */
  static async create(req, res, next) {
    try {
      const music = await MusicService.createMusic(req.body);

      res.status(201).json(formatSuccess(music));
    } catch (error) {
      next(error);
    }
  }

  /**
   * PUT /api/music/:id
   * Atualiza música
   */
  static async update(req, res, next) {
    try {
      const { id } = req.params;

      const music = await MusicService.updateMusic(id, req.body);

      res.json(formatSuccess(music));
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/music/:id
   * Deleta música
   */
  static async delete(req, res, next) {
    try {
      const { id } = req.params;

      await MusicService.deleteMusic(id);

      res.json(formatSuccess({ message: 'Music deleted successfully' }));
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/music/:id/access
   * Registra acesso à música
   */
  static async trackAccess(req, res, next) {
    try {
      const { id } = req.params;

      await MusicService.trackMusicAccess(id);

      res.json(formatSuccess({ message: 'Access tracked' }));
    } catch (error) {
      next(error);
    }
  }
}
