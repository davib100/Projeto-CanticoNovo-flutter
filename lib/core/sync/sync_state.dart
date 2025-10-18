// core/sync/sync_state.dart

/// Estados possíveis do Sync Engine
abstract class SyncState {
  const SyncState();

  factory SyncState.idle() = SyncStateIdle;
  factory SyncState.syncing({
    required double progress,
    String? currentOperation,
  }) = SyncStateSyncing;
  factory SyncState.completed({required SyncResult result}) =
      SyncStateCompleted;
  factory SyncState.error({required SyncError error}) = SyncStateError;
  factory SyncState.cancelled() = SyncStateCancelled;
  factory SyncState.paused() = SyncStatePaused;
}

class SyncStateIdle extends SyncState {
  const SyncStateIdle();
}

class SyncStateSyncing extends SyncState {
  final double progress;
  final String? currentOperation;

  const SyncStateSyncing({required this.progress, this.currentOperation});
}

class SyncStateCompleted extends SyncState {
  final SyncResult result;

  const SyncStateCompleted({required this.result});
}

class SyncStateError extends SyncState {
  final SyncError error;

  const SyncStateError({required this.error});
}

class SyncStateCancelled extends SyncState {
  const SyncStateCancelled();
}

class SyncStatePaused extends SyncState {
  const SyncStatePaused();
}
