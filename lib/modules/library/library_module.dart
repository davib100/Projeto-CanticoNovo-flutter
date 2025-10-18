import 'package:flutter/material.dart';
import 'package:myapp/core/module_registry.dart';

@AppModule(
  name: 'LibraryModule',
  persistenceType: PersistenceType.queue, // Usa QueueManager
  priority: 2,
)
class LibraryModule extends BaseModule {
  @override
  String get moduleName => 'LibraryModule';

  @override
  Future<void> initialize() async {
    // Registro de dependências
    final container = ProviderContainer();
    
    logger.info('🎵 LibraryModule: Inicializando módulo...');
    
    // Registra serviços no orquestrador
    await registerServices();
    
    // Executa migração de schema se necessário
    await runMigrations();
    
    logger.success('✅ LibraryModule: Módulo inicializado com sucesso');
  }

  Future<void> registerServices() async {
    // Serviços são providos via Riverpod
    logger.info('📦 LibraryModule: Registrando serviços...');
  }

  Future<void> runMigrations() async {
    final migrationManager = MigrationManager();
    await migrationManager.runMigrations('library');
  }

  @override
  Widget buildRoute(BuildContext context) {
    return const LibraryScreen();
  }
}
