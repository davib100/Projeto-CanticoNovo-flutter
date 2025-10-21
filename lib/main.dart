// main.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Core
import '../core/app_orchestrator.dart';
import '../core/module_registry.dart';
import '../core/queue/queue_manager.dart';
import '../core/queue/queue_config.dart';
import '../core/db/database_adapter.dart';
import '../core/db/database_config.dart';
import '../core/sync/sync_engine.dart';
//import '../core/sync/sync_config.dart';
import '../core/background/background_sync.dart';
import '../core/background/background_sync_config.dart';
import '../core/services/api_client.dart';
import '../core/security/auth_service.dart';
import '../core/security/encryption_service.dart';
import '../core/security/token_manager.dart';
import '../core/observability/observability_service.dart';

// Modules
import '../modules/auth/auth_module.dart';
import '../modules/library/library_module.dart';
import '../modules/lyrics/lyrics_module.dart';
import '../modules/quick_access/quickaccess_module.dart';
import '../modules/search/search_module.dart';
import '../modules/settings/settings_module.dart';
import '../modules/karaoke/karaoke_module.dart';

// Config
//import '../config/environment.dart';
//import '../config/firebase_options.dart';

// UI
//import '../ui/app.dart';
//import '../ui/splash/splash_screen.dart';
//import '../ui/error/error_screen.dart';

