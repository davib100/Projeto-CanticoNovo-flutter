import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cantico_novo/core/app_module.dart';
import 'package:cantico_novo/core/db/database_adapter.dart';
import 'package:cantico_novo/core/services/http_service.dart';
import 'package:cantico_novo/core/security/token_manager.dart';
import 'package:cantico_novo/core/observability/logger.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'presentation/screens/reset_password_screen.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/usecases/login_usecase.dart';
import 'domain/usecases/register_usecase.dart';
import 'domain/usecases/logout_usecase.dart';
import 'domain/usecases/reset_password_usecase.dart';
import 'providers/auth_provider.dart';

@AppModule(
  name: 'AuthModule',
  version: '1.0.0',
  persistence: PersistenceType.direct, // Sessão usa escrita direta
  priority: ModulePriority.critical,
)
class AuthModule extends BaseModule {
  @override
  String get moduleName => 'AuthModule';

  @override
  Future<void> initialize() async {
    final logger = Logger.instance;
    
    logger.logModuleInit(
      moduleName: moduleName,
      action: 'Initializing Auth Module',
      status: LogStatus.pending,
    );

    try {
      // Registrar datasources
      _registerDataSources();
      
      // Registrar repositories
      _registerRepositories();
      
      // Registrar use cases
      _registerUseCases();
      
      // Registrar providers
      _registerProviders();
      
      // Registrar rotas
      _registerRoutes();

      logger.logModuleInit(
        moduleName: moduleName,
        action: 'Auth Module initialized successfully',
        status: LogStatus.success,
      );
    } catch (e, stackTrace) {
      logger.logModuleInit(
        moduleName: moduleName,
        action: 'Failed to initialize Auth Module',
        status: LogStatus.error,
        metadata: {'error': e.toString()},
      );
      rethrow;
    }
  }

  void _registerDataSources() {
    container.read(authRemoteDataSourceProvider);
    container.read(authLocalDataSourceProvider);
  }

  void _registerRepositories() {
    container.read(authRepositoryProvider);
  }

  void _registerUseCases() {
    container.read(loginUseCaseProvider);
    container.read(registerUseCaseProvider);
    container.read(logoutUseCaseProvider);
    container.read(resetPasswordUseCaseProvider);
  }

  void _registerProviders() {
    container.read(authStateProvider.notifier);
  }

  void _registerRoutes() {
    registerRoute('/login', (context) => const LoginScreen());
    registerRoute('/register', (context) => const RegisterScreen());
    registerRoute('/reset-password', (context) => const ResetPasswordScreen());
  }

  @override
  Map<String, WidgetBuilder> get routes => {
    '/login': (context) => const LoginScreen(),
    '/register': (context) => const RegisterScreen(),
    '/reset-password': (context) => const ResetPasswordScreen(),
  };
}
