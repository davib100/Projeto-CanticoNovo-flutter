import 'package:flutter/foundation.dart';

/// Configuração para o QueueManager
@immutable
class QueueConfig {
  /// Número de operações concorrentes por fila de prioridade.
  final int concurrency;

  /// Atraso entre o processamento de itens na fila.
  final Duration processingDelay;

  /// Atraso antes de tentar novamente uma operação com falha.
  final Duration retryDelay;

  /// Número máximo de tentativas para uma operação com falha.
  final int maxRetries;

  const QueueConfig({
    this.concurrency = 4,
    this.processingDelay = const Duration(milliseconds: 100),
    this.retryDelay = const Duration(seconds: 30),
    this.maxRetries = 3,
  });

  /// Configurações padrão.
  factory QueueConfig.defaults() => const QueueConfig(
        concurrency: 6,
        processingDelay: Duration.zero,
        retryDelay: Duration(seconds: 60),
        maxRetries: 5,
      );

  QueueConfig copyWith({
    int? concurrency,
    Duration? processingDelay,
    Duration? retryDelay,
    int? maxRetries,
  }) {
    return QueueConfig(
      concurrency: concurrency ?? this.concurrency,
      processingDelay: processingDelay ?? this.processingDelay,
      retryDelay: retryDelay ?? this.retryDelay,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }
}
