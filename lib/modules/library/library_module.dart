import 'package:flutter/material.dart';
import 'package:myapp/core/module_registry.dart';

@AppModule(
  name: 'LibraryModule',
  persistenceType: PersistenceType.queue, // Usa QueueManager
  priority: 2,
)
class LibraryModule extends AppModule {
  @override
  String get name => 'LibraryModule';

  @override
  String get mainAction => 'Gerenciar Biblioteca';

  @override
  bool get useQueue => true;

  LibraryModule({
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
