// /modules/settings/settings_module.dart

import 'package:flutter/material.dart';

/// Decorator para registro automático no AppOrchestrator
class AppModule {
  final String name;
  final String route;
  final PersistenceType persistenceType;

  const AppModule({
    required this.name,
    required this.route,
    this.persistenceType = PersistenceType.direct,
  });
}

enum PersistenceType { direct, queue }

@AppModule(
  name: 'SettingsModule',
  route: '/settings',
  persistenceType: PersistenceType.direct, // Escrita direta (dados locais)
)
class SettingsModule {
  static const String moduleName = 'SettingsModule';
  
  /// Rota principal do módulo
  static Widget getScreen() {
    return const SettingsScreen();
  }

  /// Registro de rotas do módulo
  static Map<String, WidgetBuilder> routes = {
    '/settings': (context) => const SettingsScreen(),
  };
}
