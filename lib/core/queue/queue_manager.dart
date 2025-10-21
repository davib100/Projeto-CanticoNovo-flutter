import 'dart:async';
import 'package:flutter/foundation.dart';
//import 'package:collection/collection.dart';
import 'package:queue/queue.dart';
import 'package:rxdart/rxdart.dart';

import '../db/database_adapter.dart';
import '../db/database_adapter_impl.dart';
import '../observability/observability_service.dart';
import '../sync/sync_engine.dart';
import 'queue_config.dart';
import 'queued_operation.dart';
import '../services/connectivity_service.dart';

/// Tipos de eventos da fila
enum QueueEventType {
  operationAdded,
  operationSuccess,
  operationFailure,
  batchProcessed,
  queueResumed,
  queuePaused,
  queueCleared,
  syncStarted,
  syncCompleted,
}

/// Evento da fila
class QueueEvent {
  final QueueEventType type;
  final dynamic data;

  QueueEvent(this.type, {this.data});
}

/// Métricas da fila
@immutable
class QueueMetrics {
  final int totalOperations;
  final int pendingOperations;
  final int successfulOperations;
  final int failedOperations;
  final int retries;

  const QueueMetrics({
    this.totalOperations = 0,
    this.pendingOperations = 0,
    this.successfulOperations = 0,
    this.failedOperations = 0,
    this.retries = 0,
  });

  QueueMetrics copyWith({
    int? totalOperations,
    int? pendingOperations,
    int? successfulOperations,
    int? failedOperations,
    int? retries,
  }) {
    return QueueMetrics(
      totalOperations: totalOperations ?? this.totalOperations,
      pendingOperations: pendingOperations ?? this.pendingOperations,
      successfulOperations: successfulOperations ?? this.successfulOperations,
      failedOperations: failedOperations ?? this.failedOperations,
      retries: retries ?? this.retries,
    );
  }
}

/// Gerenciador de fila de operações com prioridades
class QueueManager {
  final DatabaseAdapter _dbAdapter;
  final SyncEngine _syncEngine;
  final ObservabilityService _observability;
  final QueueConfig _config;
  final ConnectivityService _connectivityService;

  final Map<QueuePriority, Queue> _priorityQueues = {};

  final BehaviorSubject<QueueState> _stateController = BehaviorSubject.seeded(
    QueueState.idle,
  );
  final PublishSubject<QueueEvent> _eventController =
      PublishSubject<QueueEvent>();

  QueueMetrics _metrics = const QueueMetrics();
  bool _isPaused = false;
  late StreamSubscription<bool> _connectivitySubscription;

  final Map<String, List<QueuedOperation>> _batchBuffers = {};

  QueueManager({
    required DatabaseAdapter db,
    required SyncEngine syncEngine,
    ObservabilityService? observability,
    QueueConfig? config,
    ConnectivityService? connectivityService,
  })  : _dbAdapter = db as DatabaseAdapterImpl,
        _syncEngine = syncEngine,
        _observability = observability ?? ObservabilityService(),
        _config = config ?? QueueConfig.defaults(),
        _connectivityService =
            connectivityService ?? ConnectivityService.instance {
    for (final priority in QueuePriority.values) {
      _priorityQueues[priority] = Queue(
        parallel: _config.concurrency,
        delay: _config.processingDelay,
      );
    }
    _connectivitySubscription = _connectivityService.isConnected$.listen(
      _handleConnectivityChange,
    );
    _loadPendingOperations();
  }

  Stream<QueueState> get stateStream => _stateController.stream;

  QueueMetrics get metrics => _metrics;

  int get size => _metrics.pendingOperations;

  bool get isHealthy => !_isPaused && _connectivityService.isConnected;

  Future<void> add(QueuedOperation operation) async {
    if (_isPaused) {
      await _dbAdapter.saveOperation(operation.copyWith(status: 'paused'));
      return;
    }

    await _dbAdapter.saveOperation(operation);
    _updateMetrics(pending: 1, total: 1);

    if (operation.batchId != null) {
      _batchBuffers.putIfAbsent(operation.batchId!, () => []).add(operation);
      return;
    }

    await _priorityQueues[operation.priority]!.add(() => _process(operation));
    _eventController.add(
      QueueEvent(QueueEventType.operationAdded, data: operation),
    );
  }

  Future<void> _process(QueuedOperation operation) async {
    if (!_connectivityService.isConnected) {
      _retry(operation, error: "No connection");
      return;
    }

    try {
      await _syncEngine.sync(priority: _convertPriority(operation.priority));
      await _dbAdapter.deleteOperation(operation.id);
      _updateMetrics(successful: 1, pending: -1);
      _eventController.add(
        QueueEvent(QueueEventType.operationSuccess, data: operation),
      );
    } catch (e, s) {
      _observability.captureException(
        e,
        stackTrace: s,
        hint: 'Queue Processing Error',
      );
      _retry(operation, error: e);
    }
  }

  SyncPriority _convertPriority(QueuePriority priority) {
    switch (priority) {
      case QueuePriority.low:
        return SyncPriority.low;
      case QueuePriority.medium:
        return SyncPriority.normal;
      case QueuePriority.high:
        return SyncPriority.high;
      case QueuePriority.critical:
        return SyncPriority.critical;
    }
  }

  void _retry(QueuedOperation operation, {dynamic error}) async {
    if (operation.canRetry) {
      final newAttempt = operation.incrementRetry();
      await _dbAdapter.updateOperation(newAttempt);
      _updateMetrics(retries: 1);
      Future.delayed(_config.retryDelay, () {
        add(newAttempt);
      });
    } else {
      await _dbAdapter.updateOperation(operation.copyWith(status: 'failed'));
      _updateMetrics(failed: 1, pending: -1);
      _eventController.add(
        QueueEvent(
          QueueEventType.operationFailure,
          data: {'operation': operation, 'error': error},
        ),
      );
    }
  }

  void pause() {
    _isPaused = true;
    _stateController.add(QueueState.paused);
  }

  void resume() {
    _isPaused = false;
    _stateController.add(QueueState.running);
    _loadPendingOperations();
  }

  void clear() async {
    for (final queue in _priorityQueues.values) {
      queue.dispose();
    }
    _batchBuffers.clear();
    await _dbAdapter.clearAllOperations();
    _metrics = const QueueMetrics();
    _stateController.add(QueueState.idle);
  }

  void _updateMetrics({
    int total = 0,
    int pending = 0,
    int successful = 0,
    int failed = 0,
    int retries = 0,
  }) {
    _metrics = _metrics.copyWith(
      totalOperations: _metrics.totalOperations + total,
      pendingOperations: _metrics.pendingOperations + pending,
      successfulOperations: _metrics.successfulOperations + successful,
      failedOperations: _metrics.failedOperations + failed,
      retries: _metrics.retries + retries,
    );
  }

  void _handleConnectivityChange(bool isConnected) {
    if (isConnected) {
      resume();
    } else {
      pause();
    }
  }

  Future<void> _loadPendingOperations() async {
    final pending = await _dbAdapter.getPendingOperations();
    for (final op in pending) {
      add(op);
    }
  }

  void dispose() {
    _stateController.close();
    _eventController.close();
    _connectivitySubscription.cancel();
    for (final queue in _priorityQueues.values) {
      queue.dispose();
    }
  }
}

enum QueueState { idle, running, paused, processingBatch, syncing }
