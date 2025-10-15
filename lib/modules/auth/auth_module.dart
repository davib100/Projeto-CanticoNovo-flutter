import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cantico_novo/core/app_module.dart';
import 'package:cantico_novo/core/db/database_adapter.dart';
import 'package:cantico_novo/core/services/http_service.dart';
import 'package:cantico_novo/core/security/token_manager.dart';
import 'package:cantico_novo/core/observability/logger.dart';
import 'package:cantico_novo/core/exceptions/module_exception.dart';
import 'package:cantico_novo/core/routing/route_guard.dart';

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

/// Módulo de autenticação com arquitetura otimizada e autocorreção
@AppModule(
  name: 'AuthModule',
  version: '2.0.0',
  persistence: PersistenceType.direct,
  priority: ModulePriority.critical,
)
class AuthModule extends BaseModule {
  final Logger _logger = Logger.instance;
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
  Future<bool> _validateDependencies() async {
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
          container.read(provider);
        } catch (e) {
          throw ModuleException(
            'Required dependency not available: ${provider.name ?? 'unknown'}',
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
  void _registerDataSources() {
    _log('Registering datasources', LogStatus.pending);
    
    try {
      // Lazy initialization para otimização
      container.read(authRemoteDataSourceProvider);
      container.read(authLocalDataSourceProvider);
      
      _log('Datasources registered', LogStatus.success);
    } catch (e, stackTrace) {
      _log('Failed to register datasources: $e', LogStatus.error);
      _logger.logError(
        'Datasource registration failed',
        error: e,
        stackTrace: stackTrace,
        module: moduleName,
      );
      rethrow;
    }
  }

  /// Registro de repositories
  void _registerRepositories() {
    _log('Registering repositories', LogStatus.pending);
    
    try {
      container.read(authRepositoryProvider);
      _log('Repositories registered', LogStatus.success);
    } catch (e, stackTrace) {
      _log('Failed to register repositories: $e', LogStatus.error);
      _logger.logError(
        'Repository registration failed',
        error: e,
        stackTrace: stackTrace,
        module: moduleName,
      );
      rethrow;
    }
  }

  /// Registro de use cases
  void _registerUseCases() {
    _log('Registering use cases', LogStatus.pending);
    
    try {
      final useCases = [
        loginUseCaseProvider,
        registerUseCaseProvider,
        logoutUseCaseProvider,
        resetPasswordUseCaseProvider,
      ];

      for (final useCase in useCases) {
        container.read(useCase);
      }
      
      _log('Use cases registered', LogStatus.success);
    } catch (e, stackTrace) {
      _log('Failed to register use cases: $e', LogStatus.error);
      _logger.logError(
        'Use case registration failed',
        error: e,
        stackTrace: stackTrace,
        module: moduleName,
      );
      rethrow;
    }
  }

  /// Registro de providers com lifecycle management
  void _registerProviders() {
    _log('Registering state providers', LogStatus.pending);
    
    try {
      // Provider principal com keepAlive para manter estado
      container.read(authStateProvider.notifier);
      
      _log('State providers registered', LogStatus.success);
    } catch (e, stackTrace) {
      _log('Failed to register providers: $e', LogStatus.error);
      _logger.logError(
        'Provider registration failed',
        error: e,
        stackTrace: stackTrace,
        module: moduleName,
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
        guards: [],
      );
      
      registerRoute(
        '/register',
        (context) => const RegisterScreen(),
        guards: [],
      );
      
      registerRoute(
        '/reset-password',
        (context) => const ResetPasswordScreen(),
        guards: [],
      );
      
      _log('Routes registered (3 routes)', LogStatus.success);
    } catch (e, stackTrace) {
      _log('Failed to register routes: $e', LogStatus.error);
      _logger.logError(
        'Route registration failed',
        error: e,
        stackTrace: stackTrace,
        module: moduleName,
      );
      rethrow;
    }
  }

  /// Health check do módulo
  Future<bool> _performHealthCheck() async {
    _log('Performing health check', LogStatus.pending);
    
    try {
      // Verificar se providers estão funcionais
      final authState = container.read(authStateProvider);
      
      // Verificar conexão com datasources
      final localDataSource = container.read(authLocalDataSourceProvider);
      final hasValidSession = await localDataSource.hasValidSession();
      
      _log(
        'Health check passed (Session: ${hasValidSession ? 'Valid' : 'Invalid'})',
        LogStatus.success,
      );
      
      return true;
    } catch (e, stackTrace) {
      _log('Health check failed: $e', LogStatus.error);
      _logger.logError(
        'Health check failed',
        error: e,
        stackTrace: stackTrace,
        module: moduleName,
      );
      return false;
    }
  }

  /// Helper para logging estruturado
  void _log(String message, LogStatus status) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    _initializationLogs.add(logEntry);
    
    _logger.logModuleInit(
      moduleName: moduleName,
      action: message,
      status: status,
      metadata: {
        'currentStatus': _status.toString(),
        'config': {
          'sessionTimeout': _config.sessionTimeout.inMinutes,
          'maxLoginAttempts': _config.maxLoginAttempts,
          'enableBiometrics': _config.enableBiometrics,
          'enableOAuth': _config.enableOAuth,
        },
      },
    );
  }

  @override
  Future<void> initialize() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      _status = ModuleInitStatus.validating;
      _log('Starting AuthModule initialization v$version', LogStatus.pending);

      // 1. Validar dependências
      final isValid = await _validateDependencies();
      if (!isValid) {
        throw ModuleException(
          'Dependency validation failed',
          module: moduleName,
        );
      }

      // 2. Registrar datasources
      _status = ModuleInitStatus.registeringDependencies;
      _registerDataSources();

      // 3. Registrar repositories
      _registerRepositories();

      // 4. Registrar use cases
      _registerUseCases();

      // 5. Registrar providers
      _status = ModuleInitStatus.registeringProviders;
      _registerProviders();

      // 6. Registrar rotas
      _status = ModuleInitStatus.registeringRoutes;
      _registerRoutes();

      // 7. Health check
      _status = ModuleInitStatus.healthCheck;
      final healthCheckPassed = await _performHealthCheck();
      
      if (!healthCheckPassed) {
        _logger.logWarning(
          'Health check failed but module will continue',
          module: moduleName,
        );
      }

      // 8. Finalizar
      _status = ModuleInitStatus.completed;
      stopwatch.stop();
      
      _log(
        'AuthModule initialized successfully in ${stopwatch.elapsedMilliseconds}ms',
        LogStatus.success,
      );

      // Logs consolidados
      _logger.log(
        level: LogLevel.info,
        message: 'AuthModule initialization complete',
        module: moduleName,
        metadata: {
          'duration': stopwatch.elapsedMilliseconds,
          'status': _status.toString(),
          'logs': _initializationLogs,
        },
      );

    } catch (e, stackTrace) {
      _status = ModuleInitStatus.failed;
      stopwatch.stop();
      
      _log(
        'AuthModule initialization failed after ${stopwatch.elapsedMilliseconds}ms: $e',
        LogStatus.error,
      );

      _logger.logError(
        'AuthModule initialization failed',
        error: e,
        stackTrace: stackTrace,
        module: moduleName,
        metadata: {
          'duration': stopwatch.elapsedMilliseconds,
          'status': _status.toString(),
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
      // Limpar providers se necessário
      // Nota: Riverpod gerencia automaticamente com autoDispose
      
      _log('AuthModule disposed', LogStatus.success);
    } catch (e, stackTrace) {
      _logger.logError(
        'Error disposing AuthModule',
        error: e,
        stackTrace: stackTrace,
        module: moduleName,
      );
    }
  }

  /// Getter para rotas (compatibilidade)
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

  /// Métricas do módulo
  Map<String, dynamic> getMetrics() {
    return {
      'status': _status.toString(),
      'isReady': isReady,
      'version': version,
      'routes': routes.length,
      'initializationLogs': _initializationLogs.length,
      'config': {
        'sessionTimeout': _config.sessionTimeout.inMinutes,
        'maxLoginAttempts': _config.maxLoginAttempts,
        'enableBiometrics': _config.enableBiometrics,
        'enableOAuth': _config.enableOAuth,
      },
    };
  }
}

/// Provider do módulo (singleton)
final authModuleProvider = Provider<AuthModule>((ref) {
  final config = ref.watch(authModuleConfigProvider);
  return AuthModule(config: config);
});

/// Extension para facilitar acesso
extension AuthModuleExtension on WidgetRef {
  AuthModule get authModule => read(authModuleProvider);
}
