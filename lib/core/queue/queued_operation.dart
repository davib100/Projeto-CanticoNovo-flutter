import 'package:uuid/uuid.dart';

// Enum para as prioridades da fila
enum QueuePriority {
  low,
  medium,
  high,
  critical, // Para operações que não podem falhar
}

// Classe que representa uma operação na fila
class QueuedOperation {
  final String id; // Identificador único da operação
  final String type; // Tipo da operação (ex: 'sync', 'upload', 'delete')
  final dynamic data; // Dados da operação
  final QueuePriority priority; // Prioridade da operação
  final int maxRetries; // Número máximo de tentativas
  final int attempts; // Tentativas já realizadas
  final String? batchId; // ID para agrupar operações em lote
  final DateTime createdAt; // Data de criação
  final String? status; // Status da operação

  QueuedOperation({
    String? id,
    required this.type,
    this.data,
    this.priority = QueuePriority.medium,
    this.maxRetries = 3,
    this.attempts = 0,
    this.batchId,
    this.status,
  }) : id = id ?? const Uuid().v4(),
       createdAt = DateTime.now();

  // Verifica se a operação ainda pode ser tentada novamente
  bool get canRetry => attempts < maxRetries;

  // Retorna uma nova instância da operação com a contagem de tentativas incrementada
  QueuedOperation incrementRetry() {
    return QueuedOperation(
      id: id,
      type: type,
      data: data,
      priority: priority,
      maxRetries: maxRetries,
      attempts: attempts + 1,
      batchId: batchId,
      status: status,
    );
  }

  QueuedOperation copyWith({
    String? id,
    String? type,
    dynamic data,
    QueuePriority? priority,
    int? maxRetries,
    int? attempts,
    String? batchId,
    DateTime? createdAt,
    String? status,
  }) {
    return QueuedOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      priority: priority ?? this.priority,
      maxRetries: maxRetries ?? this.maxRetries,
      attempts: attempts ?? this.attempts,
      batchId: batchId ?? this.batchId,
      status: status ?? this.status,
    );
  }
}
