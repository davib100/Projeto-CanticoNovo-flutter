import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/core/app_module.dart';
import 'package:myapp/core/db/database_adapter.dart';
import 'package:myapp/core/services/http_service.dart';
import 'package:myapp/core/security/token_manager.dart';
import 'package:myapp/core/observability/observability_service.dart';
import 'package:myapp/modules/auth/core/module_exception.dart';
import 'package:myapp/modules/auth/routing/route_guard.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:myapp/modules/auth/screens/login_screen.dart';
import 'package:myapp/modules/auth/screens/register_screen.dart';
import 'package:myapp/modules/auth/screens/reset_password.dart';
import 'package:myapp/modules/auth/datasource/auth_remote_datasource.dart';
import 'package:myapp/modules/auth/datasource/auth_local_datasource.dart';
import 'package:myapp/modules/auth/repositories/auth_repository_impl.dart';
import 'package:myapp/modules/auth/usecases/login_usecase.dart';
import 'package:myapp/modules/auth/usecases/register_usecase.dart';
import 'package:myapp/modules/auth/usecases/logout_usecase.dart';
import 'package:myapp/modules/auth/usecases/reset_password_usecase.dart';
import 'package:myapp/modules/auth/providers/auth_provider.dart';

/// Configurações do módulo de autenticação
class AuthModuleConfig {
  final Duration sessionTimeout;
  final Duration tokenRefreshInterval;
  final int maxLoginAttempts;
  final bool enableBiometrics;
  final bool enableOAuth;
  final List<String> allowedOAuthProviders;
  
  const AuthModuleConfig({
    this.sessionTimeout = const Duration(hours: 1),
    this.tokenRefreshInterval = const Duration(minutes: 50),
    this.maxLoginAttempts = 5,
    this.enableBiometrics = true,
    this.enableOAuth = true,
    this.allowedOAuthProviders = const ['google', 'microsoft', 'facebook'],
  });
}

/// Provider para configuração do módulo
final authModuleConfigProvider = Provider<AuthModuleConfig>((ref) {
  return const AuthModuleConfig();
});

/// Status de inicialização do módulo
enum ModuleInitStatus {
  notStarted,
  validating,
  registeringDependencies,
  registeringProviders,
  registeringRoutes,
  healthCheck,
  completed,
  failed,
}

/// Resultado da inicialização
class InitializationResult {
  final bool success;
  final ModuleInitStatus status;
  final String? error;
  final Duration duration;
  final Map<String, dynamic> metadata;

  const InitializationResult({
    required this.success,
    required this.status,
    this.error,
    required this.duration,
    this.metadata = const {},
  });

