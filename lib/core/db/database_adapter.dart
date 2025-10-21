// core/db/database_adapter.dart
import 'dart:async';

import '../queue/queued_operation.dart';

/// Adapta a comunicação com o banco de dados, abstraindo a implementação subjacente.
///
/// Esta classe define o contrato para todas as operações de banco de dados, incluindo:
/// - Gerenciamento de operações em fila para sincronização offline.
/// - Execução de migrações de schema.
/// - Cache de dados com tempo de vida útil (TTL).
/// - Backup e restauração do banco de dados.
/// - Execução de transações atômicas.
abstract class DatabaseAdapter {
  /// Indica se o banco de dados está saudável e conectado.
  bool get isHealthy;

  /// Inicializa o banco de dados.
  Future<void> init();

  /// Fecha a conexão com o banco de dados.
  Future<void> close();

  /// Exporta o banco de dados e retorna o caminho para o arquivo exportado.
  Future<String> export();

  /// Restaura o banco de dados a partir de um arquivo.
  Future<void> restore(String path);

  /// Salva uma nova operação na fila de sincronização.
  Future<void> saveOperation(QueuedOperation operation);

  /// Remove uma operação da fila pelo seu ID.
  Future<void> deleteOperation(String id);

  /// Atualiza uma operação existente na fila.
  Future<void> updateOperation(QueuedOperation operation);

  /// Retorna todas as operações pendentes de sincronização.
  Future<List<QueuedOperation>> getPendingOperations();

  /// Limpa todas as operações da fila.
  Future<void> clearAllOperations();

  /// Executa uma query genérica.
  Future<List<Map<String, dynamic>>> queryGeneric(
    String table, {
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  });

  /// Insere um registro genérico.
  Future<void> insertGeneric(
    String table,
    Map<String, dynamic> data, {
    dynamic transaction,
  });

  /// Atualiza um registro genérico.
  Future<void> updateGeneric(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs, {
    dynamic transaction,
  });

  /// Deleta um registro genérico.
  Future<void> deleteGeneric(
    String table,
    String where,
    List<dynamic> whereArgs, {
    dynamic transaction,
  });

  /// Executa uma transação atômica.
  Future<void> transaction(Future<void> Function(dynamic txn) action);
}
