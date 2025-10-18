import 'package:flutter/material.dart';
import 'package:myapp/core/module_registry.dart';
import 'ui/search_screen.dart';

@AppModule(
  name: 'SearchModule',
  version: '1.0.0',
  dependencies: ['AuthModule', 'QuickAccessModule'],
  persistenceType: PersistenceType.direct, // Histórico de busca usa persistência direta
)
class SearchModule extends ModuleBase {
  @override
  String get moduleName => 'SearchModule';

  @override
  Future<void> initialize() async {
    final startTime = DateTime.now();
    
    try {
      // Registra rotas do módulo
      _registerRoutes();
      
      // Inicializa serviços locais
      await _initializeServices();
      
      // Log de sucesso
      logModuleAction(
        moduleName: moduleName,
        action: 'initialize',
        status: ModuleStatus.success,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e, stackTrace) {
      logModuleAction(
        moduleName: moduleName,
        action: 'initialize',
        status: ModuleStatus.error,
        error: e.toString(),
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  void _registerRoutes() {
    RouteRegistry.instance.register(
      '/search',
      (context) => const SearchScreen(),
    );
  }

  Future<void> _initializeServices() async {
    // Carrega histórico de buscas do banco local
    await SearchRepository.instance.loadSearchHistory();
  }

  @override
  Future<void> dispose() async {
    // Limpa recursos do módulo
    await SearchRepository.instance.dispose();
  }

  @override
  Widget buildRoute(String routeName) {
    if (routeName == '/search') {
      return const SearchScreen();
    }
    throw Exception('Route $routeName not found in SearchModule');
  }
}
