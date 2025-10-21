// core/migrations/migration_v1_to_v2.dart
import 'package:drift/drift.dart';
import '../core/db/migration_manager.dart';

/// Migration v1 → v2: Adiciona suporte a soft delete e versionamento
///
/// Mudanças:
/// - Adiciona coluna deleted_at em Songs e Categories
/// - Adiciona coluna version em Songs e Categories para optimistic locking
/// - Adiciona coluna checksum em Songs para validação de integridade
/// - Adiciona índices para otimização de queries com soft delete
class MigrationV1ToV2 implements Migration {
  @override
  String get description => 'Add soft delete and versioning support';

  @override
  Future<void> migrate(Migrator migrator) async {
    // ══════════════════════════════════════════
    // SONGS TABLE
    // ══════════════════════════════════════════

    // Adicionar coluna deleted_at (soft delete)
    await migrator.database
        .customStatement('ALTER TABLE songs ADD COLUMN deleted_at INTEGER');

    // Adicionar coluna version (optimistic locking)
    await migrator.database.customStatement(
        'ALTER TABLE songs ADD COLUMN version INTEGER NOT NULL DEFAULT 1');

    // Adicionar coluna checksum (integridade)
    await migrator.database
        .customStatement('ALTER TABLE songs ADD COLUMN checksum TEXT');

    // Criar índice para soft delete
    await migrator.database.customStatement(
        'CREATE INDEX idx_songs_deleted_v2 ON songs(deleted_at) WHERE deleted_at IS NULL');

    // ══════════════════════════════════════════
    // CATEGORIES TABLE
    // ══════════════════════════════════════════

    // Adicionar coluna deleted_at
    await migrator.database.customStatement(
        'ALTER TABLE categories ADD COLUMN deleted_at INTEGER');

    // Adicionar coluna version
    await migrator.database.customStatement(
        'ALTER TABLE categories ADD COLUMN version INTEGER NOT NULL DEFAULT 1');

    // Adicionar coluna updated_at (tracking de mudanças)
    await migrator.database.customStatement(
        'ALTER TABLE categories ADD COLUMN updated_at INTEGER NOT NULL DEFAULT (strftime(\'%s\', \'now\'))');

    // ══════════════════════════════════════════
    // REGISTRAR MIGRAÇÃO
    // ══════════════════════════════════════════

    await migrator.database.customInsert(
      'INSERT INTO migration_history (version, description, applied_at) VALUES (?, ?, ?)',
      variables: [
        Variable.withInt(2),
        Variable.withString(description),
        Variable.withString(DateTime.now().toIso8601String()),
      ],
    );
  }
}
