// core/background/background_sync.dart
class BackgroundSync {
  static const _syncTaskKey = 'com.canticonovo.sync';
  
  Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode
    );
  }
  
  Future<void> enableAutoSync() async {
    await Workmanager().registerPeriodicTask(
      _syncTaskKey,
      _syncTaskKey,
      frequency: Duration(hours: 6),
      constraints: Constraints(
        networkType: NetworkType.unmetered, // Apenas Wi-Fi
        requiresBatteryNotLow: true,
        requiresCharging: false,
      ),
    );
  }
  
  Future<void> syncNow() async {
    await Workmanager().registerOneOffTask(
      '${_syncTaskKey}_manual',
      _syncTaskKey,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final db = await openDatabase();
    final syncEngine = SyncEngine(db, ApiClient());
    
    try {
      await syncEngine.sync();
      return true;
    } catch (e) {
      return false;
    }
  });
}
