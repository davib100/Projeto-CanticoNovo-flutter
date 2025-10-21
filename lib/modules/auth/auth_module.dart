import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/core/module_registry.dart';
import 'package:myapp/core/db/database_adapter.dart';
import 'package:myapp/core/services/http_service.dart';
import 'package:myapp/core/security/token_manager.dart';
import 'package:myapp/core/observability/logger.dart';
import 'package:myapp/core/exceptions/module_exception.dart';
import 'package:myapp/core/routing/route_guard.dart';

import 'presentation/screens/login_screen.dart';
import 'presentation/screens/register_screen.dart';
import 'presentation/screens/reset_password_screen.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'repositories/auth_repository_impl.dart';
import 'usecases/login_usecase.dart';
import 'usecases/register_usecase.dart';
import 'usecases/logout_usecase.dart';
import 'usecases/reset_password_usecase.dart';
import 'presentation/providers/auth_provider.dart';

// ... (código anterior) ...

class AuthModule extends AppModule {
  final Logger _logger = Logger.instance;
  final AuthModuleConfig _config;

  ModuleInitStatus _status = ModuleInitStatus.notStarted;
  final List<String> _initializationLogs = [];

  AuthModule({
    AuthModuleConfig? config,
    ModulePriority priority = ModulePriority.critical,
    bool lazy = false,
  })  : _config = config ?? const AuthModuleConfig(),
        super(priority: priority, lazy: lazy);

  @override
  String get name => 'AuthModule';

  // ... (restante do código do AuthModule) ...
}
