// core/sync/sync_engine.dart
class SyncEngine {
  final DatabaseAdapter _db;
  final ApiClient _apiClient;
  
  Future<void> sync() async {
    final pendingOperations = await _getPendingSync();
    
    for (final op in pendingOperations) {
      try {
        final response = await _apiClient.post('/sync/push', {
          'operations': [op.toJson()]
        });
        
        if (response.hasConflict) {
          await _handleConflict(op, response.serverData);
        } else {
          await _markAsSynced(op.id);
        }
      } catch (e) {
        await _markAsError(op.id, e.toString());
      }
    }
    
    await _pullFromServer();
  }
  
  Future<void> _handleConflict(
    SyncOperation local, 
    Map<String, dynamic> server
  ) async {
    final strategy = ConflictResolutionStrategy.lastWriteWins;
    
    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        final localTimestamp = local.updatedAt;
        final serverTimestamp = DateTime.parse(server['updated_at']);
        
        if (serverTimestamp.isAfter(localTimestamp)) {
          await _applyServerData(server);
        } else {
          await _forcePush(local);
        }
        break;
        
      case ConflictResolutionStrategy.manual:
        await _showConflictDialog(local, server);
        break;
    }
  }
}
