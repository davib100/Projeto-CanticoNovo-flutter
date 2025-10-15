// core/queue/queue_manager.dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

import '../db/database_adapter.dart';
import '../sync/sync_engine.dart';
import '../observability/observability_service.dart';
import 'queued_operation.dart';
import 'queue_config.dart';
import 'circuit_breaker.dart';
import 'rate_limiter.dart';

/// Gerenciador de filas avançado com:
/// - Persistência dual (memória + DB)
/// - Priorização multi-nível
/// - Retry strategies configuráveis
/// - Circuit breaker por operação
/// - Dead letter queue
/// - Rate limiting
/// - Deduplicação automática
/// - Batch processing
/// - Concurrent workers
/// - Observabilidade completa
class QueueManager {
  final DatabaseAdapter _db;
  final SyncEngine _syncEngine;
  final ObservabilityService _observability;
  final QueueConfig _config;
  
  // Filas por prioridade
  final _priorityQueues = <QueuePriority, Queue<QueuedOperation>>{};
  
  // Dead Letter Queue
  final _deadLetterQueue = Queue<QueuedOperation>();
  
  // Controle de processamento
  bool _isProcessing = false;
  bool _isPaused = false;
  final List<Worker> _workers = [];
  
  // Circuit breakers por módulo
  final Map<String, CircuitBreaker> _circuitBreakers = {};
  
  // Rate limiters por módulo
  final Map<String, RateLimiter> _rateLimiters = {};
  
  // Deduplicação
  final Map<String, DateTime> _operationHashes = {};
  
  // Estado e métricas
  final _stateController = StreamController<QueueState>.broadcast();
  final _metrics = QueueMetrics();
  
  // Timers
  Timer? _persistenceTimer;
  Timer? _batchFlushTimer;
  Timer? _cleanupTimer;
  
  // Batch buffer
  final Map<String, List<QueuedOperation>> _batchBuffers = {};
  
  QueueManager({
    required DatabaseAdapter db,
    required SyncEngine syncEngine,
    ObservabilityService? observability,
    QueueConfig? config,
  })  : _db = db,
        _syncEngine = syncEngine,
        _observability = observability ?? ObservabilityService(),
        _config = config ?? QueueConfig.defaults() {
    // Inicializar filas de prioridade
    for (final priority in QueuePriority.values) {
      _priorityQueues[priority] = Queue<QueuedOperation>();
    }
  }
  bool get isHealthy => _isConnected;
  
  /// Stream de estados da fila
  Stream<QueueState> get stateStream => _stateController.stream;
  
  /// Métricas da fila
  QueueMetrics get metrics => _metrics;
  
  /// Tamanho total da fila
  int get size => _priorityQueues.values.fold(0, (sum, q) => sum + q.length);
  
  /// Tamanho da DLQ
  int get deadLetterSize => _deadLetterQueue.length;
  
  /// Verifica se está processando
  bool get isProcessing => _isProcessing;
  
  /// Verifica se está pausado
  bool get isPaused => _isPaused;
  
