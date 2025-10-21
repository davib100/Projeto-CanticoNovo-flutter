import 'package:flutter/material.dart';
import 'package:myapp/core/module_registry.dart';
import 'presentation/screens/karaoke_list_screen.dart';

@AppModule(
  name: 'KaraokeModule',
  persistenceType:
      PersistenceType.direct, // Não usa QueueManager - dados temporários
  priority: 8,
)
class KaraokeModule extends AppModule {
  @override
  String get name => 'KaraokeModule';

  @override
  String get mainAction => 'Executar Karaokê';

  @override
  bool get useQueue => false;

  KaraokeModule({
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
