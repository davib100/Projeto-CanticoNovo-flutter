import 'package:flutter/material.dart';
import '../../core/module_registry.dart';
import '../../core/queue/queue_manager.dart';
import '../core/observability/logger_service.dart';
import 'screens/upload_screen.dart';
import 'services/upload_service.dart';
import 'repositories/upload_repository.dart';

@AppModule(
  name: 'UploadModule',
  persistence: PersistenceType.queue, // Usa fila para sincronização
  routes: {'upload': '/upload', 'upload_edit': '/upload/edit'},
)
class UploadModule extends BaseModule {
  final QueueManager _queueManager;
  final LoggerService _logger;
  late final UploadService _uploadService;
  late final UploadRepository _repository;

  UploadModule({
    required QueueManager queueManager,
    required LoggerService logger,
  }) : _queueManager = queueManager,
       _logger = logger {
    _repository = UploadRepository(queueManager: queueManager, logger: logger);
    _uploadService = UploadService(repository: _repository, logger: logger);
  }

  @override
  Future<void> initialize() async {
    _logger.info('🎵 UploadModule: Iniciando módulo de upload...');

    try {
      await _repository.initialize();
      _logger.success('✅ UploadModule: Módulo inicializado com sucesso');
    } catch (e) {
      _logger.error('❌ UploadModule: Falha na inicialização', error: e);
      rethrow;
    }
  }

  @override
  Map<String, WidgetBuilder> getRoutes() {
    return {
      '/upload': (context) => UploadScreen(uploadService: _uploadService),
      '/upload/edit': (context) {
        final args =
            ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
        return UploadScreen(
          uploadService: _uploadService,
          editMusicId: args?['musicId'],
        );
      },
    };
  }

  @override
  void dispose() {
    _logger.info('🔌 UploadModule: Encerrando módulo...');
    _uploadService.dispose();
  }
}
