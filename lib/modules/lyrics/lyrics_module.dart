import 'package:myapp/core/module_registry.dart';

@AppModule()
class LyricsModule extends AppModule {
  @override
  String get name => 'LyricsModule';

  @override
  String get mainAction => 'Visualizar Letras';

  @override
  bool get useQueue => true;

  LyricsModule({
    ModulePriority priority = ModulePriority.normal,
    bool lazy = false,
  }) : super(priority: priority, lazy: lazy);

  @override
  Future<void> initialize(DatabaseAdapter db, QueueManager queue) async {
    // ... (lógica de inicialização)
  }

  @override
  Future<void> dispose() async {
    // ... (lógica de dispose)
  }
}
