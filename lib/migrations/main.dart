import 'package:firebase_core/firebase_core.dart';

// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final orchestrator = AppOrchestrator(
    registry: ModuleRegistry(),
    queueManager: QueueManager(),
    dbAdapter: DatabaseAdapter(),
    syncEngine: SyncEngine(),
    observability: ObservabilityService(),
  );

  // Registrar módulos
  orchestrator.registry
    ..register(AuthModule())
    ..register(LibraryModule())
    ..register(LyricsModule())
    ..register(QuickAccessModule())
    ..register(SearchModule())
    ..register(SettingsModule())
    ..register(KaraokeModule());

  await orchestrator.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: orchestrator),
        Provider.value(value: orchestrator.queueManager),
        Provider.value(value: orchestrator.dbAdapter),
      ],
      child: CanticoNovoApp(),
    ),
  );
}

// Inicialização no main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final observability = ObservabilityService();

  // Inicializar Sentry
  await observability.initSentry(
    dsn: 'https://your-dsn@sentry.io/project-id',
    environment: kDebugMode ? 'development' : 'production',
    tracesSampleRate: 1.0,
    enableAutoPerformanceTracing: true,
  );

  // Configurar tratamento de erros Flutter
  FlutterError.onError = (FlutterErrorDetails details) async {
    await observability.captureException(
      details.exception,
      stackTrace: details.stack,
      extra: {
        'library': details.library,
        'context': details.context?.toString(),
      },
    );
    FlutterError.presentError(details);
  };

  // Capturar erros assíncronos
  PlatformDispatcher.instance.onError = (error, stack) {
    observability.captureException(error, stackTrace: stack);
    return true;
  };

  // Executar app dentro de zona protegida
  runZonedGuarded(
    () {
      runApp(MyApp());
    },
    (error, stackTrace) {
      observability.captureException(error, stackTrace: stackTrace);
    },
  );
}

// Uso em um módulo
class LibraryModule extends AppModule {
  final ObservabilityService _observability;

  LibraryModule(this._observability);

  Future<void> createBook(String title) async {
    // Iniciar transação
    final transaction = _observability.startTransaction(
      'library.createBook',
      'db.operation',
      description: 'Creating new book: $title',
    );

    try {
      // Adicionar breadcrumb
      _observability.addBreadcrumb(
        'Creating book',
        category: 'library',
        data: {'title': title},
      );

      // Operação
      await _repository.createBook(title);

      // Registrar métrica
      _observability.recordMetric(
        'book.created',
        1,
        unit: SentryMeasurementUnit.none,
      );

      await transaction.finish(status: SpanStatus.ok());
    } catch (e, stackTrace) {
      // Capturar exceção
      await _observability.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'library.createBook',
        extra: {'title': title},
      );

      await transaction.finish(status: SpanStatus.internalError());
      rethrow;
    }
  }
}
