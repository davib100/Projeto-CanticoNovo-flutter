// /modules/lyrics/lyrics_module.dart

import '../../../core/app_orchestrator.dart';
import '../../../core/module_registry.dart';
import '../../../core/observability/logger.dart';

@AppModule()
class LyricsModule implements AppModuleInterface {
  @override
  String get name => 'LyricsModule';

  @override
  ModulePersistenceType get persistenceType => ModulePersistenceType.queue;

  @override
  Future<void> initialize(AppOrchestrator orchestrator) async {
    final logger = orchestrator.logger;

    logger.info('🎵 Inicializando LyricsModule...');

    // Registrar rotas
    orchestrator.registerRoute('/lyrics/:id', (context, params) {
      return LyricsScreen(musicId: params['id']!);
    });

    // Registrar migração de tabela Music (se necessário)
    await orchestrator.migrationManager.registerMigration(
      version: 1,
      migration: () async {
        logger.info('Aplicando migração da tabela Music');
        // Migração já definida no schema Drift
      },
    );

    logger.success('✅ LyricsModule inicializado com sucesso');
  }

  @override
  Future<void> dispose() async {
    // Cleanup se necessário
  }
}