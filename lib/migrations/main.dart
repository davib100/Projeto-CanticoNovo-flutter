// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
