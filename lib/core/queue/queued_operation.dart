// core/queue/queued_operation.dart
import 'dart:convert';

class QueuedOperation {
  final String id;
  final String module;
  final String action;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final QueueOperationStatus status;
  final String? errorMessage;
  
  QueuedOperation({
    required this.id,
    required this.module,
    required this.action,
    required this.payload,
    DateTime? createdAt,
    this.retryCount = 0,
    this.status = QueueOperationStatus.pending,
    this.errorMessage,
  }) : createdAt = createdAt ?? DateTime.now();
  
  /// Cria uma cópia com valores modificados
  QueuedOperation copyWith({
    String? id,
    String? module,
    String? action,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? retryCount,
    QueueOperationStatus? status,
    String? errorMessage,
  }) {
    return QueuedOperation(
      id: id ?? this.id,
      module: module ?? this.module,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
  
  /// Converte para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'module': module,
      'action': action,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'status': status.name,
      'error_message': errorMessage,
    };
  }
  
  /// Cria instância a partir de JSON
  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'] as String,
      module: json['module'] as String,
      action: json['action'] as String,
      payload: json['payload'] is String 
        ? jsonDecode(json['payload'] as String)
        : json['payload'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
      status: QueueOperationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => QueueOperationStatus.pending,
      ),
      errorMessage: json['error_message'] as String?,
    );
  }
  
  /// Verifica se a operação pode ser retentada
  bool canRetry({int maxRetries = 3}) {
    return retryCount < maxRetries && 
           status == QueueOperationStatus.error;
  }
  
  /// Incrementa contador de retry
  QueuedOperation incrementRetry() {
    return copyWith(
      retryCount: retryCount + 1,
      status: QueueOperationStatus.pending,
    );
  }
  
  /// Marca como processada
  QueuedOperation markAsProcessed() {
    return copyWith(status: QueueOperationStatus.processed);
  }
  
  /// Marca como erro
  QueuedOperation markAsError(String error) {
    return copyWith(
      status: QueueOperationStatus.error,
      errorMessage: error,
    );
  }
  
  @override
  String toString() {
    return 'QueuedOperation(id: $id, module: $module, action: $action, status: ${status.name})';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is QueuedOperation && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

/// Status de operação na fila
enum QueueOperationStatus {
  pending,
  processing,
  processed,
  error,
  cancelled,
}

/// Extensão para QueueOperationStatus
extension QueueOperationStatusExtension on QueueOperationStatus {
  String get displayName {
    switch (this) {
      case QueueOperationStatus.pending:
        return 'Pendente';
      case QueueOperationStatus.processing:
        return 'Processando';
      case QueueOperationStatus.processed:
        return 'Concluído';
      case QueueOperationStatus.error:
        return 'Erro';
      case QueueOperationStatus.cancelled:
        return 'Cancelado';
    }
  }
  
  String get icon {
    switch (this) {
      case QueueOperationStatus.pending:
        return '⏳';
      case QueueOperationStatus.processing:
        return '🔄';
      case QueueOperationStatus.processed:
        return '✅';
      case QueueOperationStatus.error:
        return '❌';
      case QueueOperationStatus.cancelled:
        return '🚫';
    }
  }
}
