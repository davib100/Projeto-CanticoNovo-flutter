// core/db/database_adapter.dart
import 'dart:async';

import '../queue/queued_operation.dart';

/// Enum para o algoritmo de conflito usado em operações de inserção.
/// Adicionado para corresponder ao uso em `auth_local_datasource.dart`.
enum ConflictAlgorithm {
  rollback,
  abort,
  fail,
  ignore,
  replace,
}

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

  /// Executa uma query.
  Future<List<Map<String, dynamic>>> query({
    required String table,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  });

  /// Insere um registro. Retorna o ID do registro inserido.
  Future<int> insert({
    required String table,
    required Map<String, dynamic> data,
    ConflictAlgorithm? conflictAlgorithm,
    dynamic transaction,
  });

  /// Atualiza registros. Retorna o número de linhas afetadas.
  Future<int> update({
    required String table,
    required Map<String, dynamic> data,
    String? where,
    List<dynamic>? whereArgs,
    dynamic transaction,
  });

  /// Deleta registros. Retorna o número de linhas afetadas.
  Future<int> delete({
    required String table,
    String? where,
    List<dynamic>? whereArgs,
    dynamic transaction,
  });

  /// Executa uma transação atômica.
  Future<void> transaction(Future<void> Function(dynamic txn) action);
}
