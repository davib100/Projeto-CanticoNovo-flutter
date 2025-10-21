// core/sync/sync_engine.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Precisamos para a compressão gzip

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;
import 'package:myapp/core/services/api_exception.dart'; // Importa a exceção customizada
import '../db/database_adapter.dart';
import '../observability/observability_service.dart';
//import '../queue/queued_operation.dart';
import '../services/api_client.dart';
import 'conflict_resolver.dart';
import '../../shared/models/sync_models.dart';
import 'sync_operation.dart';
import 'sync_state.dart';

/// Motor de sincronização offline-first com suporte a:
/// - Sincronização incremental (delta sync)
/// - Resolução de conflitos com múltiplas estratégias
/// - Optimistic locking com versionamento
/// - Retry com exponential backoff
/// - Transações atômicas
/// - Compressão e otimização de bandwidth
/// - Sync priorizado e cancelável
class SyncEngine {
  final DatabaseAdapter _db;
  final ApiClient _apiClient;
  final ObservabilityService _observabilityService;
  final Connectivity _connectivity;

  // Gerenciamento de estado
  final _syncStateController = StreamController<SyncState>.broadcast();
  SyncState _currentState = SyncState.idle();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isConnected = false;

  // Resolvedores de conflito
  final Map<String, ConflictResolver> _conflictResolvers = {};
  final ConflictResolutionStrategy _defaultStrategy =
      ConflictResolutionStrategy.lastWriteWins;

  // Configurações de sincronização
  final SyncConfiguration _config;

  // Controle de execução
  Timer? _periodicSyncTimer;
  Completer<void>? _syncCompleter;
  CancellationToken? _currentCancellationToken;

  // Métricas
  final _syncMetrics = SyncMetrics();

  bool get isHealthy => _isConnected;

  SyncEngine({
    required DatabaseAdapter db,
    required ApiClient apiClient,
    required ObservabilityService observabilityService,
    Connectivity? connectivity,
    SyncConfiguration? config,
  })  : _db = db,
        _apiClient = apiClient,
        _observabilityService = observabilityService,
        _connectivity = connectivity ?? Connectivity(),
        _config = config ?? SyncConfiguration.defaults();

  /// Stream de estados de sincronização
  Stream<SyncState> get stateStream => _syncStateController.stream;

  /// Estado atual da sincronização
  SyncState get currentState => _currentState;

  /// Métricas de sincronização
  SyncMetrics get metrics => _syncMetrics;