  InitializationResult copyWith({
    bool? success,
    ModuleInitStatus? status,
    String? error,
    Duration? duration,
    Map<String, dynamic>? metadata,
  }) {
    return InitializationResult(
      success: success ?? this.success,
      status: status ?? this.status,
      error: error ?? this.error,
      duration: duration ?? this.duration,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum LogStatus { pending, success, error }

/// Módulo de autenticação com arquitetura otimizada e autocorreção
@AppModule(
  name: 'AuthModule',
  version: '2.0.0',
  persistence: PersistenceType.direct,
  priority: ModulePriority.critical,
)
class AuthModule extends BaseModule {
  final ObservabilityService _observability = ObservabilityService();
  final AuthModuleConfig _config;
  
  ModuleInitStatus _status = ModuleInitStatus.notStarted;
  final List<String> _initializationLogs = [];
  
  AuthModule({AuthModuleConfig? config}) 
      : _config = config ?? const AuthModuleConfig();

  @override
  String get moduleName => 'AuthModule';

  @override
  String get version => '2.0.0';

  /// Validação pré-inicialização
  Future<bool> _validateDependencies(WidgetRef ref) async {
    try {
      _log('Validating dependencies', LogStatus.pending);
      
      // Verificar dependências core
      final requiredProviders = [
        databaseAdapterProvider,
        httpServiceProvider,
        tokenManagerProvider,
      ];

      for (final provider in requiredProviders) {
        try {
          ref.read(provider);
        } catch (e) {
          throw ModuleException(
            'Required dependency not available: \${provider.name ?? 'unknown'}',
            module: moduleName,
          );
        }
      }

      _log('Dependencies validated', LogStatus.success);
      return true;
    } catch (e) {
      _log('Dependency validation failed: $e', LogStatus.error);
      return false;
    }
  }

  /// Registro de datasources com factory pattern
  void _registerDataSources(WidgetRef ref) {
    _log('Registering datasources', LogStatus.pending);
    
    try {
      // Lazy initialization para otimização
      ref.read(authRemoteDataSourceProvider);
      ref.read(authLocalDataSourceProvider);
      
      _log('Datasources registered', LogStatus.success);
    } catch (e, stackTrace) {
      _log('Failed to register datasources: $e', LogStatus.error);
      _observability.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Datasource registration failed',
        extra: {'module': moduleName},
      );
      rethrow;
    }
  }

  /// Registro de repositories
  void _registerRepositories(WidgetRef ref) {
    _log('Registering repositories', LogStatus.pending);
    
    try {
      ref.read(authRepositoryProvider);
      _log('Repositories registered', LogStatus.success);
    } catch (e, stackTrace) {
      _log('Failed to register repositories: $e', LogStatus.error);
      _observability.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Repository registration failed',
        extra: {'module': moduleName},
      );
      rethrow;
    }
  }

  /// Registro de use cases
  void _registerUseCases(WidgetRef ref) {
    _log('Registering use cases', LogStatus.pending);
    
    try {
      final useCases = [
        loginUseCaseProvider,
        registerUseCaseProvider,
        logoutUseCaseProvider,
        resetPasswordUseCaseProvider,
      ];

      for (final useCase in useCases) {
        ref.read(useCase);
      }
      
      _log('Use cases registered', LogStatus.success);
    } catch (e, stackTrace) {
      _log('Failed to register use cases: $e', LogStatus.error);
      _observability.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Use case registration failed',
        extra: {'module': moduleName},
      );
      rethrow;
    }
  }

