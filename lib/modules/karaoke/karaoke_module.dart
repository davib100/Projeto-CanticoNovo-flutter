// /frontend/modules/karaoke/karaoke_module.dart

import 'package:flutter/material.dart';
import '../../core/app_orchestrator.dart';
import '../../core/module_registry.dart';
import 'presentation/screens/karaoke_list_screen.dart';

@AppModule(
  name: 'KaraokeModule',
  persistenceType: PersistenceType.direct, // Não usa QueueManager - dados temporários
  priority: 8,
)
class KaraokeModule extends BaseModule {
  @override
  String get moduleName => 'KaraokeModule';

  @override
  Future<void> initialize() async {
    final startTime = DateTime.now();
    
    try {
      // Log de inicialização
      await logModuleAction(
        action: 'initialize',
        status: ModuleStatus.loading,
        message: 'Inicializando módulo Karaokê',
      );

      // Registrar dependências
      await _registerDependencies();

      // Verificar permissões de áudio
      await _checkAudioPermissions();

      final duration = DateTime.now().difference(startTime);
      
      await logModuleAction(
        action: 'initialize',
        status: ModuleStatus.success,
        message: 'Módulo inicializado com sucesso',
        metadata: {'duration_ms': duration.inMilliseconds},
      );
    } catch (e, stackTrace) {
      await logModuleAction(
        action: 'initialize',
        status: ModuleStatus.error,
        message: 'Erro ao inicializar módulo',
        error: e.toString(),
        stackTrace: stackTrace.toString(),
      );
      rethrow;
    }
  }

  Future<void> _registerDependencies() async {
    // Registrar providers com Riverpod
    // Provider registration será feito no app_orchestrator
  }

  Future<void> _checkAudioPermissions() async {
    // Verificar permissões necessárias para gravação de áudio (futuramente)
  }

  @override
  Widget getMainScreen() {
    return const KaraokeListScreen();
  }

  @override
  Map<String, WidgetBuilder> getRoutes() {
    return {
      '/karaoke': (context) => const KaraokeListScreen(),
      '/karaoke/player': (context) => const KaraokePlayerScreen(),
    };
  }
}
