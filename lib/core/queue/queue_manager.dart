// core/queue/queue_manager.dart
import 'dart:convert';
import 'dart:collection';

// Estes são os imports que eu presumi que você está usando.
// Se os caminhos estiverem incorretos, por favor me avise.
import 'package:myapp/core/db/database_adapter.dart';
import 'package:myapp/core/queue/queued_operation.dart';
import 'package:myapp/core/sync/sync_engine.dart';

class QueueManager {
  final DatabaseAdapter _db;
  final SyncEngine _syncEngine;
  final _queue = Queue<QueuedOperation>();
  bool _isProcessing = false;

  QueueManager({
    required DatabaseAdapter db,
    required SyncEngine syncEngine,
  })  : _db = db,
        _syncEngine = syncEngine;

  Future<void> initialize() async {
    // Carregar operações pendentes do banco
    final pendingOps = await _db.queryGeneric(
      'queue_operations',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
    
    for (final op in pendingOps) {
      // TODO: O método QueuedOperation.fromJson não foi fornecido.
      // Substitua pelo seu método de desserialização.
      // _queue.add(QueuedOperation.fromJson(op));
    }
    
    // Iniciar processamento automático
    _processQueue();
  }
  
  Future<void> enqueue(QueuedOperation operation) async {
    await _db.insert('queue_operations', {
      'id': operation.id,
      'module': operation.module,
      'action': operation.action,
      'payload': jsonEncode(operation.payload),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0
    });
    
    _queue.add(operation);
    _processQueue();
  }
  
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    
    _isProcessing = true;
    
    while (_queue.isNotEmpty) {
      final operation = _queue.removeFirst();
      
      try {
        await _executeOperation(operation);
        await _markAsProcessed(operation.id);
      } catch (e) {
        await _handleFailure(operation, e);
      }
    }
    
    _isProcessing = false;
  }
  
  Future<void> _executeOperation(QueuedOperation op) async {
    switch (op.module) {
      case 'library':
        await _db.insert(op.action, op.payload);
        break;
      case 'lyrics':
        await _db.update(op.action, op.payload);
        break;
      // ... outros módulos
    }
    
    await _syncEngine.markForSync(op);
  }

  Future<void> _markAsProcessed(String id) async {
    await _db.update('queue_operations', {'status': 'processed'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _handleFailure(QueuedOperation op, Object error) async {
    final newRetryCount = op.retryCount + 1;
    if (newRetryCount > 5) {
      await _db.update('queue_operations', {'status': 'failed'}, where: 'id = ?', whereArgs: [op.id]);
    } else {
      await _db.update('queue_operations', {'retry_count': newRetryCount}, where: 'id = ?', whereArgs: [op.id]);
    }
  }

  Future<int> getPendingCount() async {
    final result = await _db.queryGeneric(
      'queue_operations',
      columns: ['COUNT(*) as count'],
      where: 'status = ?',
      whereArgs: ['pending'],
    );
    
    if (result.isNotEmpty && result.first.containsKey('count')) {
        final count = result.first['count'];
        if (count is int) {
            return count;
        }
    }
    return 0;
  }
  
  Future<void> dispose() async {
    _queue.clear();
  }
}
