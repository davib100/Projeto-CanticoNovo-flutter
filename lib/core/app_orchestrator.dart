// core/app_orchestrator.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:myapp/core/db/database_adapter_impl.dart';

import 'module_registry.dart';
import 'queue/queue_manager.dart';
import 'db/database_adapter.dart';
import 'db/schema_registry.dart';
import 'sync/sync_engine.dart';
import 'background/background_sync.dart';
import 'services/api_client.dart';
import 'security/auth_service.dart';
import 'security/encryption_service.dart';
import 'security/token_manager.dart';
import 'observability/observability_service.dart';

/// Orquestrador central da aplicação
/// Gerencia toda a inicialização e ciclo de vida do app
class AppOrchestrator {
  static final AppOrchestrator _instance = AppOrchestrator._internal();
  factory AppOrchestrator() => _instance;
  AppOrchestrator._internal();

  // Core Services
  late final ModuleRegistry _registry;
  late final DatabaseAdapter _dbAdapter;
  late final QueueManager _queueManager;
  late final SyncEngine _syncEngine;
  late final BackgroundSync _backgroundSync;
  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final EncryptionService _encryptionService;
  late final ObservabilityService _observability;
  late final TokenManager _tokenManager;

  // Estado da inicialização
  bool _isInitialized = false;
  final List<InitializationStep> _initializationSteps = [];
  final _initializationCompleter = Completer<void>();

  // Getters públicos
  ModuleRegistry get registry => _registry;
  DatabaseAdapter get dbAdapter => _dbAdapter;
  QueueManager get queueManager => _queueManager;
  SyncEngine get syncEngine => _syncEngine;
  BackgroundSync get backgroundSync => _backgroundSync;
  ApiClient get apiClient => _apiClient;
  AuthService get authService => _authService;
  EncryptionService get encryptionService => _encryptionService;
  ObservabilityService get observability => _observability;
  TokenManager get tokenManager => _tokenManager;

  bool get isInitialized => _isInitialized;
  List<InitializationStep> get initializationSteps =>
      List.unmodifiable(_initializationSteps);

  /// Future que completa quando a inicialização termina
  Future<void> get initialized => _initializationCompleter.future;

  /// Inicializa toda a aplicação
  Future<void> initialize({
    String? sentryDsn,
    String? apiBaseUrl,
    String environment = 'production',
  }) async {
    if (_isInitialized) {
      if (kDebugMode) {
        developer.log('⚠️  AppOrchestrator already initialized');
      }
      return;
    }

    try {
      if (kDebugMode) {
        developer.log('🚀 ═══════════════════════════════════════');
        developer.log('🚀 Starting App Orchestrator Initialization');
        developer.log('🚀 ═══════════════════════════════════════');
      }

      final startTime = DateTime.now();

      // 1. Inicializar Observabilidade (primeiro de tudo)
      await _initializeObservability(sentryDsn, environment);

      // 2. Inicializar Sistema de Arquivos e Diretórios
      await _initializeFileSystem();

      // 3. Inicializar Segurança (Criptografia)
      await _initializeSecurity();

      // 4. Inicializar Banco de Dados
      await _initializeDatabase();

      // 5. Inicializar Token Manager
      await _initializeTokenManager();

      // 6. Inicializar API Client
      await _initializeApiClient(apiBaseUrl ?? _getDefaultApiUrl());

      // 7. Inicializar Autenticação
      await _initializeAuthentication();

      // 8. Inicializar Sync Engine (antes do QueueManager)
      await _initializeSyncEngine();

      // 9. Inicializar Queue Manager
      await _initializeQueueManager();

      // 10. Inicializar Background Sync
      await _initializeBackgroundSync();

      // 11. Inicializar Module Registry
      await _initializeModuleRegistry();

      // 12. Carregar e Inicializar Módulos
      await _registerAndInitializeModules();

      // 13. Verificar Conectividade
      await _checkConnectivity();

      // 14. Executar Health Check
      await _performHealthCheck();

      final duration = DateTime.now().difference(startTime);

      _isInitialized = true;
      _initializationCompleter.complete();

      if (kDebugMode) {
        developer.log('✅ ═══════════════════════════════════════');
        developer.log('✅ App Orchestrator Initialized Successfully');
        developer.log('✅ Total Time: ${duration.inMilliseconds}ms');
        developer.log('✅ ═══════════════════════════════════════');
        _printInitializationSummary();
      }

      // Enviar evento de boot completo para Sentry
      await _observability.captureMessage(
        'App initialized successfully',
        level: SentryLevel.info,
        extra: {
          'duration_ms': duration.inMilliseconds,
          'steps': _initializationSteps.length,
        },
      );
    } catch (e, stackTrace) {
      _initializationCompleter.completeError(e, stackTrace);

      if (kDebugMode) {
        developer.log('❌ ═══════════════════════════════════════');
        developer.log('❌ App Orchestrator Initialization FAILED');
        developer.log('❌ Error: $e');
        developer.log('❌ ═══════════════════════════════════════');
      }

      // Capturar erro crítico no Sentry
      if (_observability.isInitialized) {
        await _observability.captureException(
          e,
          stackTrace: stackTrace,
          endpoint: 'app.orchestrator.initialize',
          level: SentryLevel.fatal,
        );
      }

      rethrow;
    }
  }

