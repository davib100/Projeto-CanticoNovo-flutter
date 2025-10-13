import { open } from 'sqlite';
import sqlite3 from 'sqlite3';
import { config } from '../config/env.mjs';

/**
 * Mostra status de todas as migrations
 * 
 * Uso:
 *   node migrations/status.mjs
 */

async function showStatus() {
  const db = await open({
    filename: config.DATABASE_PATH,
    driver: sqlite3.Database,
  });

  try {
    // Verifica se tabela migrations existe
    const tableExists = await db.get(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='migrations'"
    );

    if (!tableExists) {
      console.log('❌ No migrations table found. Run initDatabase() first.');
      return;
    }

    // Lista migrations aplicadas
    const appliedMigrations = await db.all(
      'SELECT name, version, executed_at FROM migrations ORDER BY id'
    );

    console.log('\n' + '='.repeat(80));
    console.log('MIGRATIONS STATUS');
    console.log('='.repeat(80));
    
    if (appliedMigrations.length === 0) {
      console.log('\n❌ No migrations applied yet.');
    } else {
      console.log(`\n✅ ${appliedMigrations.length} migrations applied:\n`);
      
      appliedMigrations.forEach((migration, index) => {
        console.log(`${index + 1}. [${migration.version}] ${migration.name}`);
        console.log(`   Executed: ${migration.executed_at}\n`);
      });
    }
    
    console.log('='.repeat(80) + '\n');

  } catch (error) {
    console.error('Failed to get status:', error.message);
  } finally {
    await db.close();
  }
}

showStatus().catch(console.error);
