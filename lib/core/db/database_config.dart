// core/db/database_config.dart

class DatabaseConfig {
  final String databaseName;
  final bool logStatements;
  final int cacheSize;
  final int slowQueryThreshold; // milliseconds
  final bool backupBeforeMigration;
  final bool rollbackOnMigrationFailure;
  
  const DatabaseConfig({
    required this.databaseName,
    required this.logStatements,
    required this.cacheSize,
    required this.slowQueryThreshold,
    required this.backupBeforeMigration,
    required this.rollbackOnMigrationFailure,
  });
  
  factory DatabaseConfig.defaults() {
    return const DatabaseConfig(
      databaseName: 'cantico_novo.db',
      logStatements: kDebugMode,
      cacheSize: 1000,
      slowQueryThreshold: 100,
      backupBeforeMigration: true,
      rollbackOnMigrationFailure: true,
    );
  }
}
