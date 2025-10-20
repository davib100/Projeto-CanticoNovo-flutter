import 'dart:async';
import 'dart:io';

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

  /// Inicializa o banco de dados, aplicando migrações se necessário.
  Future<void> init();

  /// Fecha a conexão com o banco de dados.
  Future<void> close();

  /// Executa uma lista de migrações de schema em ordem.
  Future<void> executeMigrations(Map<int, String> migrations);

  /// Busca um valor do cache pelo sua chave.
  Future<T?> getCached<T>(String key);

  /// Adiciona ou atualiza um valor no cache com um TTL opcional.
  Future<void> setCached<T>(String key, T value, {Duration? ttl});

  /// Remove um valor do cache pela sua chave.
  Future<void> invalidateCache(String key);

  /// Exporta o banco de dados para um arquivo.
  Future<File> export();

  /// Restaura o banco de dados a partir de um backup.
  Future<void> restore(List<int> data);

  /// Executa um bloco de código dentro de uma transação atômica.
  ///
  /// Se o bloco de código lançar uma exceção, a transação será revertida (rollback).
  /// Caso contrário, as alterações serão salvas (commit).
  /// O parâmetro [txn] é um objeto de transação específico da implementação do banco.
  Future<void> transaction(Future<void> Function(dynamic txn) action);

  // Métodos genéricos para manipulação de dados
  Future<void> insertGeneric(String table, Map<String, dynamic> data, {dynamic transaction});
  Future<void> updateGeneric(String table, Map<String, dynamic> data, String where, List<dynamic> whereArgs, {dynamic transaction});
  Future<void> deleteGeneric(String table, String where, List<dynamic> whereArgs, {dynamic transaction});
  Future<List<Map<String, dynamic>>> queryGeneric(String table, {List<String>? columns, String? where, List<dynamic>? whereArgs, String? orderBy, int? limit});
  Future<void> customStatement(String statement, {dynamic transaction});
}
