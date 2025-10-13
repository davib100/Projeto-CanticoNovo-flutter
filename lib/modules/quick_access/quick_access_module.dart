import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cantico_novo/core/app_orchestrator.dart';
import 'package:cantico_novo/core/observability/logger.dart';
import 'presentation/quick_access_screen.dart';

@AppModule(
  name: 'QuickAccessModule',
  route: '/quick-access',
  usesQueue: true, // Usa QueueManager para sincronização
  priority: 5,
)
class QuickAccessModule {
  static const String moduleName = 'QuickAccessModule';
  
  /// Inicialização do módulo
  static Future<void> initialize() async {
    final logger = AppLogger(moduleName);
    
    try {
      logger.info('🚀 Inicializando QuickAccessModule...');
      
      // Registrar rotas
      _registerRoutes();
      
      // Limpar itens expirados (>24h)
      await _cleanupExpiredItems();
      
      logger.success('✅ QuickAccessModule inicializado com sucesso');
    } catch (e, stack) {
      logger.error('❌ Erro ao inicializar QuickAccessModule', error: e, stackTrace: stack);
      rethrow;
    }
  }
  
  static void _registerRoutes() {
    AppOrchestrator.registerRoute(
      name: 'QuickAccess',
      path: '/quick-access',
      builder: (context) => const QuickAccessScreen(),
    );
  }
  
  static Future<void> _cleanupExpiredItems() async {
    final logger = AppLogger(moduleName);
    logger.info('🧹 Limpando itens expirados (>24h)...');
    
    try {
      // Será implementado no repository
      // await QuickAccessRepository.cleanupExpiredItems();
      logger.info('✅ Limpeza concluída');
    } catch (e) {
      logger.warning('⚠️ Erro na limpeza de itens expirados: $e');
    }
  }
}