  /// Inicializa o queue manager
  Future<void> initialize() async {
    try {
      _observability.addBreadcrumb(
        'Initializing QueueManager',
        category: 'queue',
      );
      
      // Carregar operações pendentes do banco
      await _loadPendingOperations();
      
      // Inicializar circuit breakers
      _initializeCircuitBreakers();
      
      // Inicializar rate limiters
      _initializeRateLimiters();
      
      // Inicializar workers
      _initializeWorkers();
      
      // Agendar persistência periódica
      _schedulePersistence();
      
      // Agendar flush de batches
      _scheduleBatchFlush();
      
      // Agendar cleanup
      _scheduleCleanup();
      
      // Iniciar processamento
      _startProcessing();
      
      _updateState(QueueState.idle(queueSize: size));
      
      if (kDebugMode) {
        debugPrint('✅ QueueManager initialized');
        debugPrint('   Pending operations: ${size}');
        debugPrint('   Workers: ${_config.maxWorkers}');
        debugPrint('   Dead letter: ${deadLetterSize}');
      }
      
    } catch (e, stackTrace) {
      await _observability.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'queue_manager.initialize',
      );
      rethrow;
    }
  }
  
  /// Enfileira uma operação
  Future<void> enqueue(
    QueuedOperation operation, {
    bool skipDeduplication = false,
  }) async {
    // Validar operação
    _validateOperation(operation);
    
    // Verificar backpressure
    if (size >= _config.maxQueueSize) {
      await _handleBackpressure(operation);
      return;
    }
    
    // Deduplicação
    if (!skipDeduplication && _isDuplicate(operation)) {
      if (kDebugMode) {
        debugPrint('⚠️  Duplicate operation detected: ${operation.id}');
      }
      
      _metrics.duplicatesDetected++;
      return;
    }
    
    try {
      // Persistir no banco imediatamente
      await _persistOperation(operation);
      
      // Adicionar à fila em memória
      final priority = _getOperationPriority(operation);
      _priorityQueues[priority]!.add(operation);
      
      // Registrar hash para deduplicação
      _registerOperationHash(operation);
      
      _metrics.enqueued++;
      _metrics.currentQueueSize = size;
      
      _updateState(QueueState.operationEnqueued(
        operation: operation,
        queueSize: size,
      ));
      
      // Iniciar processamento se não estiver rodando
      if (!_isProcessing) {
        _startProcessing();
      }
      
      if (kDebugMode) {
        debugPrint('📥 Operation enqueued: ${operation.id} [${priority.name}]');
      }
      
    } catch (e, stackTrace) {
      await _observability.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'queue_manager.enqueue',
        extra: {'operation_id': operation.id},
      );
      rethrow;
    }
  }
  
  /// Enfileira múltiplas operações
  Future<void> enqueueAll(List<QueuedOperation> operations) async {
    for (final operation in operations) {
      await enqueue(operation);
    }
  }
  
  /// Remove uma operação da fila
  Future<bool> dequeue(String operationId) async {
    for (final queue in _priorityQueues.values) {
      final operation = queue.firstWhereOrNull((op) => op.id == operationId);
      
      if (operation != null) {
        queue.remove(operation);
        
        await _db.deleteGeneric(
          'queue_operations',
          'id = ?',
          [operationId],
        );
        
        _metrics.dequeued++;
        _metrics.currentQueueSize = size;
        
        return true;
      }
    }
    
    return false;
  }
  
  /// Pausa o processamento
  void pause() {
    _isPaused = true;
    
    _updateState(QueueState.paused(queueSize: size));
    
    if (kDebugMode) {
      debugPrint('⏸️  Queue processing paused');
    }
  }
  
  /// Resume o processamento
  void resume() {
    _isPaused = false;
    
    _updateState(QueueState.resumed(queueSize: size));
    
    if (!_isProcessing) {
      _startProcessing();
    }
    
    if (kDebugMode) {
      debugPrint('▶️  Queue processing resumed');
    }
  }
  
  /// Limpa a fila
  Future<void> clear() async {
    for (final queue in _priorityQueues.values) {
      queue.clear();
    }
    
    await _db.deleteGeneric(
      'queue_operations',
      'status IN (?, ?)',
      ['pending', 'error'],
    );
    
    _metrics.currentQueueSize = 0;
    
    _updateState(QueueState.cleared());
    
    if (kDebugMode) {
      debugPrint('🗑️  Queue cleared');
    }
  }
  
  /// Obtém contagem de operações pendentes
  Future<int> getPendingCount() async {
    return size;
  }
  
  /// Obtém operações pendentes
  Future<List<QueuedOperation>> getPendingOperations({
    int? limit,
    QueuePriority? priority,
  }) async {
    final operations = <QueuedOperation>[];
    
    if (priority != null) {
      operations.addAll(_priorityQueues[priority]!);
    } else {
      for (final queue in _priorityQueues.values) {
        operations.addAll(queue);
      }
    }
    
    if (limit != null && operations.length > limit) {
      return operations.take(limit).toList();
    }
    
    return operations;
  }
  
  /// Reprocessa operação da DLQ
  Future<void> retryFromDLQ(String operationId) async {
    final operation = _deadLetterQueue.firstWhereOrNull(
      (op) => op.id == operationId
    );
    
    if (operation != null) {
      _deadLetterQueue.remove(operation);
      
      // Resetar contadores
      final retriedOp = operation.copyWith(
        retryCount: 0,
        status: QueueOperationStatus.pending,
        errorMessage: null,
      );
      
      await enqueue(retriedOp, skipDeduplication: true);
      
      if (kDebugMode) {
        debugPrint('🔄 Operation retried from DLQ: $operationId');
      }
    }
  }
  
  /// Inicia processamento da fila
  void _startProcessing() {
    if (_isProcessing || _isPaused) return;
    
    _isProcessing = true;
    
    // Distribuir trabalho entre workers
    for (final worker in _workers) {
      worker.start();
    }
  }
  
  /// Para processamento da fila
  Future<void> _stopProcessing() async {
    _isProcessing = false;
    
    for (final worker in _workers) {
      await worker.stop();
    }
  }
  
  /// Processa próxima operação (chamado pelos workers)
  Future<void> _processNext(Worker worker) async {
    if (_isPaused || size == 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      return;
    }
    
    // Selecionar operação de maior prioridade
    final operation = _selectNextOperation();
    
    if (operation == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      return;
    }
    
    _metrics.processing++;
    
    _updateState(QueueState.processing(
      operation: operation,
      queueSize: size,
    ));
    
    final startTime = DateTime.now();
    
    try {
      // Verificar circuit breaker
      final circuitBreaker = _circuitBreakers[operation.module];
      if (circuitBreaker != null && !circuitBreaker.canExecute) {
        throw CircuitBreakerOpenException(
          'Circuit breaker open for module: ${operation.module}'
        );
      }
      
      // Verificar rate limiter
      final rateLimiter = _rateLimiters[operation.module];
      if (rateLimiter != null && !rateLimiter.tryAcquire()) {
        // Recolocar na fila
        final priority = _getOperationPriority(operation);
        _priorityQueues[priority]!.addFirst(operation);
        
        await Future.delayed(const Duration(milliseconds: 500));
        return;
      }
      
      // Executar operação
      await _executeOperation(operation);
      
      // Marcar como processada
      await _markAsProcessed(operation);
      
      // Atualizar circuit breaker
      circuitBreaker?.recordSuccess();
      
      final duration = DateTime.now().difference(startTime);
      
      _metrics.processed++;
      _metrics.processing--;
      _metrics.totalProcessingTime += duration;
      
      _updateState(QueueState.operationProcessed(
        operation: operation,
        queueSize: size,
        duration: duration,
      ));
      
      if (kDebugMode) {
        debugPrint('✅ Operation processed: ${operation.id} (${duration.inMilliseconds}ms)');
      }
      
    } on CircuitBreakerOpenException catch (e) {
      // Aguardar antes de reprocessar
      await Future.delayed(const Duration(seconds: 5));
      
      // Recolocar na fila
      final priority = _getOperationPriority(operation);
      _priorityQueues[priority]!.addFirst(operation);
      
      _metrics.processing--;
      
    } catch (e, stackTrace) {
      await _handleOperationFailure(operation, e, stackTrace);
      
      final duration = DateTime.now().difference(startTime);
      
      _metrics.failed++;
      _metrics.processing--;
      
      _updateState(QueueState.operationFailed(
        operation: operation,
        error: e.toString(),
        queueSize: size,
      ));
    }
  }
  
  /// Seleciona próxima operação para processar
  QueuedOperation? _selectNextOperation() {
    // Buscar na ordem de prioridade
    for (final priority in QueuePriority.values.reversed) {
      final queue = _priorityQueues[priority]!;
      
      if (queue.isNotEmpty) {
        return queue.removeFirst();
      }
    }
    
    return null;
  }
  
  /// Executa uma operação
  Future<void> _executeOperation(QueuedOperation operation) async {
    final span = _observability.startChild(
      'queue.execute',
      description: 'Executing operation: ${operation.id}',
      data: {
        'module': operation.module,
        'action': operation.action,
      },
    );
    
    try {
      // Verificar se deve usar batching
      if (_config.enableBatching && _shouldBatch(operation)) {
        await _addToBatch(operation);
      } else {
        await _executeSingleOperation(operation);
      }
      
      await span?.finish(status: SpanStatus.ok());
      
    } catch (e) {
      await span?.finish(status: SpanStatus.internalError());
      rethrow;
    }
  }
  
  /// Executa operação individual
  Future<void> _executeSingleOperation(QueuedOperation operation) async {
    switch (operation.module) {
      case 'library':
        await _executeLibraryOperation(operation);
        break;
      case 'lyrics':
        await _executeLyricsOperation(operation);
        break;
      case 'quickaccess':
        await _executeQuickAccessOperation(operation);
        break;
      case 'sync':
        await _executeSyncOperation(operation);
        break;
      default:
        throw UnsupportedOperationException(
          'Unknown module: ${operation.module}'
        );
    }
  }
  
  /// Executa operação de library
  Future<void> _executeLibraryOperation(QueuedOperation operation) async {
    switch (operation.action) {
      case 'create_book':
        await _db.insertGeneric('books', operation.payload);
        break;
      case 'update_book':
        await _db.updateGeneric(
          'books',
          operation.payload,
          'id = ?',
          [operation.payload['id']],
        );
        break;
      case 'delete_book':
        await _db.deleteGeneric(
          'books',
          'id = ?',
          [operation.payload['id']],
        );
        break;
      default:
        throw UnsupportedOperationException(
          'Unknown action: ${operation.action}'
        );
    }
    
    // Marcar para sincronização
    await _syncEngine.markForSync(operation);
  }
  
  /// Executa operação de lyrics
  Future<void> _executeLyricsOperation(QueuedOperation operation) async {
    switch (operation.action) {
      case 'create_song':
        await _db.insertGeneric('songs', operation.payload);
        break;
      case 'update_song':
        await _db.updateGeneric(
          'songs',
          operation.payload,
          'id = ?',
          [operation.payload['id']],
        );
        break;
      case 'delete_song':
        await _db.deleteGeneric(
          'songs',
          'id = ?',
          [operation.payload['id']],
        );
        break;
      default:
        throw UnsupportedOperationException(
          'Unknown action: ${operation.action}'
        );
    }
    
    await _syncEngine.markForSync(operation);
  }
  
  /// Executa operação de quickaccess
  Future<void> _executeQuickAccessOperation(QueuedOperation operation) async {
    // Implementar lógica específica de quickaccess
    await _db.insertGeneric('quickaccess_log', operation.payload);
  }
  
  /// Executa operação de sync
  Future<void> _executeSyncOperation(QueuedOperation operation) async {
    // Delegar para sync engine
    await _syncEngine.processSyncOperation(operation);
  }
  
  /// Trata falha de operação
  Future<void> _handleOperationFailure(
    QueuedOperation operation,
    dynamic error,
    StackTrace stackTrace,
  ) async {
    final circuitBreaker = _circuitBreakers[operation.module];
    circuitBreaker?.recordFailure();
    
    await _observability.captureException(
      error,
      stackTrace: stackTrace,
      endpoint: 'queue_manager.execute_operation',
      extra: {
        'operation_id': operation.id,
        'module': operation.module,
        'action': operation.action,
        'retry_count': operation.retryCount,
      },
    );
    
    // Verificar se pode retentar
    if (operation.canRetry(maxRetries: _config.maxRetries)) {
      final retryOp = operation.incrementRetry();
      
      // Calcular delay de retry
      final delay = _calculateRetryDelay(retryOp);
      
      if (kDebugMode) {
        debugPrint('🔄 Retrying operation ${operation.id} after ${delay.inSeconds}s');
      }
      
      // Atualizar no banco
      await _updateOperationInDB(retryOp);
      
      // Recolocar na fila com delay
      Future.delayed(delay, () {
        final priority = _getOperationPriority(retryOp);
        _priorityQueues[priority]!.add(retryOp);
      });
      
      _metrics.retried++;
      
    } else {
      // Mover para Dead Letter Queue
      await _moveToDeadLetterQueue(operation, error.toString());
      
      _metrics.movedToDLQ++;
      
      if (kDebugMode) {
        debugPrint('💀 Operation moved to DLQ: ${operation.id}');
      }
    }
  }
  
  /// Calcula delay de retry baseado na estratégia
  Duration _calculateRetryDelay(QueuedOperation operation) {
    switch (_config.retryStrategy) {
      case RetryStrategy.exponential:
        // 2^retry * 1000ms
        final backoff = (1 << operation.retryCount) * 1000;
        return Duration(milliseconds: backoff);
        
      case RetryStrategy.linear:
        // retry * 2000ms
        return Duration(milliseconds: operation.retryCount * 2000);
        
      case RetryStrategy.fixed:
        return _config.fixedRetryDelay;
        
      case RetryStrategy.jittered:
        // Exponential com jitter aleatório
        final base = (1 << operation.retryCount) * 1000;
        final jitter = (base * 0.3).toInt(); // 30% jitter
        final randomJitter = DateTime.now().millisecond % jitter;
        return Duration(milliseconds: base + randomJitter);
    }
  }
  
  /// Move operação para Dead Letter Queue
  Future<void> _moveToDeadLetterQueue(
    QueuedOperation operation,
    String error,
  ) async {
    final dlqOp = operation.markAsError(error);
    
    _deadLetterQueue.add(dlqOp);
    
    await _db.updateGeneric(
      'queue_operations',
      {
        'status': 'dead_letter',
        'error_message': error,
        'processed_at': DateTime.now().toIso8601String(),
      },
      'id = ?',
      [operation.id],
    );
  }
  
  /// Marca operação como processada
  Future<void> _markAsProcessed(QueuedOperation operation) async {
    await _db.updateGeneric(
      'queue_operations',
      {
        'status': 'processed',
        'processed_at': DateTime.now().toIso8601String(),
      },
      'id = ?',
      [operation.id],
    );
  }
  
  /// Verifica se operação é duplicada
  bool _isDuplicate(QueuedOperation operation) {
    final hash = _generateOperationHash(operation);
    
    if (_operationHashes.containsKey(hash)) {
      final timestamp = _operationHashes[hash]!;
      final age = DateTime.now().difference(timestamp);
      
      // Considerar duplicado se foi enfileirado nos últimos 5 minutos
      return age < _config.deduplicationWindow;
    }
    
    return false;
  }
  
  /// Registra hash de operação
  void _registerOperationHash(QueuedOperation operation) {
    final hash = _generateOperationHash(operation);
    _operationHashes[hash] = DateTime.now();
  }
  
  /// Gera hash de operação
  String _generateOperationHash(QueuedOperation operation) {
    return '${operation.module}:${operation.action}:${operation.payload.hashCode}';
  }
  
  /// Valida operação
  void _validateOperation(QueuedOperation operation) {
    if (operation.id.isEmpty) {
      throw InvalidOperationException('Operation ID cannot be empty');
    }
    
    if (operation.module.isEmpty) {
      throw InvalidOperationException('Operation module cannot be empty');
    }
    
    if (operation.action.isEmpty) {
      throw InvalidOperationException('Operation action cannot be empty');
    }
  }
  
  /// Lida com backpressure
  Future<void> _handleBackpressure(QueuedOperation operation) async {
    switch (_config.backpressureStrategy) {
      case BackpressureStrategy.reject:
        throw QueueFullException('Queue is full. Size: ${size}');
        
      case BackpressureStrategy.dropOldest:
        // Remove operação mais antiga de menor prioridade
        for (final priority in QueuePriority.values) {
          final queue = _priorityQueues[priority]!;
          if (queue.isNotEmpty) {
            final dropped = queue.removeFirst();
            await dequeue(dropped.id);
            
            _metrics.dropped++;
            
            if (kDebugMode) {
              debugPrint('⚠️  Dropped operation due to backpressure: ${dropped.id}');
            }
            
            break;
          }
        }
        
        // Tentar enfileirar novamente
        await enqueue(operation, skipDeduplication: true);
        break;
        
      case BackpressureStrategy.block:
        // Aguardar até ter espaço
        while (size >= _config.maxQueueSize) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        await enqueue(operation, skipDeduplication: true);
        break;
    }
  }
  
  /// Obtém prioridade de operação
  QueuePriority _getOperationPriority(QueuedOperation operation) {
    // Prioridade pode ser ajustada baseada em vários fatores
    final basePriority = QueuePriority.values.firstWhere(
      (p) => p.value == (operation.payload['priority'] ?? 50),
      orElse: () => QueuePriority.normal,
    );
    
    // Aumentar prioridade se retry count é alto (evitar starvation)
    if (operation.retryCount > 2) {
      final index = QueuePriority.values.indexOf(basePriority);
      if (index < QueuePriority.values.length - 1) {
        return QueuePriority.values[index + 1];
      }
    }
    
    return basePriority;
  }
  
  /// Verifica se operação deve ser processada em batch
  bool _shouldBatch(QueuedOperation operation) {
    // Apenas algumas operações se beneficiam de batching
    return operation.module == 'sync' || operation.module == 'analytics';
  }
  
  /// Adiciona operação ao batch
  Future<void> _addToBatch(QueuedOperation operation) async {
    final batchKey = '${operation.module}:${operation.action}';
    
    _batchBuffers[batchKey] ??= [];
    _batchBuffers[batchKey]!.add(operation);
    
    // Se batch está cheio, processar
    if (_batchBuffers[batchKey]!.length >= _config.batchSize) {
      await _flushBatch(batchKey);
    }
  }
  
  /// Processa batch
  Future<void> _flushBatch(String batchKey) async {
    final batch = _batchBuffers[batchKey];
    
    if (batch == null || batch.isEmpty) return;
    
    if (kDebugMode) {
      debugPrint('📦 Flushing batch: $batchKey (${batch.length} operations)');
    }
    
    try {
      // Processar batch atomicamente
      await _db.transaction(() async {
        for (final operation in batch) {
          await _executeSingleOperation(operation);
          await _markAsProcessed(operation);
        }
      });
      
      _metrics.batchesProcessed++;
      
    } catch (e, stackTrace) {
      // Em caso de erro, reprocessar individualmente
      for (final operation in batch) {
        try {
          await _executeSingleOperation(operation);
          await _markAsProcessed(operation);
        } catch (opError, opStackTrace) {
          await _handleOperationFailure(operation, opError, opStackTrace);
        }
      }
    } finally {
      _batchBuffers.remove(batchKey);
    }
  }
  
  /// Carrega operações pendentes do banco
  Future<void> _loadPendingOperations() async {
    final results = await _db.queryGeneric(
      'queue_operations',
      where: 'status IN (?, ?)',
      whereArgs: ['pending', 'error'],
      orderBy: 'priority DESC, created_at ASC',
    );
    
    for (final json in results) {
      final operation = QueuedOperation.fromJson(json);
      final priority = _getOperationPriority(operation);
      
      _priorityQueues[priority]!.add(operation);
      _registerOperationHash(operation);
    }
    
    _metrics.currentQueueSize = size;
    
    // Carregar DLQ
    final dlqResults = await _db.queryGeneric(
      'queue_operations',
      where: 'status = ?',
      whereArgs: ['dead_letter'],
    );
    
    for (final json in dlqResults) {
      _deadLetterQueue.add(QueuedOperation.fromJson(json));
    }
  }
  
  /// Persiste operação no banco
  Future<void> _persistOperation(QueuedOperation operation) async {
    await _db.insertGeneric('queue_operations', operation.toJson());
  }
  
  /// Atualiza operação no banco
  Future<void> _updateOperationInDB(QueuedOperation operation) async {
    await _db.updateGeneric(
      'queue_operations',
      operation.toJson(),
      'id = ?',
      [operation.id],
    );
  }
  
  /// Inicializa circuit breakers
  void _initializeCircuitBreakers() {
    for (final module in ['library', 'lyrics', 'quickaccess', 'sync']) {
      _circuitBreakers[module] = CircuitBreaker(
        failureThreshold: _config.circuitBreakerThreshold,
        timeout: _config.circuitBreakerTimeout,
        onStateChange: (state) {
          if (kDebugMode) {
            debugPrint('⚡ Circuit breaker [$module]: $state');
          }
        },
      );
    }
  }
  
  /// Inicializa rate limiters
  void _initializeRateLimiters() {
    for (final module in ['library', 'lyrics', 'quickaccess', 'sync']) {
      _rateLimiters[module] = RateLimiter(
        maxTokens: _config.rateLimit,
        refillRate: Duration(seconds: 1),
      );
    }
  }
  
  /// Inicializa workers
  void _initializeWorkers() {
    for (int i = 0; i < _config.maxWorkers; i++) {
      _workers.add(Worker(
        id: i,
        processNext: _processNext,
      ));
    }
  }
  
  /// Agenda persistência periódica
  void _schedulePersistence() {
    _persistenceTimer = Timer.periodic(
      _config.persistenceInterval,
      (_) async {
        await _persistState();
      },
    );
  }
  
  /// Agenda flush de batches
  void _scheduleBatchFlush() {
    _batchFlushTimer = Timer.periodic(
      _config.batchFlushInterval,
      (_) async {
        for (final batchKey in _batchBuffers.keys.toList()) {
          await _flushBatch(batchKey);
        }
      },
    );
  }
  
  /// Agenda cleanup
  void _scheduleCleanup() {
    _cleanupTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) async {
        await _cleanup();
      },
    );
  }
  
  /// Persiste estado atual
  Future<void> _persistState() async {
    // Limpar hashes antigos
    final cutoff = DateTime.now().subtract(_config.deduplicationWindow);
    _operationHashes.removeWhere((_, timestamp) => timestamp.isBefore(cutoff));
  }
  
  /// Cleanup de operações antigas
  Future<void> _cleanup() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    
    final deleted = await _db.deleteGeneric(
      'queue_operations',
      'status = ? AND processed_at < ?',
      ['processed', cutoffDate.toIso8601String()],
    );
    
    if (kDebugMode && deleted > 0) {
      debugPrint('🧹 Cleaned up $deleted old queue operations');
    }
  }
  
  /// Atualiza estado
  void _updateState(QueueState state) {
    _stateController.add(state);
  }
  
  /// Libera recursos
  Future<void> dispose() async {
    await _stopProcessing();
    
    _persistenceTimer?.cancel();
    _batchFlushTimer?.cancel();
    _cleanupTimer?.cancel();
    
    await _stateController.close();
    
    if (kDebugMode) {
      debugPrint('🔒 QueueManager disposed');
      debugPrint('   Final metrics:');
      debugPrint('     Enqueued: ${_metrics.enqueued}');
      debugPrint('     Processed: ${_metrics.processed}');
      debugPrint('     Failed: ${_metrics.failed}');
      debugPrint('     DLQ: ${_metrics.movedToDLQ}');
    }
  }
}

