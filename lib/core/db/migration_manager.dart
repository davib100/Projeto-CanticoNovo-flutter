// core/db/migration_manager.dart
import 'dart:developer' as developer;
import 'package:drift/drift.dart';
import '../../../core/migrations/migration_v1_to_v2.dart';
import '../../../core/migrations/migration_v2_to_v3.dart';
import '../../../core/migrations/migration_v3_to_v4.dart';

class MigrationManager {
  static final Map<int, Migration> _migrations = {
    1: MigrationV1ToV2(),
    2: MigrationV2ToV3(),
    3: MigrationV3ToV4(),
  };
  
  /// Executa todas as migrações necessárias de [from] até [to]
  static Future<void> runMigrations(
    Migrator migrator, 
    int from, 
    int to
  ) async {
    if (from == to) return;
    
    for (int version = from; version < to; version++) {
      final migration = _migrations[version];
      
      if (migration == null) {
        throw MigrationNotFoundException(
          'Migration from version $version to ${version + 1} not found'
        );
      }
      
      try {
        await migration.migrate(migrator);
        developer.log('✅ Migration v$version -> v${version + 1} completed', name: 'MigrationManager');
      } catch (e) {
        throw MigrationFailedException(
          'Failed to migrate from v$version to v${version + 1}: $e'
        );
      }
    }
  }
  
  /// Registra uma nova migração
  static void registerMigration(int version, Migration migration) {
    _migrations[version] = migration;
  }
  
  /// Valida se todas as migrações estão disponíveis
  static bool validateMigrationChain(int from, int to) {
    for (int version = from; version < to; version++) {
      if (!_migrations.containsKey(version)) {
        return false;
      }
    }
    return true;
  }
  
  /// Retorna o histórico de migrações aplicadas
  static Future<List<MigrationRecord>> getMigrationHistory(
    GeneratedDatabase db
  ) async {
    final results = await db.customSelect(
      'SELECT * FROM migration_history ORDER BY applied_at DESC'
    ).get();
    
    return results.map((row) => MigrationRecord(
      version: row.read<int>('version'),
      description: row.read<String>('description'),
      appliedAt: DateTime.parse(row.read<String>('applied_at')),
    )).toList();
  }
}

/// Interface base para migrações
abstract class Migration {
  String get description;
  
  Future<void> migrate(Migrator migrator);
}

/// Exceção para migração não encontrada
class MigrationNotFoundException implements Exception {
  final String message;
  MigrationNotFoundException(this.message);
  
  @override
  String toString() => 'MigrationNotFoundException: $message';
}

/// Exceção para falha na migração
class MigrationFailedException implements Exception {
  final String message;
  MigrationFailedException(this.message);
  
  @override
  String toString() => 'MigrationFailedException: $message';
}

/// Registro de migração aplicada
class MigrationRecord {
  final int version;
  final String description;
  final DateTime appliedAt;
  
  MigrationRecord({
    required this.version,
    required this.description,
    required this.appliedAt,
  });
}
