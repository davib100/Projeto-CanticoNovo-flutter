import '../queue/queued_operation.dart';

// Adapta a comunicação com o banco de dados
abstract class DatabaseAdapter {
  Future<void> saveOperation(QueuedOperation operation);
  Future<void> deleteOperation(String id);
  Future<void> updateOperation(QueuedOperation operation);
  Future<List<QueuedOperation>> getPendingOperations();
  Future<void> clearAllOperations();
  Future<void> init();
  Future<void> close();

  // Métodos para o schema
  Future<void> executeMigrations(Map<int, String> migrations);

  // Métodos para o cache
  Future<T?> getCached<T>(String key);
  Future<void> setCached<T>(String key, T value, {Duration? ttl});
  Future<void> invalidateCache(String key);
}
