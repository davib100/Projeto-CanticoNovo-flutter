// core/background/background_sync_state.dart

abstract class BackgroundSyncState {
  const BackgroundSyncState();
  
  factory BackgroundSyncState.idle() = BackgroundSyncStateIdle;
  factory BackgroundSyncState.syncing({
    required double progress,
    String? message,
  }) = BackgroundSyncStateSyncing;
  factory BackgroundSyncState.completed({
    required DateTime lastSyncTime,
    required Duration duration,
  }) = BackgroundSyncStateCompleted;
  factory BackgroundSyncState.error({
    required String error,
    DateTime? lastSyncTime,
  }) = BackgroundSyncStateError;
  factory BackgroundSyncState.paused() = BackgroundSyncStatePaused;
}

class BackgroundSyncStateIdle extends BackgroundSyncState {
  const BackgroundSyncStateIdle();
}

class BackgroundSyncStateSyncing extends BackgroundSyncState {
  final double progress;
  final String? message;
  
  const BackgroundSyncStateSyncing({
    required this.progress,
    this.message,
  });
}

class BackgroundSyncStateCompleted extends BackgroundSyncState {
  final DateTime lastSyncTime;
  final Duration duration;
  
  const BackgroundSyncStateCompleted({
    required this.lastSyncTime,
    required this.duration,
  });
}

class BackgroundSyncStateError extends BackgroundSyncState {
  final String error;
  final DateTime? lastSyncTime;
  
  const BackgroundSyncStateError({
    required this.error,
    this.lastSyncTime,
  });
}

class BackgroundSyncStatePaused extends BackgroundSyncState {
  const BackgroundSyncStatePaused();
}