  /// 1. Inicializar Observabilidade
  Future<void> _initializeObservability(String? dsn, String environment) async {
    final step = _startStep('Observability', '🔍');

    try {
      _observability = ObservabilityService();

      await _observability.initSentry(
        dsn: dsn,
        environment: environment,
        tracesSampleRate: kDebugMode ? 1.0 : 0.2,
        enableAutoPerformanceTracing: true,
        enableUserInteractionTracing: true,
        inAppIncludes: ['com.canticonovo'],
      );

      _completeStep(step, success: true);
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 2. Inicializar Sistema de Arquivos
  Future<void> _initializeFileSystem() async {
    final step = _startStep('File System', '📁');

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();

      if (kDebugMode) {
        developer.log('   App Directory: ${appDir.path}');
        developer.log('   Temp Directory: ${tempDir.path}');
      }

      _completeStep(step, success: true);
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 3. Inicializar Segurança
  Future<void> _initializeSecurity() async {
    final step = _startStep('Encryption Service', '🔐');

    try {
      _encryptionService = EncryptionService(const FlutterSecureStorage());

      await _encryptionService.initialize();

      _completeStep(step, success: true);
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 4. Inicializar Banco de Dados
  Future<void> _initializeDatabase() async {
    final step = _startStep('Database (Drift + SQLite)', '💾');

    try {
      _dbAdapter = DatabaseAdapterImpl();
      await _dbAdapter.init();

      // Validar schema
      final validationResult = SchemaRegistry.validateSchema();

      if (!validationResult.isValid) {
        throw DatabaseInitializationException(
          'Schema validation failed: ${validationResult.errors.join(", ")}',
        );
      }

      if (kDebugMode && validationResult.hasWarnings) {
        developer.log('   ⚠️  Schema warnings:');
        for (final warning in validationResult.warnings) {
          developer.log('      - $warning');
        }
      }

      // Verificar se há migrações pendentes
      const currentVersion = 1; //_dbAdapter.schemaVersion;
      if (kDebugMode) {
        developer.log('   Database version: $currentVersion');
      }

      _completeStep(
        step,
        success: true,
        metadata: {
          'version': currentVersion,
          'tables': SchemaRegistry.getAllTables().length,
        },
      );
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 5. Inicializar Token Manager
  Future<void> _initializeTokenManager() async {
    final step = _startStep('Token Manager', '🎟️');
    try {
      _tokenManager = TokenManager(
        secureStorage: const FlutterSecureStorage(),
        encryptionService: _encryptionService,
        observabilityService: _observability,
      );
      await _tokenManager.loadTokens();
      _completeStep(step, success: true);
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 6. Inicializar API Client
  Future<void> _initializeApiClient(String baseUrl) async {
    final step = _startStep('API Client', '🌐');

    try {
      _apiClient = ApiClient(
        baseUrl: baseUrl,
        client: http.Client(),
        tokenManager: _tokenManager,
        observabilityService: _observability,
      );

      if (kDebugMode) {
        developer.log('   Base URL: $baseUrl');
      }

      _completeStep(step, success: true, metadata: {'baseUrl': baseUrl});
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 7. Inicializar Autenticação
  Future<void> _initializeAuthentication() async {
    final step = _startStep('Authentication Service', '🔑');

    try {
      _authService = AuthService(
        apiClient: _apiClient,
        tokenManager: _tokenManager,
        googleSignIn: GoogleSignIn(scopes: ['email']),
      );

      // Verificar se há sessão válida
      final hasValidSession = await _authService.hasValidSession();

      if (kDebugMode) {
        developer.log('   Valid Session: ${hasValidSession ? "Yes" : "No"}');
      }

      _completeStep(
        step,
        success: true,
        metadata: {'hasSession': hasValidSession},
      );
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 8. Inicializar Sync Engine
  Future<void> _initializeSyncEngine() async {
    final step = _startStep('Sync Engine', '🔄');

    try {
      _syncEngine = SyncEngine(
        db: _dbAdapter,
        apiClient: _apiClient,
        observabilityService: _observability,
      );

      await _syncEngine.initialize();

      // Verificar última sincronização
      final lastSync = await _syncEngine.getLastSyncTime();

      if (kDebugMode && lastSync != null) {
        final timeSince = DateTime.now().difference(lastSync);
        developer.log('   Last Sync: ${timeSince.inMinutes} minutes ago');
      }

      _completeStep(
        step,
        success: true,
        metadata: {'lastSync': lastSync?.toIso8601String()},
      );
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 9. Inicializar Queue Manager
  Future<void> _initializeQueueManager() async {
    final step = _startStep('Queue Manager', '📋');

    try {
      _queueManager = QueueManager(db: _dbAdapter, syncEngine: _syncEngine);

      // Carregar operações pendentes
      final pendingCount = _queueManager.metrics.pendingOperations;

      if (kDebugMode) {
        developer.log('   Pending Operations: $pendingCount');
      }

      _completeStep(
        step,
        success: true,
        metadata: {'pendingOperations': pendingCount},
      );
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 10. Inicializar Background Sync
  Future<void> _initializeBackgroundSync() async {
    final step = _startStep('Background Sync', '⏰');

    try {
      _backgroundSync = BackgroundSync(
        queueManager: _queueManager,
        syncEngine: _syncEngine,
      );

      await _backgroundSync.initialize();

      _completeStep(step, success: true);
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 11. Inicializar Module Registry
  Future<void> _initializeModuleRegistry() async {
    final step = _startStep('Module Registry', '🧩');

    try {
      _registry = ModuleRegistry();

      // Adicionar lifecycle observer
      _registry.addLifecycleObserver(_ModuleLifecycleLogger(_observability));

      _completeStep(step, success: true);
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 12. Registrar e Inicializar Módulos
  Future<void> _registerAndInitializeModules() async {
    final step = _startStep('App Modules', '📦');

    try {
      // Os módulos serão registrados externamente via registerModules()
      // Aqui apenas inicializamos os que já foram registrados

      if (_registry.getRegisteredModules().isEmpty) {
        if (kDebugMode) {
          developer.log('   ⚠️  No modules registered yet');
        }
      } else {
        await _registry.initializeAll(
          db: _dbAdapter,
          queue: _queueManager,
          observability: _observability,
        );

        final initializedCount = _registry.getInitializedModules().length;
        final lazyCount = _registry.getLazyModules().length;

        if (kDebugMode) {
          developer.log('   Initialized Modules: $initializedCount');
          developer.log('   Lazy Modules: $lazyCount');
        }
      }

      _completeStep(step, success: true);
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// 13. Verificar Conectividade
  Future<void> _checkConnectivity() async {
    final step = _startStep('Network Connectivity', '📡');

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;

      if (kDebugMode) {
        developer.log('   Connection: ${connectivityResult.toString()}');
      }

      // Configurar contexto no Sentry
      await _observability.setContext('connectivity', {
        'type': connectivityResult.toString(),
        'connected': isConnected,
      });

      _completeStep(
        step,
        success: true,
        metadata: {
          'connected': isConnected,
          'type': connectivityResult.toString(),
        },
      );
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      // Não re-throw - conectividade não é crítica
    }
  }

  /// 14. Health Check
  Future<void> _performHealthCheck() async {
    final step = _startStep('Health Check', '🏥');

    try {
      final Map<String, bool> healthStatus = {
        'database': _dbAdapter.isHealthy,
        'queueManager': _queueManager.isHealthy,
        'syncEngine': _syncEngine.isHealthy,
        'moduleRegistry': _registry.isInitialized,
        'observability': _observability.isInitialized,
      };

      final isHealthy = healthStatus.values.every((v) => v);

      if (!isHealthy) {
        final failedComponents = healthStatus.entries
            .where((e) => !e.value)
            .map((e) => e.key)
            .join(", ");
        throw HealthCheckException('Health check failed: $failedComponents');
      }

      _completeStep(step, success: true, metadata: healthStatus);
    } catch (e) {
      _completeStep(step, success: false, error: e.toString());
      rethrow;
    }
  }

  /// Registra módulos externos
  void registerModules(List<AppModule> modules) {
    for (final module in modules) {
      _registry.register(module);
    }
  }

  /// Helper: Inicia um step de inicialização
  InitializationStep _startStep(String name, String icon) {
    final step = InitializationStep(
      name: name,
      icon: icon,
      startTime: DateTime.now(),
    );

    _initializationSteps.add(step);

    if (kDebugMode) {
      developer.log('$icon Starting: $name...');
    }

    _observability.addBreadcrumb(
      'Initializing: $name',
      category: 'initialization',
      level: SentryLevel.info,
    );

    return step;
  }

  /// Helper: Completa um step de inicialização
  void _completeStep(
    InitializationStep step, {
    required bool success,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    step.endTime = DateTime.now();
    step.success = success;
    step.error = error;
    step.metadata = metadata;

    final duration = step.duration?.inMilliseconds ?? 0;
    final status = success ? '✅' : '❌';

    if (kDebugMode) {
      developer.log('$status ${step.icon} ${step.name} - ${duration}ms');
      if (error != null) {
        developer.log('   Error: $error');
      }
      if (metadata != null && metadata.isNotEmpty) {
        metadata.forEach((key, value) {
          developer.log('   $key: $value');
        });
      }
    }
  }

  /// Imprime resumo da inicialização
  void _printInitializationSummary() {
    final totalDuration = _initializationSteps.fold<int>(
      0,
      (sum, step) => sum + (step.duration?.inMilliseconds ?? 0),
    );

    developer.log('\n📊 Initialization Summary:');
    developer.log('   Total Steps: ${_initializationSteps.length}');
    developer.log(
      '   Successful: ${_initializationSteps.where((s) => s.success).length}',
    );
    developer.log(
        '   Failed: ${_initializationSteps.where((s) => !s.success).length}');
    developer.log('   Total Duration: ${totalDuration}ms\n');
  }

  /// Obtém URL padrão da API
  String _getDefaultApiUrl() {
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.canticonovo.com',
    );
  }

  /// Destrói todo o orquestrador
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      _registry.disposeAll();
      await _backgroundSync.dispose();
      _queueManager.dispose();
      await _syncEngine.dispose();
      await _dbAdapter.close();
      _apiClient.dispose();
      await _observability.close();
      await _tokenManager.clear();

      _isInitialized = false;
      _initializationSteps.clear();

      if (kDebugMode) {
        developer.log('🔒 AppOrchestrator disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        developer.log('❌ Error disposing AppOrchestrator: $e');
      }
    }
  }
}

/// Representa um passo da inicialização
class InitializationStep {
  final String name;
  final String icon;
  final DateTime startTime;
  DateTime? endTime;
  bool success = false;
  String? error;
  Map<String, dynamic>? metadata;

  InitializationStep({
    required this.name,
    required this.icon,
    required this.startTime,
  });

  Duration? get duration => endTime?.difference(startTime);

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon': icon,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration_ms': duration?.inMilliseconds,
      'success': success,
      'error': error,
      'metadata': metadata,
    };
  }
}

/// Observer interno para logging de ciclo de vida dos módulos
class _ModuleLifecycleLogger extends ModuleLifecycleObserver {
  final ObservabilityService _observability;

  _ModuleLifecycleLogger(this._observability);

  @override
  void onModuleInitializing(AppModule module) {
    _observability.addBreadcrumb(
      'Initializing module: ${module.name}',
      category: 'module.lifecycle',
      level: SentryLevel.info,
    );
  }

  @override
  void onModuleInitialized(AppModule module) {
    _observability.addBreadcrumb(
      'Module initialized: ${module.name}',
      category: 'module.lifecycle',
      level: SentryLevel.info,
    );
  }

  @override
  void onModuleError(AppModule module, dynamic error, StackTrace stackTrace) {
    _observability.captureException(
      error,
      stackTrace: stackTrace,
      endpoint: 'module.initialization',
      extra: {'module': module.name},
      level: SentryLevel.error,
    );
  }
}

// ══════════════════════════════════════════
// EXCEÇÕES CUSTOMIZADAS
// ══════════════════════════════════════════

class DatabaseInitializationException implements Exception {
  final String message;
  DatabaseInitializationException(this.message);

  @override
  String toString() => 'DatabaseInitializationException: $message';
}

class HealthCheckException implements Exception {
  final String message;
  HealthCheckException(this.message);

  @override
  String toString() => 'HealthCheckException: $message';
}