// ══════════════════════════════════════════
// WORKER
// ══════════════════════════════════════════

class Worker {
  final int id;
  final Future<void> Function(Worker) processNext;
  
  bool _isRunning = false;
  
  Worker({
    required this.id,
    required this.processNext,
  });
  
  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    _run();
  }
  
  Future<void> stop() async {
    _isRunning = false;
  }
  
  Future<void> _run() async {
    while (_isRunning) {
      try {
        await processNext(this);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️  Worker $id error: $e');
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }
}

// ══════════════════════════════════════════
// ESTADO DA FILA
// ══════════════════════════════════════════

abstract class QueueState {
  const QueueState();
  
  factory QueueState.idle({required int queueSize}) = QueueStateIdle;
  factory QueueState.operationEnqueued({
    required QueuedOperation operation,
    required int queueSize,
  }) = QueueStateOperationEnqueued;
  factory QueueState.processing({
    required QueuedOperation operation,
    required int queueSize,
  }) = QueueStateProcessing;
  factory QueueState.operationProcessed({
    required QueuedOperation operation,
    required int queueSize,
    required Duration duration,
  }) = QueueStateOperationProcessed;
  factory QueueState.operationFailed({
    required QueuedOperation operation,
    required String error,
    required int queueSize,
  }) = QueueStateOperationFailed;
  factory QueueState.paused({required int queueSize}) = QueueStatePaused;
  factory QueueState.resumed({required int queueSize}) = QueueStateResumed;
  factory QueueState.cleared() = QueueStateCleared;
}

class QueueStateIdle extends QueueState {
  final int queueSize;
  const QueueStateIdle({required this.queueSize});
}

class QueueStateOperationEnqueued extends QueueState {
  final QueuedOperation operation;
  final int queueSize;
  const QueueStateOperationEnqueued({
    required this.operation,
    required this.queueSize,
  });
}

class QueueStateProcessing extends QueueState {
  final QueuedOperation operation;
  final int queueSize;
  const QueueStateProcessing({
    required this.operation,
    required this.queueSize,
  });
}

class QueueStateOperationProcessed extends QueueState {
  final QueuedOperation operation;
  final int queueSize;
  final Duration duration;
  const QueueStateOperationProcessed({
    required this.operation,
    required this.queueSize,
    required this.duration,
  });
}

class QueueStateOperationFailed extends QueueState {
  final QueuedOperation operation;
  final String error;
  final int queueSize;
  const QueueStateOperationFailed({
    required this.operation,
    required this.error,
    required this.queueSize,
  });
}

class QueueStatePaused extends QueueState {
  final int queueSize;
  const QueueStatePaused({required this.queueSize});
}

class QueueStateResumed extends QueueState {
  final int queueSize;
  const QueueStateResumed({required this.queueSize});
}

class QueueStateCleared extends QueueState {
  const QueueStateCleared();
}

// ══════════════════════════════════════════
// MÉTRICAS
// ══════════════════════════════════════════

class QueueMetrics {
  int enqueued = 0;
  int dequeued = 0;
  int processed = 0;
  int failed = 0;
  int retried = 0;
  int processing = 0;
  int movedToDLQ = 0;
  int duplicatesDetected = 0;
  int dropped = 0;
  int batchesProcessed = 0;
  int currentQueueSize = 0;
  Duration totalProcessingTime = Duration.zero;
  
  Duration get averageProcessingTime {
    return processed > 0
      ? Duration(microseconds: totalProcessingTime.inMicroseconds ~/ processed)
      : Duration.zero;
  }
  
  double get successRate {
    final total = processed + failed;
    return total > 0 ? (processed / total) * 100 : 0.0;
  }
  
  @override
  String toString() {
    return 'QueueMetrics(\n'
           '  Enqueued: $enqueued\n'
           '  Processed: $processed\n'
           '  Failed: $failed\n'
           '  Retried: $retried\n'
           '  DLQ: $movedToDLQ\n'
           '  Processing: $processing\n'
           '  Queue Size: $currentQueueSize\n'
           '  Success Rate: ${successRate.toStringAsFixed(1)}%\n'
           '  Avg Processing Time: ${averageProcessingTime.inMilliseconds}ms\n'
           ')';
  }
}

// ══════════════════════════════════════════
// EXCEÇÕES
// ══════════════════════════════════════════

class QueueException implements Exception {
  final String message;
  QueueException(this.message);
  
  @override
  String toString() => 'QueueException: $message';
}

class QueueFullException extends QueueException {
  QueueFullException(String message) : super(message);
}

class InvalidOperationException extends QueueException {
  InvalidOperationException(String message) : super(message);
}

class UnsupportedOperationException extends QueueException {
  UnsupportedOperationException(String message) : super(message);
}

class CircuitBreakerOpenException extends QueueException {
  CircuitBreakerOpenException(String message) : super(message);
}