/// Entry point da aplicação Cântico Novo
///
/// Inicialização sequencial e otimizada de todos os componentes:
/// 1. Flutter Framework bindings
/// 2. Error handling global
/// 3. Firebase
/// 4. Sentry (Observability)
/// 5. App Orchestrator (Core Services)
/// 6. Module Registry & Registration
/// 7. Dependency Injection (Riverpod)
/// 8. UI Rendering
Future<void> main() async {
  // ══════════════════════════════════════════
  // FASE 1: INICIALIZAÇÃO DO FRAMEWORK
  // ══════════════════════════════════════════

  WidgetsFlutterBinding.ensureInitialized();

  // Lock de orientação (portrait apenas)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configuração da UI do sistema
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ══════════════════════════════════════════
  // FASE 2: CONFIGURAÇÃO DE ERROR HANDLING
  // ══════════════════════════════════════════

  // Inicializar Observability Service primeiro (para capturar erros de boot)
  final observability = ObservabilityService();

  await observability.initSentry(
    dsn: Environment.sentryDsn,
    environment: Environment.current.name,
    tracesSampleRate: Environment.isProduction ? 0.2 : 1.0,
    profilesSampleRate: Environment.isProduction ? 0.1 : 1.0,
    enableAutoPerformanceTracing: true,
    enableUserInteractionTracing: true,
    attachStacktrace: true,
    inAppIncludes: ['com.canticonovo'],
  );

  // Configurar error handlers do Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    observability.captureException(
      details.exception,
      stackTrace: details.stack,
      endpoint: 'flutter.error',
      level: SentryLevel.error,
      extra: {
        'library': details.library,
        'context': details.context?.toString(),
        'silent': details.silent,
      },
    );
  };

  // Capturar erros assíncronos não tratados
  PlatformDispatcher.instance.onError = (error, stack) {
    observability.captureException(
      error,
      stackTrace: stack,
      endpoint: 'platform.error',
      level: SentryLevel.fatal,
    );
    return true;
  };

  // ══════════════════════════════════════════
  // FASE 3: ZONA PROTEGIDA DE EXECUÇÃO
  // ══════════════════════════════════════════

  runZonedGuarded<Future<void>>(
    () async {
      try {
        // ══════════════════════════════════════════
        // FASE 4: INICIALIZAÇÃO DO FIREBASE
        // ══════════════════════════════════════════

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        observability.addBreadcrumb(
          'Firebase initialized',
          category: 'initialization',
          level: SentryLevel.info,
        );

        // ══════════════════════════════════════════
        // FASE 5: INICIALIZAÇÃO DOS CORE SERVICES
        // ══════════════════════════════════════════

        // Secure Storage (cross-platform)
        const secureStorage = FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

        // Encryption Service
        final encryptionService = EncryptionService(
          secureStorage,
          config: EncryptionConfig.defaults(),
        );
        await encryptionService.initialize();

        // Token Manager
        final tokenManager = TokenManager(
          secureStorage: secureStorage,
          encryptionService: encryptionService,
          observability: observability,
          config: TokenManagerConfig.defaults(),
        );

        // Database Adapter
        final dbAdapter = DatabaseAdapter(
          config: Environment.isProduction
              ? DatabaseConfig.defaults()
              : DatabaseConfig.defaults().copyWith(
                  logStatements: true,
                  slowQueryThreshold: 50,
                ),
        );

        // API Client (será inicializado pelo orchestrator)
        ApiClient? apiClient;

        // Auth Service
        AuthService? authService;

        // Queue Manager
        final queueManager = QueueManager(
          db: dbAdapter,
          syncEngine: null, // Será definido depois
          observability: observability,
          config: Environment.isProduction
              ? QueueConfig.defaults()
              : QueueConfig.defaults().copyWith(
                  maxWorkers: 1,
                  enableBatching: false,
                ),
        );

        // Sync Engine
        final syncEngine = SyncEngine(
          db: dbAdapter,
          apiClient: null, // Será definido depois
          observability: observability,
          config: SyncConfiguration.defaults(),
        );

        // Background Sync
        final backgroundSync = BackgroundSync(
          queueManager: queueManager,
          syncEngine: syncEngine,
        );

        // ══════════════════════════════════════════
        // FASE 6: APP ORCHESTRATOR
        // ══════════════════════════════════════════

        final orchestrator = AppOrchestrator();

        // ══════════════════════════════════════════
        // FASE 7: MÓDULOS - REGISTRO COM PRIORIDADES
        // ══════════════════════════════════════════

        orchestrator.registerModules([
          // Módulos críticos (inicializam primeiro)
          AuthModule(priority: ModulePriority.critical),

          // Módulos de alta prioridade
          LibraryModule(priority: ModulePriority.high),
          LyricsModule(priority: ModulePriority.high),

          // Módulos normais
          QuickAccessModule(priority: ModulePriority.normal),
          SearchModule(priority: ModulePriority.normal),

          // Módulos de baixa prioridade (lazy load)
          SettingsModule(
            priority: ModulePriority.low,
            lazy: true,
          ),
          KaraokeModule(
            priority: ModulePriority.low,
            lazy: true,
          ),
        ]);

        // ══════════════════════════════════════════
        // FASE 8: INICIALIZAÇÃO ORQUESTRADA
        // ══════════════════════════════════════════

        await orchestrator.initialize(
          sentryDsn: Environment.sentryDsn,
          apiBaseUrl: Environment.apiBaseUrl,
          environment: Environment.current.name,
        );

        // ══════════════════════════════════════════
        // FASE 9: PROVIDERS RIVERPOD
        // ══════════════════════════════════════════

        final container = ProviderContainer(
          overrides: [
            // Core Services
            orchestratorProvider.overrideWithValue(orchestrator),
            databaseProvider.overrideWithValue(dbAdapter),
            queueManagerProvider.overrideWithValue(queueManager),
            syncEngineProvider.overrideWithValue(syncEngine),
            backgroundSyncProvider.overrideWithValue(backgroundSync),
            observabilityProvider.overrideWithValue(observability),
            encryptionServiceProvider.overrideWithValue(encryptionService),
            tokenManagerProvider.overrideWithValue(tokenManager),

            // Services (criados pelo orchestrator)
            apiClientProvider.overrideWithValue(orchestrator.apiClient),
            authServiceProvider.overrideWithValue(orchestrator.authService),

            // Module Registry
            moduleRegistryProvider.overrideWithValue(orchestrator.registry),
          ],
          observers: [
            // Logger de providers em debug
            if (kDebugMode) _ProviderLogger(),
          ],
        );

        // ══════════════════════════════════════════
        // FASE 10: RENDERIZAÇÃO DA UI
        // ══════════════════════════════════════════

        runApp(
          UncontrolledProviderScope(
            container: container,
            child: const CanticoNovoApp(),
          ),
        );

        // ══════════════════════════════════════════
        // FASE 11: PÓS-INICIALIZAÇÃO
        // ══════════════════════════════════════════

        // Inicializar módulos lazy após 2 segundos (não bloqueante)
        Future.delayed(const Duration(seconds: 2), () {
          orchestrator.registry.initializeLazy<SettingsModule>();
        });

        // Log de sucesso
        await observability.captureMessage(
          'App initialized successfully',
          level: SentryLevel.info,
          extra: {
            'duration_ms': orchestrator.initializationSteps.fold<int>(
                0, (sum, step) => sum + (step.duration?.inMilliseconds ?? 0)),
            'modules': orchestrator.registry.getInitializedModules().length,
            'platform': Platform.operatingSystem,
          },
        );

        if (kDebugMode) {
          debugPrint('');
          debugPrint('═══════════════════════════════════════');
          debugPrint('    🎵 CÂNTICO NOVO INITIALIZED 🎵');
          debugPrint('═══════════════════════════════════════');
          debugPrint('Environment: ${Environment.current.name}');
          debugPrint('Platform: ${Platform.operatingSystem}');
          debugPrint(
              'Modules: ${orchestrator.registry.getInitializedModules().length}');
          debugPrint('═══════════════════════════════════════');
          debugPrint('');
        }
      } catch (error, stackTrace) {
        // Erro crítico durante inicialização
        await observability.captureException(
          error,
          stackTrace: stackTrace,
          endpoint: 'app.initialization',
          level: SentryLevel.fatal,
        );

        // Mostrar tela de erro fatal
        runApp(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: FatalErrorScreen(
              error: error,
              stackTrace: stackTrace,
              onRetry: () {
                // Reiniciar app
                main();
              },
            ),
          ),
        );
      }
    },
    (error, stackTrace) {
      // Última linha de defesa - erro não capturado
      observability.captureException(
        error,
        stackTrace: stackTrace,
        endpoint: 'zone.error',
        level: SentryLevel.fatal,
      );

      if (kDebugMode) {
        debugPrint('═══════════════════════════════════════');
        debugPrint('💥 UNCAUGHT ERROR');
        debugPrint('═══════════════════════════════════════');
        debugPrint('Error: $error');
        debugPrint('Stack: $stackTrace');
        debugPrint('═══════════════════════════════════════');
      }
    },
  );
}

