import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/core/module_registry.dart';
import 'package:myapp/core/observability/logger.dart';
import 'presentation/quick_access_screen.dart';

@AppModule(
  name: 'QuickAccessModule',
  route: '/quick-access',
  usesQueue: true, // Usa QueueManager para sincronização
  priority: 5,
)
class QuickAccessModule extends AppModule {
  @override
  String get name => 'QuickAccessModule';

  @override
  String get mainAction => 'Acesso Rápido';

  @override
  bool get useQueue => true;

  QuickAccessModule({
    ModulePriority priority = ModulePriority.low,
    bool lazy = true,
  }) : super(priority: priority, lazy: lazy);

  @override
  Future<void> initialize(DatabaseAdapter db, QueueManager queue) async {
    final logger = Logger(moduleName: name);

    try {
      logger.logInfo('🚀 Inicializando QuickAccessModule...');

      // A lógica de registro de rotas agora é tratada centralmente

      await _cleanupExpiredItems(logger);

      logger.logInfo('✅ QuickAccessModule inicializado com sucesso');
    } catch (e, stack) {
      logger.logError(
        '❌ Erro ao inicializar QuickAccessModule',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> _cleanupExpiredItems(Logger logger) async {
    logger.logInfo('🧹 Limpando itens expirados (>24h)...');
    try {
      // Implementação futura no repositório
      logger.logInfo('✅ Limpeza concluída');
    } catch (e) {
      logger.logWarning('⚠️ Erro na limpeza de itens expirados: $e');
    }
  }

  @override
  Future<void> dispose() async {
    // Lógica de liberação de recursos
  }
}
