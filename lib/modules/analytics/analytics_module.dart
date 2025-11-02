
import '../../core/module_registry.dart';
import '../../core/db/database_adapter.dart';
import '../../core/queue/queue_manager.dart';

class AnalyticsModule extends AppModule {
  const AnalyticsModule({super.priority, super.lazy});

  @override
  String get name => 'AnalyticsModule';

  @override
  bool get useQueue => false;

  @override
  String get mainAction => 'Track events';

  @override
  Future<void> initialize(DatabaseAdapter db, QueueManager queue) async {
    // A lógica de inicialização do serviço de analytics está no provider,
    // que é instanciado sob demanda. Nenhuma inicialização adicional é necessária aqui.
  }

  @override
  Future<void> dispose() async {
    // No resources to dispose for this module
  }
}