// ══════════════════════════════════════════
// PROVIDERS RIVERPOD
// ══════════════════════════════════════════

final orchestratorProvider = Provider<AppOrchestrator>((ref) {
  throw UnimplementedError('Orchestrator must be overridden');
});

final databaseProvider = Provider<DatabaseAdapter>((ref) {
  throw UnimplementedError('Database must be overridden');
});

final queueManagerProvider = Provider<QueueManager>((ref) {
  throw UnimplementedError('QueueManager must be overridden');
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  throw UnimplementedError('SyncEngine must be overridden');
});

final backgroundSyncProvider = Provider<BackgroundSync>((ref) {
  throw UnimplementedError('BackgroundSync must be overridden');
});

final observabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Observability must be overridden');
});

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  throw UnimplementedError('EncryptionService must be overridden');
});

final tokenManagerProvider = Provider<TokenManager>((ref) {
  throw UnimplementedError('TokenManager must be overridden');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('ApiClient must be overridden');
});

final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('AuthService must be overridden');
});

final moduleRegistryProvider = Provider<ModuleRegistry>((ref) {
  throw UnimplementedError('ModuleRegistry must be overridden');
});

// Provider para status de autenticação (reactive)
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateStream;
});

// Provider para status de sincronização (reactive)
final syncStateProvider = StreamProvider<SyncState>((ref) {
  final syncEngine = ref.watch(syncEngineProvider);
  return syncEngine.stateStream;
});

// Provider para status da fila (reactive)
final queueStateProvider = StreamProvider<QueueState>((ref) {
  final queueManager = ref.watch(queueManagerProvider);
  return queueManager.stateStream;
});

// ══════════════════════════════════════════
// PROVIDER LOGGER (DEBUG)
// ══════════════════════════════════════════

class _ProviderLogger extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderBase provider,
    Object? value,
    ProviderContainer container,
  ) {
    debugPrint('🔷 Provider added: ${provider.name ?? provider.runtimeType}');
  }

  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    debugPrint('🔄 Provider updated: ${provider.name ?? provider.runtimeType}');
  }

  @override
  void didDisposeProvider(
    ProviderBase provider,
    ProviderContainer container,
  ) {
    debugPrint(
        '🗑️  Provider disposed: ${provider.name ?? provider.runtimeType}');
  }

  @override
  void providerDidFail(
    ProviderBase provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    debugPrint('❌ Provider failed: ${provider.name ?? provider.runtimeType}');
    debugPrint('   Error: $error');
  }
}

// ══════════════════════════════════════════
// ENVIRONMENT CONFIG
// ══════════════════════════════════════════

class Environment {
  static const String _envKey =
      String.fromEnvironment('ENV', defaultValue: 'development');

  static EnvironmentType get current {
    switch (_envKey) {
      case 'production':
        return EnvironmentType.production;
      case 'staging':
        return EnvironmentType.staging;
      default:
        return EnvironmentType.development;
    }
  }

  static bool get isProduction => current == EnvironmentType.production;
  static bool get isStaging => current == EnvironmentType.staging;
  static bool get isDevelopment => current == EnvironmentType.development;

  static String get apiBaseUrl {
    switch (current) {
      case EnvironmentType.production:
        return 'https://api.canticonovo.com';
      case EnvironmentType.staging:
        return 'https://api-staging.canticonovo.com';
      case EnvironmentType.development:
        return 'http://localhost:3000';
    }
  }

  static String get sentryDsn {
    return const String.fromEnvironment(
      'SENTRY_DSN',
      defaultValue: '',
    );
  }
}

enum EnvironmentType {
  development,
  staging,
  production,
}

// ══════════════════════════════════════════
// FATAL ERROR SCREEN
// ══════════════════════════════════════════

class FatalErrorScreen extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  const FatalErrorScreen({
    Key? key,
    required this.error,
    this.stackTrace,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Erro Fatal',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ocorreu um erro crítico durante a inicialização do aplicativo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Error: $error',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          if (stackTrace != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              stackTrace.toString(),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
