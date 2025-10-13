import { open } from 'sqlite';
import sqlite3 from 'sqlite3';
import { config } from '../config/env.mjs';
import { logger } from '../utils/logger.mjs';

/**
 * Script para rollback de migrations
 * 
 * Uso:
 *   node migrations/rollback.mjs 005
 *   node migrations/rollback.mjs all
 */

async function rollback(migrationName = null) {
  const db = await open({
    filename: config.DATABASE_PATH,
    driver: sqlite3.Database,
  });

  try {
    if (migrationName === 'all') {
      logger.info('Rolling back ALL migrations...');
      
      // Lista todas as migrations em ordem reversa
      const migrations = await db.all(
        'SELECT name, version FROM migrations ORDER BY id DESC'
      );

      for (const migration of migrations) {
        await rollbackMigration(db, migration.name);
      }
      
      logger.info('✅ All migrations rolled back');
    } else if (migrationName) {
      await rollbackMigration(db, migrationName);
    } else {
      // Rollback da última migration
      const lastMigration = await db.get(
        'SELECT name FROM migrations ORDER BY id DESC LIMIT 1'
      );

      if (lastMigration) {
        await rollbackMigration(db, lastMigration.name);
      } else {
        logger.warn('No migrations to rollback');
      }
    }
  } catch (error) {
    logger.error('Rollback failed', { error: error.message });
    throw error;
  } finally {
    await db.close();
  }
}

async function rollbackMigration(db, name) {
  logger.info(`Rolling back migration: ${name}`);

  // Tenta importar e executar down() se existir arquivo
  try {
    const migrationModule = await import(`./${name}.mjs`);
    
    if (migrationModule.down) {
      await migrationModule.down(db);
    }
  } catch (error) {
    logger.warn(`No down() function for ${name}, skipping`);
  }

  // Remove da tabela de migrations
  await db.run('DELETE FROM migrations WHERE name = ?', name);
  
  logger.info(`✅ Rolled back: ${name}`);
}

// Executa rollback
const migrationArg = process.argv[2];
rollback(migrationArg).catch(console.error);
