
// lib/core/sync/sync_models.dart

/// Erro de sincronização
class SyncError {
  final String message;
  final DateTime timestamp;
  final StackTrace? stackTrace;

  SyncError({required this.message, required this.timestamp, this.stackTrace});
}

/// Resultado de sincronização
class SyncResult {
  final int pushedCount;
  final int pulledCount;
  final int conflictsResolved;
  final List<SyncError> errors;
  final Duration duration;

  SyncResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.conflictsResolved,
    required this.errors,
    required this.duration,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccessful => errors.isEmpty;
  int get totalOperations => pushedCount + pulledCount;
}