  /// Inicializa o sync engine
  Future<void> initialize() async {
    try {
      _observabilityService.addBreadcrumb('Initializing SyncEngine',
          category: 'sync');

      // Registrar estratégias de conflito padrão
      _registerDefaultConflictResolvers();

      // Carregar última sincronização
      final lastSync = await _loadLastSyncTime();
      _syncMetrics.lastSyncTime = lastSync;

      // Iniciar monitoramento de conectividade
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen(_updateConnectivityStatus);
      final initialConnectivity = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(initialConnectivity);

      // Configurar sync periódico se habilitado
      if (_config.enablePeriodicSync) {
        _startPeriodicSync();
      }

      _updateState(SyncState.idle());

      if (kDebugMode) {
        print('✅ SyncEngine initialized');
        print('   Last Sync: ${lastSync ?? "Never"}');
        print('   Periodic Sync: ${_config.enablePeriodicSync}');
        print('   Initial Connectivity: $_isConnected');
      }
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'sync_engine.initialize',
      );
      rethrow;
    }
  }

  void _updateConnectivityStatus(ConnectivityResult result) {
    _isConnected = result != ConnectivityResult.none;
    if (kDebugMode) {
      print('ℹ️ Connectivity status updated: $_isConnected');
    }
  }

  /// Sincroniza todas as entidades pendentes
  Future<SyncResult> sync({
    List<String>? entityTypes,
    SyncPriority priority = SyncPriority.normal,
    bool force = false,
  }) async {
    // Verificar se já está sincronizando
    if (_currentState is SyncStateSyncing && !force) {
      throw SyncInProgressException('Sync already in progress');
    }

    // Verificar conectividade
    if (!_isConnected && !force) {
      throw NoConnectivityException('No network connectivity');
    }

    _syncCompleter = Completer<void>();
    _currentCancellationToken = CancellationToken();

    final transaction = _observabilityService.startTransaction(
      'sync.full',
      'sync',
      data: {
        'entityTypes': entityTypes?.join(',') ?? 'all',
        'priority': priority.name,
      },
    );

    try {
      _updateState(SyncState.syncing(progress: 0.0));
      _syncMetrics.syncStarted();

      // 1. PUSH: Enviar operações locais pendentes para o servidor
      final pushResult = await _pushLocalChanges(
        entityTypes: entityTypes,
        priority: priority,
        cancellationToken: _currentCancellationToken!,
      );

      _updateState(
        SyncState.syncing(
          progress: 0.5,
          currentOperation: 'Receiving updates...',
        ),
      );

      // 2. PULL: Receber atualizações do servidor
      final pullResult = await _pullServerChanges(
        entityTypes: entityTypes,
        cancellationToken: _currentCancellationToken!,
      );

      // 3. Consolidar resultados
      final result = SyncResult(
        pushedCount: pushResult.operationsCount,
        pulledCount: pullResult.operationsCount,
        conflictsResolved:
            pushResult.conflictsCount + pullResult.conflictsCount,
        errors: [...pushResult.errors, ...pullResult.errors],
        duration: DateTime.now().difference(_syncMetrics.currentSyncStart!),
      );

      // 4. Atualizar timestamp de última sincronização
      await _saveLastSyncTime(DateTime.now());
      _syncMetrics.lastSyncTime = DateTime.now();

      // 5. Limpar operações sincronizadas
      await _cleanupSyncedOperations();

      _updateState(SyncState.completed(result: result));
      _syncMetrics.syncCompleted(result);

      await transaction.finish(status: const SpanStatus.ok());

      _observabilityService.addBreadcrumb(
        'Sync completed successfully',
        category: 'sync',
        data: {
          'pushed': result.pushedCount,
          'pulled': result.pulledCount,
          'conflicts': result.conflictsResolved,
          'duration_ms': result.duration.inMilliseconds,
        },
      );

      _syncCompleter?.complete();
      return result;
    } on CancelledException {
      _updateState(SyncState.cancelled());
      _syncMetrics.syncCancelled();

      await transaction.finish(status: const SpanStatus.cancelled());

      _syncCompleter?.completeError(SyncCancelledException());
      rethrow;
    } catch (e, stackTrace) {
      final error = SyncError(
        message: e.toString(),
        timestamp: DateTime.now(),
        stackTrace: stackTrace,
      );

      _updateState(SyncState.error(error: error));
      _syncMetrics.syncFailed(error);

      await _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'sync_engine.sync',
        extra: {
          'entityTypes': entityTypes?.join(','),
          'priority': priority.name,
        },
      );

      await transaction.finish(status: const SpanStatus.internalError());

      _syncCompleter?.completeError(e, stackTrace);
      rethrow;
    } finally {
      _currentCancellationToken = null;
      _syncCompleter = null;
    }
  }

  /// PUSH: Envia operações locais para o servidor
  Future<_SyncOperationResult> _pushLocalChanges({
    List<String>? entityTypes,
    required SyncPriority priority,
    required CancellationToken cancellationToken,
  }) async {
    final span = _observabilityService.startChild(
      'sync.push',
      description: 'Pushing local changes to server',
    );

    try {
      // 1. Carregar operações pendentes do banco
      final pendingOps = await _loadPendingOperations(
        entityTypes: entityTypes,
        priority: priority,
      );

      if (pendingOps.isEmpty) {
        await span?.finish(status: const SpanStatus.ok());
        return _SyncOperationResult.empty();
      }

      if (kDebugMode) {
        print('📤 Pushing ${pendingOps.length} operations to server');
      }

      int successCount = 0;
      int conflictCount = 0;
      final errors = <SyncError>[];

      // 2. Processar em batches para otimizar bandwidth
      final batches = _createBatches(pendingOps, _config.batchSize);

      for (int i = 0; i < batches.length; i++) {
        // Verificar cancelamento
        cancellationToken.throwIfCancelled();

        final batch = batches[i];

        try {
          // 3. Enviar batch para o servidor
          final response = await _sendBatchToServer(batch);
          final batchResponse = BatchResponse.fromJson(response);

          // 4. Processar resposta
          for (final opResult in batchResponse.results) {
            if (opResult.hasConflict) {
              final serverData = opResult.serverData;
              if (serverData != null) {
                final resolved = await _resolveConflict(
                  opResult.localOperation,
                  serverData,
                );

                if (resolved) {
                  conflictCount++;
                } else {
                  errors.add(
                    SyncError(
                      message:
                          'Unresolved conflict for ${opResult.localOperation.id}',
                      timestamp: DateTime.now(),
                    ),
                  );
                }
              } else {
                errors.add(
                  SyncError(
                    message:
                        'Conflict reported for ${opResult.localOperation.id} but no server data was provided.',
                    timestamp: DateTime.now(),
                  ),
                );
              }
            } else if (opResult.success) {
              await _markOperationAsSynced(opResult.localOperation);
              successCount++;
            } else {
              errors.add(
                SyncError(
                  message: opResult.error ?? 'Unknown error',
                  timestamp: DateTime.now(),
                ),
              );
            }
          }

          // Atualizar progresso
          final progress = 0.5 * ((i + 1) / batches.length);
          _updateState(
            SyncState.syncing(
              progress: progress,
              currentOperation: 'Pushing batch ${i + 1}/${batches.length}',
            ),
          );
        } on ApiException catch (e) {
          // Retry com exponential backoff
          final retried = await _retryWithBackoff(
            () => _sendBatchToServer(batch),
            maxRetries: _config.maxRetries,
          );

          if (retried == null) {
            errors.add(
              SyncError(
                message: 'Failed to push batch after retries: ${e.message}',
                timestamp: DateTime.now(),
              ),
            );
          }
        }
      }

      await span?.finish(status: const SpanStatus.ok());

      return _SyncOperationResult(
        operationsCount: successCount,
        conflictsCount: conflictCount,
        errors: errors,
      );
    } catch (e) {
      await span?.finish(status: const SpanStatus.internalError());
      rethrow;
    }
  }

  /// PULL: Recebe atualizações do servidor
  Future<_SyncOperationResult> _pullServerChanges({
    List<String>? entityTypes,
    required CancellationToken cancellationToken,
  }) async {
    final span = _observabilityService.startChild(
      'sync.pull',
      description: 'Pulling server changes',
    );

    try {
      // 1. Obter timestamp da última sincronização
      final lastSync = _syncMetrics.lastSyncTime;

      // 2. Solicitar apenas mudanças incrementais (delta sync)
      final response = await _apiClient.get(
        '/sync/pull',
        queryParams: {
          'since': lastSync?.toIso8601String() ?? '1970-01-01T00:00:00Z',
          'entities': entityTypes?.join(',') ?? 'all',
          'include_deleted': 'true',
        },
      );

      final serverOperations = (response['operations'] as List)
          .map((json) => ServerOperation.fromJson(json))
          .toList();

      if (serverOperations.isEmpty) {
        await span?.finish(status: const SpanStatus.ok());
        return _SyncOperationResult.empty();
      }

      if (kDebugMode) {
        print('📥 Pulling ${serverOperations.length} operations from server');
      }

      int appliedCount = 0;
      int conflictCount = 0;
      final errors = <SyncError>[];

      // 3. Aplicar operações do servidor localmente
      await _db.transaction((txn) async {
        for (int i = 0; i < serverOperations.length; i++) {
          cancellationToken.throwIfCancelled();

          final serverOp = serverOperations[i];

          try {
            // Verificar se há versão local
            final localVersion = await _getLocalVersion(
              serverOp.entityType,
              serverOp.entityId,
            );

            if (localVersion != null) {
              // Verificar conflito por versionamento
              if (serverOp.version <= localVersion.version) {
                // Versão local é mais recente - possível conflito
                final resolved = await _resolveConflict(
                  localVersion,
                  serverOp.data,
                );

                if (resolved) {
                  conflictCount++;
                } else {
                  errors.add(
                    SyncError(
                      message:
                          'Version conflict for ${serverOp.entityType}:${serverOp.entityId}',
                      timestamp: DateTime.now(),
                    ),
                  );
                  continue;
                }
              }
            }

            // Aplicar operação
            await _applyServerOperation(serverOp, txn);
            appliedCount++;

            // Atualizar progresso
            final progress = 0.5 + (0.5 * ((i + 1) / serverOperations.length));
            _updateState(
              SyncState.syncing(
                progress: progress,
                currentOperation:
                    'Applying ${i + 1}/${serverOperations.length}',
              ),
            );
          } catch (e) {
            errors.add(
              SyncError(
                message: 'Failed to apply operation: $e',
                timestamp: DateTime.now(),
              ),
            );
          }
        }
      });

      await span?.finish(status: const SpanStatus.ok());

      return _SyncOperationResult(
        operationsCount: appliedCount,
        conflictsCount: conflictCount,
        errors: errors,
      );
    } catch (e) {
      await span?.finish(status: const SpanStatus.internalError());
      rethrow;
    }
  }

  /// Resolve conflito entre versão local e servidor
  Future<bool> _resolveConflict(
    dynamic localData,
    Map<String, dynamic> serverData,
  ) async {
    final entityType = serverData['entity_type'] as String;

    // Obter resolvedor específico ou usar padrão
    final resolver =
        _conflictResolvers[entityType] ?? _conflictResolvers['default']!;

    final resolution = await resolver.resolve(
      ConflictContext(
        localData: localData,
        serverData: serverData,
        strategy: _defaultStrategy,
      ),
    );

    if (resolution.isResolved) {
      // Aplicar resolução
      await _applyResolution(resolution);

      // Log do conflito resolvido
      await _logConflict(
        entityType: entityType,
        strategy: resolution.strategy,
        winner: resolution.winner,
      );

      return true;
    }

    // Conflito não resolvido - requer intervenção manual
    if (resolution.requiresManualResolution) {
      await _queueForManualResolution(resolution);
    }

    return false;
  }

  /// Registra estratégias de resolução padrão
  void _registerDefaultConflictResolvers() {
    _conflictResolvers['default'] = DefaultConflictResolver();
    _conflictResolvers['songs'] = SongConflictResolver();
    _conflictResolvers['categories'] = CategoryConflictResolver();
  }

  /// Carrega operações pendentes do banco
  Future<List<SyncOperation>> _loadPendingOperations({
    List<String>? entityTypes,
    required SyncPriority priority,
  }) async {
    final whereConditions = <String>['status = ?'];
    final whereArgs = <dynamic>['pending'];

    if (entityTypes != null && entityTypes.isNotEmpty) {
      whereConditions.add(
        'entity_type IN (${List.filled(entityTypes.length, '?').join(',')})',
      );
      whereArgs.addAll(entityTypes);
    }

    final results = await _db.queryGeneric(
      'sync_log',
      where: whereConditions.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'priority DESC, created_at ASC',
      limit: _config.maxOperationsPerSync,
    );

    return results.map((json) => SyncOperation.fromJson(json)).toList();
  }

  /// Cria batches de operações
  List<List<SyncOperation>> _createBatches(
    List<SyncOperation> operations,
    int batchSize,
  ) {
    final batches = <List<SyncOperation>>[];

    for (int i = 0; i < operations.length; i += batchSize) {
      final end = (i + batchSize < operations.length)
          ? i + batchSize
          : operations.length;
      batches.add(operations.sublist(i, end));
    }

    return batches;
  }

  /// Envia batch para o servidor
  Future<Map<String, dynamic>> _sendBatchToServer(
      List<SyncOperation> batch) async {
    dynamic payload = batch.map((op) => op.toJson()).toList();
    bool isCompressed = false;

    if (_config.compressionEnabled) {
      payload = await _compressPayload(payload);
      isCompressed = true;
    }

    return await _apiClient.post('/sync/push', {
      'operations': payload,
      'compressed': isCompressed,
      'client_timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Retry com exponential backoff
  Future<T?> _retryWithBackoff<T>(
    Future<T> Function() operation, {
    required int maxRetries,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        if (attempt >= maxRetries) {
          return null;
        }

        // Exponential backoff: 2^attempt * 1000ms
        final delayMs = (1 << attempt) * 1000;

        if (kDebugMode) {
          print('⏳ Retry attempt $attempt/$maxRetries in ${delayMs}ms');
        }

        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return null;
  }

  /// Inicia sincronização periódica
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();

    _periodicSyncTimer = Timer.periodic(_config.syncInterval, (_) async {
      try {
        if (_isConnected) {
          await sync();
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️  Periodic sync failed: $e');
        }
      }
    });
  }

  /// Cancela sincronização em andamento
  Future<void> cancelSync() async {
    if (_currentState is! SyncStateSyncing) {
      return;
    }

    _currentCancellationToken?.cancel();
    await _syncCompleter?.future.catchError((_) {});
  }

  /// Pausa sincronização periódica
  void pausePeriodicSync() {
    _periodicSyncTimer?.cancel();
    _updateState(SyncState.paused());
  }

  /// Resume sincronização periódica
  void resumePeriodicSync() {
    if (_config.enablePeriodicSync) {
      _startPeriodicSync();
    }
    _updateState(SyncState.idle());
  }

  /// Obtém timestamp da última sincronização
  Future<DateTime?> getLastSyncTime() async {
    return _syncMetrics.lastSyncTime;
  }

  /// Carrega última sincronização do banco
  Future<DateTime?> _loadLastSyncTime() async {
    final result = await _db.queryGeneric(
      'sync_metadata',
      columns: ['last_sync_time'],
      where: 'key = ?',
      whereArgs: ['global_last_sync'],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final timestamp = result.first['last_sync_time'] as String?;
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  /// Salva timestamp da última sincronização
  Future<void> _saveLastSyncTime(DateTime timestamp) async {
    await _db.insertGeneric('sync_metadata', {
      'key': 'global_last_sync',
      'last_sync_time': timestamp.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Atualiza estado e notifica listeners
  void _updateState(SyncState newState) {
    if (_currentState == newState) return;
    _currentState = newState;
    _syncStateController.add(newState);
  }

  /// Limpa operações já sincronizadas
  Future<void> _cleanupSyncedOperations() async {
    final cutoffDate = DateTime.now().subtract(_config.syncRetentionPeriod);

    await _db.deleteGeneric('sync_log', 'status = ? AND synced_at < ?', [
      'synced',
      cutoffDate.toIso8601String(),
    ]);
  }

  /// Marca operação como sincronizada
  Future<void> _markOperationAsSynced(SyncOperation operation) async {
    await _db.updateGeneric(
      'sync_log',
      {'status': 'synced', 'synced_at': DateTime.now().toIso8601String()},
      'id = ?',
      [operation.id],
    );
  }

  /// Obtém versão local de uma entidade
  Future<LocalVersion?> _getLocalVersion(
    String entityType,
    String entityId,
  ) async {
    final results = await _db.queryGeneric(
      entityType,
      where: 'id = ?',
      whereArgs: [entityId],
      limit: 1,
    );

    if (results.isEmpty) return null;

    return LocalVersion.fromJson(results.first);
  }

  /// Aplica operação do servidor
  Future<void> _applyServerOperation(
    ServerOperation operation,
    dynamic transaction,
  ) async {
    switch (operation.operationType) {
      case 'insert':
      case 'update':
        await _db.insertGeneric(operation.entityType, operation.data,
            transaction: transaction);
        break;
      case 'delete':
        await _db.deleteGeneric(
            operation.entityType,
            'id = ?',
            [
              operation.entityId,
            ],
            transaction: transaction);
        break;
    }
  }

  /// Aplica resolução de conflito
  Future<void> _applyResolution(ConflictResolution resolution) async {
    final data = resolution.resolvedData;

    await _db.insertGeneric(data['entity_type'] as String, data);
  }

  /// Registra conflito no log
  Future<void> _logConflict({
    required String entityType,
    required ConflictResolutionStrategy strategy,
    required ConflictWinner winner,
  }) async {
    await _db.insertGeneric('conflict_log', {
      'entity_type': entityType,
      'strategy': strategy.name,
      'winner': winner.name,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Enfileira conflito para resolução manual
  Future<void> _queueForManualResolution(ConflictResolution resolution) async {
    await _db.insertGeneric('manual_conflict_queue', {
      'local_data': jsonEncode(resolution.context.localData),
      'server_data': jsonEncode(resolution.context.serverData),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Comprime payload para otimizar bandwidth
  Future<String> _compressPayload(dynamic payload) async {
    final json = jsonEncode(payload);
    final bytes = utf8.encode(json);
    final compressed = gzip.encode(bytes);
    return base64.encode(compressed);
  }

  /// Libera recursos
  Future<void> dispose() async {
    _periodicSyncTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _syncStateController.close();

    if (kDebugMode) {
      print('🔒 SyncEngine disposed');
    }
  }
}

// ══════════════════════════════════════════
// CLASSES DE SUPORTE
// ══════════════════════════════════════════

/// Configuração do sync engine
class SyncConfiguration {
  final bool enablePeriodicSync;
  final Duration syncInterval;
  final int batchSize;
  final int maxRetries;
  final int maxOperationsPerSync;
  final bool compressionEnabled;
  final Duration syncRetentionPeriod;

  const SyncConfiguration({
    required this.enablePeriodicSync,
    required this.syncInterval,
    required this.batchSize,
    required this.maxRetries,
    required this.maxOperationsPerSync,
    required this.compressionEnabled,
    required this.syncRetentionPeriod,
  });

  factory SyncConfiguration.defaults() {
    return const SyncConfiguration(
      enablePeriodicSync: false,
      syncInterval: Duration(minutes: 15),
      batchSize: 50,
      maxRetries: 3,
      maxOperationsPerSync: 1000,
      compressionEnabled: true,
      syncRetentionPeriod: Duration(days: 30),
    );
  }
}

/// Métricas de sincronização
class SyncMetrics {
  DateTime? lastSyncTime;
  DateTime? currentSyncStart;
  int totalSyncs = 0;
  int successfulSyncs = 0;
  int failedSyncs = 0;
  int cancelledSyncs = 0;
  int totalConflictsResolved = 0;
  Duration totalSyncTime = Duration.zero;

  void syncStarted() {
    currentSyncStart = DateTime.now();
    totalSyncs++;
  }

  void syncCompleted(SyncResult result) {
    successfulSyncs++;
    totalConflictsResolved += result.conflictsResolved;
    totalSyncTime += result.duration;
    currentSyncStart = null;
  }

  void syncFailed(SyncError error) {
    failedSyncs++;
    currentSyncStart = null;
  }

  void syncCancelled() {
    cancelledSyncs++;
    currentSyncStart = null;
  }

  double get successRate =>
      totalSyncs > 0 ? (successfulSyncs / totalSyncs) * 100 : 0.0;

  Duration get averageSyncDuration => successfulSyncs > 0
      ? Duration(milliseconds: totalSyncTime.inMilliseconds ~/ successfulSyncs)
      : Duration.zero;
}

/// Prioridade de sincronização
enum SyncPriority {
  critical(100),
  high(75),
  normal(50),
  low(25),
  background(0);

  final int value;
  const SyncPriority(this.value);
}

/// Token de cancelamento
class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw CancelledException();
    }
  }
}

/// Resultado interno de operação de sync
class _SyncOperationResult {
  final int operationsCount;
  final int conflictsCount;
  final List<SyncError> errors;

  _SyncOperationResult({
    required this.operationsCount,
    required this.conflictsCount,
    required this.errors,
  });

  factory _SyncOperationResult.empty() {
    return _SyncOperationResult(
      operationsCount: 0,
      conflictsCount: 0,
      errors: [],
    );
  }
}

// ══════════════════════════════════════════
// EXCEÇÕES
// ══════════════════════════════════════════

class SyncException implements Exception {
  final String message;
  SyncException(this.message);

  @override
  String toString() => 'SyncException: $message';
}

class SyncInProgressException extends SyncException {
  SyncInProgressException(super.message);
}

class NoConnectivityException extends SyncException {
  NoConnectivityException(super.message);
}

class SyncCancelledException extends SyncException {
  SyncCancelledException() : super('Sync was cancelled');
}

class CancelledException implements Exception {}
