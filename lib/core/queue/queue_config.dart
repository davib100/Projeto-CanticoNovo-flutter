// core/queue/queue_config.dart

/// Configuração do Queue Manager
class QueueConfig {
  /// Número máximo de workers concorrentes
  final int maxWorkers;
  
  /// Tamanho máximo da fila
  final int maxQueueSize;
  
  /// Número máximo de tentativas de retry
  final int maxRetries;
  
  /// Estratégia de retry
  final RetryStrategy retryStrategy;
  
  /// Delay fixo para retry (usado quando strategy é fixed)
  final Duration fixedRetryDelay;
  
  /// Habilitar batch processing
  final bool enableBatching;
  
  /// Tamanho do batch
  final int batchSize;
  
  /// Intervalo para flush de batches
  final Duration batchFlushInterval;
  
  /// Janela de deduplicação
  final Duration deduplicationWindow;
  
  /// Intervalo de persistência de estado
  final Duration persistenceInterval;
  
  /// Estratégia de backpressure
  final BackpressureStrategy backpressureStrategy;
  
  /// Threshold do circuit breaker (número de falhas consecutivas)
  final int circuitBreakerThreshold;
  
  /// Timeout do circuit breaker (tempo em estado open)
  final Duration circuitBreakerTimeout;
  
  /// Rate limit (operações por segundo por módulo)
  final int rateLimit;
  
  const QueueConfig({
    required this.maxWorkers,
    required this.maxQueueSize,
    required this.maxRetries,
    required this.retryStrategy,
    required this.fixedRetryDelay,
    required this.enableBatching,
    required this.batchSize,
    required this.batchFlushInterval,
    required this.deduplicationWindow,
    required this.persistenceInterval,
    required this.backpressureStrategy,
    required this.circuitBreakerThreshold,
    required this.circuitBreakerTimeout,
    required this.rateLimit,
  });
  
  /// Configuração padrão otimizada
  factory QueueConfig.defaults() {
    return const QueueConfig(
      maxWorkers: 3,
      maxQueueSize: 10000,
      maxRetries: 3,
      retryStrategy: RetryStrategy.exponential,
      fixedRetryDelay: Duration(seconds: 5),
      enableBatching: true,
      batchSize: 50,
      batchFlushInterval: Duration(seconds: 10),
      deduplicationWindow: Duration(minutes: 5),
      persistenceInterval: Duration(seconds: 30),
      backpressureStrategy: BackpressureStrategy.dropOldest,
      circuitBreakerThreshold: 5,
      circuitBreakerTimeout: Duration(minutes: 1),
      rateLimit: 100,
    );
  }
  
  /// Configuração para alta performance
  factory QueueConfig.highPerformance() {
    return const QueueConfig(
      maxWorkers: 8,
      maxQueueSize: 50000,
      maxRetries: 5,
      retryStrategy: RetryStrategy.jittered,
      fixedRetryDelay: Duration(seconds: 3),
      enableBatching: true,
      batchSize: 100,
      batchFlushInterval: Duration(seconds: 5),
      deduplicationWindow: Duration(minutes: 10),
      persistenceInterval: Duration(seconds: 15),
      backpressureStrategy: BackpressureStrategy.block,
      circuitBreakerThreshold: 10,
      circuitBreakerTimeout: Duration(seconds: 30),
      rateLimit: 500,
    );
  }
  
  /// Configuração para baixo consumo de recursos
  factory QueueConfig.lowResource() {
    return const QueueConfig(
      maxWorkers: 1,
      maxQueueSize: 1000,
      maxRetries: 2,
      retryStrategy: RetryStrategy.linear,
      fixedRetryDelay: Duration(seconds: 10),
      enableBatching: false,
      batchSize: 20,
      batchFlushInterval: Duration(seconds: 30),
      deduplicationWindow: Duration(minutes: 3),
      persistenceInterval: Duration(minutes: 1),
      backpressureStrategy: BackpressureStrategy.reject,
      circuitBreakerThreshold: 3,
      circuitBreakerTimeout: Duration(minutes: 2),
      rateLimit: 50,
    );
  }
  
  /// Cria cópia com valores modificados
  QueueConfig copyWith({
    int? maxWorkers,
    int? maxQueueSize,
    int? maxRetries,
    RetryStrategy? retryStrategy,
    Duration? fixedRetryDelay,
    bool? enableBatching,
    int? batchSize,
    Duration? batchFlushInterval,
    Duration? deduplicationWindow,
    Duration? persistenceInterval,
    BackpressureStrategy? backpressureStrategy,
    int? circuitBreakerThreshold,
    Duration? circuitBreakerTimeout,
    int? rateLimit,
  }) {
    return QueueConfig(
      maxWorkers: maxWorkers ?? this.maxWorkers,
      maxQueueSize: maxQueueSize ?? this.maxQueueSize,
      maxRetries: maxRetries ?? this.maxRetries,
      retryStrategy: retryStrategy ?? this.retryStrategy,
      fixedRetryDelay: fixedRetryDelay ?? this.fixedRetryDelay,
      enableBatching: enableBatching ?? this.enableBatching,
      batchSize: batchSize ?? this.batchSize,
      batchFlushInterval: batchFlushInterval ?? this.batchFlushInterval,
      deduplicationWindow: deduplicationWindow ?? this.deduplicationWindow,
      persistenceInterval: persistenceInterval ?? this.persistenceInterval,
      backpressureStrategy: backpressureStrategy ?? this.backpressureStrategy,
      circuitBreakerThreshold: circuitBreakerThreshold ?? this.circuitBreakerThreshold,
      circuitBreakerTimeout: circuitBreakerTimeout ?? this.circuitBreakerTimeout,
      rateLimit: rateLimit ?? this.rateLimit,
    );
  }
  
  @override
  String toString() {
    return 'QueueConfig(\n'
           '  maxWorkers: $maxWorkers\n'
           '  maxQueueSize: $maxQueueSize\n'
           '  maxRetries: $maxRetries\n'
           '  retryStrategy: ${retryStrategy.name}\n'
           '  enableBatching: $enableBatching\n'
           '  batchSize: $batchSize\n'
           '  circuitBreakerThreshold: $circuitBreakerThreshold\n'
           '  rateLimit: $rateLimit ops/s\n'
           ')';
  }
}

/// Estratégias de retry
enum RetryStrategy {
  /// Exponential backoff: 2^retry * base_delay
  exponential,
  
  /// Linear backoff: retry * base_delay
  linear,
  
  /// Fixed delay entre retries
  fixed,
  
  /// Exponential com jitter aleatório
  jittered,
}

/// Estratégias de backpressure
enum BackpressureStrategy {
  /// Rejeita novas operações quando fila está cheia
  reject,
  
  /// Remove operação mais antiga quando fila está cheia
  dropOldest,
  
  /// Bloqueia até ter espaço na fila
  block,
}
