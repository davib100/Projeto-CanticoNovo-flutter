// core/sync/sync_operation.dart

/// Operação de sincronização
class SyncOperation {
  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int priority;
  
  SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.priority,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'priority': priority,
    };
  }
  
  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      operation: json['operation'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
      priority: json['priority'] as int? ?? 50,
    );
  }
}

/// Operação do servidor
class ServerOperation {
  final String entityType;
  final String entityId;
  final String operationType;
  final int version;
  final Map<String, dynamic> data;
  
  ServerOperation({
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.version,
    required this.data,
  });
  
  factory ServerOperation.fromJson(Map<String, dynamic> json) {
    return ServerOperation(
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      operationType: json['operation_type'] as String,
      version: json['version'] as int,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

/// Resposta de batch
class BatchResponse {
  final List<OperationResult> results;
  
  BatchResponse({required this.results});
  
  factory BatchResponse.fromJson(Map<String, dynamic> json) {
    return BatchResponse(
      results: (json['results'] as List)
          .map((r) => OperationResult.fromJson(r))
          .toList(),
    );
  }
}

/// Resultado de operação
class OperationResult {
  final SyncOperation localOperation;
  final bool success;
  final bool hasConflict;
  final Map<String, dynamic>? serverData;
  final String? error;
  
  OperationResult({
    required this.localOperation,
    required this.success,
    required this.hasConflict,
    this.serverData,
    this.error,
  });
  
  factory OperationResult.fromJson(Map<String, dynamic> json) {
    return OperationResult(
      localOperation: SyncOperation.fromJson(json['local_operation']),
      success: json['success'] as bool,
      hasConflict: json['has_conflict'] as bool? ?? false,
      serverData: json['server_data'] as Map<String, dynamic>?,
      error: json['error'] as String?,
    );
  }
}

/// Versão local de entidade
class LocalVersion {
  final String entityType;
  final String entityId;
  final int version;
  final Map<String, dynamic> data;
  
  LocalVersion({
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.data,
  });
  
  factory LocalVersion.fromJson(Map<String, dynamic> json) {
    return LocalVersion(
      entityType: json['entity_type'] as String? ?? 'unknown',
      entityId: json['id'].toString(),
      version: json['version'] as int? ?? 1,
      data: json,
    );
  }
}