  /// Registro de providers com lifecycle management
  void _registerProviders(WidgetRef ref) {
    _log('Registering state providers', LogStatus.pending);
    
    try {
      // Provider principal com keepAlive para manter estado
      ref.read(authStateProvider.notifier);
      
      _log('State providers registered', LogStatus.success);
    } catch (e, stackTrace) {
      _log('Failed to register providers: $e', LogStatus.error);
      _observability.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Provider registration failed',
        extra: {'module': moduleName},
      );
      rethrow;
    }
  }

  /// Registro de rotas com guards
  void _registerRoutes() {
    _log('Registering routes', LogStatus.pending);
    
    try {
      // Rotas públicas
      registerRoute(
        '/login',
        (context) => const LoginScreen(),
      );
      
      registerRoute(
        '/register',
        (context) => const RegisterScreen(),
      );
      
      registerRoute(
        '/reset-password',
        (context) => const ResetPasswordScreen(),
      );
      
      _log('Routes registered (3 routes)', LogStatus.success);
    } catch (e, stackTrace) {
      _log('Failed to register routes: $e', LogStatus.error);
      _observability.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Route registration failed',
        extra: {'module': moduleName},
      );
      rethrow;
    }
  }

  /// Health check do módulo
  Future<bool> _performHealthCheck(WidgetRef ref) async {
    _log('Performing health check', LogStatus.pending);
    
    try {
      // Verificar se providers estão funcionais
      final authState = ref.read(authStateProvider);
      
      // Verificar conexão com datasources
      final localDataSource = ref.read(authLocalDataSourceProvider);
      final hasValidSession = await localDataSource.hasValidSession();
      
      _log(
        'Health check passed (Session: \${hasValidSession ? 'Valid' : 'Invalid'})',
        LogStatus.success,
      );
      
      return true;
    } catch (e, stackTrace) {
      _log('Health check failed: $e', LogStatus.error);
      _observability.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Health check failed',
        extra: {'module': moduleName},
      );
      return false;
    }
  }

  /// Helper para logging estruturado
  void _log(String message, LogStatus status) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    _initializationLogs.add(logEntry);
    
    _observability.addBreadcrumb(
      message,
      category: 'module_init',
      level: status == LogStatus.error ? SentryLevel.error : SentryLevel.info,
      data: {
        'module': moduleName,
        'status': status.name,
        'current_status': _status.name,
      },
    );
  }

  @override
  Future<void> initialize(WidgetRef ref) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      _status = ModuleInitStatus.validating;
      _log('Starting AuthModule initialization v$version', LogStatus.pending);

      // 1. Validar dependências
      final isValid = await _validateDependencies(ref);
      if (!isValid) {
        throw ModuleException(
          'Dependency validation failed',
          module: moduleName,
        );
      }

      // 2. Registrar dependências
      _status = ModuleInitStatus.registeringDependencies;
      _registerDataSources(ref);
      _registerRepositories(ref);
      _registerUseCases(ref);

      // 3. Registrar providers
      _status = ModuleInitStatus.registeringProviders;
      _registerProviders(ref);

      // 4. Registrar rotas
      _status = ModuleInitStatus.registeringRoutes;
      _registerRoutes();

      // 5. Health check
      _status = ModuleInitStatus.healthCheck;
      final healthCheckPassed = await _performHealthCheck(ref);
      
      if (!healthCheckPassed) {
        _observability.captureMessage(
          'Health check failed but module will continue',
          level: SentryLevel.warning,
          extra: {'module': moduleName},
        );
      }

      // 6. Finalizar
      _status = ModuleInitStatus.completed;
      stopwatch.stop();
      
      _log(
        'AuthModule initialized successfully in \${stopwatch.elapsedMilliseconds}ms',
        LogStatus.success,
      );

      _observability.captureMessage(
        'AuthModule initialization complete',
        level: SentryLevel.info,
        extra: {
          'module': moduleName,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'final_status': _status.name,
          'logs': _initializationLogs,
        },
      );

    } catch (e, stackTrace) {
      _status = ModuleInitStatus.failed;
      stopwatch.stop();
      
      final errorMessage = 'AuthModule initialization failed after \${stopwatch.elapsedMilliseconds}ms: $e';
      _log(errorMessage, LogStatus.error);

      _observability.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'AuthModule initialization failed',
        extra: {
          'module': moduleName,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'failed_status': _status.name,
          'logs': _initializationLogs,
        },
      );

      rethrow;
    }
  }

  /// Dispose de recursos
  @override
  Future<void> dispose() async {
    _log('Disposing AuthModule', LogStatus.pending);
    
    try {
      // Limpar providers se necessário (Riverpod já gerencia com autoDispose)
      _log('AuthModule disposed', Log.success);
    } catch (e, stackTrace) {
      _observability.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Error disposing AuthModule',
        extra: {'module': moduleName},
      );
    }
  }

  /// Getter para rotas
  @override
  Map<String, WidgetBuilder> get routes => {
    '/login': (context) => const LoginScreen(),
    '/register': (context) => const RegisterScreen(),
    '/reset-password': (context) => const ResetPasswordScreen(),
  };

  /// Status atual do módulo
  ModuleInitStatus get status => _status;

  /// Logs de inicialização
  List<String> get initializationLogs => List.unmodifiable(_initializationLogs);

  /// Verificar se módulo está pronto
  bool get isReady => _status == ModuleInitStatus.completed;

  /// Obter configuração
  AuthModuleConfig get config => _config;
}

/// Provider do módulo (singleton)
final authModuleProvider = Provider<AuthModule>((ref) {
  final config = ref.watch(authModuleConfigProvider);
  final module = AuthModule(config: config);
  module.initialize(ref);
  return module;
});

abstract class BaseModule {
  String get moduleName;
  String get version;
  
  Map<String, WidgetBuilder> get routes;

  void registerRoute(String path, WidgetBuilder builder) {
    // Implementação do registro de rota
  }
  
  Future<void> initialize(WidgetRef ref);
  Future<void> dispose();
}

class AppModule {
  final String name;
  final String version;
  final PersistenceType persistence;
  final ModulePriority priority;

  const AppModule({
    required this.name,
    required this.version,
    this.persistence = PersistenceType.none,
    this.priority = ModulePriority.normal,
  });
}

enum PersistenceType { direct, indirect, none }
enum ModulePriority { critical, high, normal, low }
