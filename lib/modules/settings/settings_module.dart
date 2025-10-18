// /modules/settings/settings_module.dart

import 'package:flutter/material.dart';
import 'package:myapp/core/module_registry.dart';
import 'screens/settings_screen.dart';


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
