// core/queue/rate_limiter.dart
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rate Limiter usando Token Bucket Algorithm
///
/// Permite controlar a taxa de execução de operações,
/// prevenindo sobrecarga do sistema
class RateLimiter {
  final int maxTokens;
  final Duration refillRate;
  final bool allowBurst;

  int _currentTokens;
  DateTime _lastRefillTime;
  final Queue<DateTime> _requestHistory = Queue<DateTime>();

  RateLimiter({
    required this.maxTokens,
    required this.refillRate,
    this.allowBurst = true,
  })  : _currentTokens = maxTokens,
        _lastRefillTime = DateTime.now();

  /// Número de tokens disponíveis
  int get availableTokens {
    _refillTokens();
    return _currentTokens;
  }

  /// Taxa de requisições por segundo (últimos 60s)
  double get requestRate {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 60));

    // Limpar requisições antigas
    _requestHistory.removeWhere((time) => time.isBefore(cutoff));

    return _requestHistory.length / 60.0;
  }

  /// Tenta adquirir um token
  bool tryAcquire({int tokens = 1}) {
    if (tokens < 1) {
      throw ArgumentError('Tokens must be at least 1');
    }

    _refillTokens();

    if (_currentTokens >= tokens) {
      _currentTokens -= tokens;
      _requestHistory.add(DateTime.now());
      return true;
    }

    return false;
  }

  /// Adquire token (bloqueante - aguarda até ter disponível)
  Future<void> acquire({int tokens = 1}) async {
    while (!tryAcquire(tokens: tokens)) {
      // Calcular quanto tempo até próximo refill
      final now = DateTime.now();
      final timeSinceRefill = now.difference(_lastRefillTime);
      final timeUntilRefill = refillRate - timeSinceRefill;

      if (timeUntilRefill.isNegative) {
        // Refill deveria ter ocorrido, tentar novamente
        continue;
      }

      // Aguardar até próximo refill
      await Future.delayed(timeUntilRefill);
    }
  }

  /// Refill de tokens baseado no tempo decorrido
  void _refillTokens() {
    final now = DateTime.now();
    final timeSinceRefill = now.difference(_lastRefillTime);

    if (timeSinceRefill >= refillRate) {
      // Calcular quantos refills ocorreram
      final refills =
          timeSinceRefill.inMicroseconds ~/ refillRate.inMicroseconds;

      if (allowBurst) {
        // Refill completo (permite burst)
        _currentTokens = maxTokens;
      } else {
        // Refill gradual
        _currentTokens = (_currentTokens + refills).clamp(0, maxTokens);
      }

      _lastRefillTime = now;
    }
  }

  /// Reset do rate limiter
  void reset() {
    _currentTokens = maxTokens;
    _lastRefillTime = DateTime.now();
    _requestHistory.clear();
  }

  /// Obtém métricas do rate limiter
  RateLimiterMetrics getMetrics() {
    return RateLimiterMetrics(
      availableTokens: availableTokens,
      maxTokens: maxTokens,
      requestRate: requestRate,
      utilizationRate:
          ((maxTokens - availableTokens) / maxTokens * 100).toInt(),
    );
  }
}

/// Métricas do rate limiter
class RateLimiterMetrics {
  final int availableTokens;
  final int maxTokens;
  final double requestRate;
  final int utilizationRate;

  RateLimiterMetrics({
    required this.availableTokens,
    required this.maxTokens,
    required this.requestRate,
    required this.utilizationRate,
  });

  @override
  String toString() {
    return 'RateLimiterMetrics(\n'
        '  available: $availableTokens/$maxTokens\n'
        '  requestRate: ${requestRate.toStringAsFixed(2)} req/s\n'
        '  utilization: ${utilizationRate.toStringAsFixed(1)}%\n'
        ')';
  }
}

/// Rate Limiter usando Sliding Window
///
/// Alternativa ao Token Bucket, mais preciso para janelas de tempo fixas
class SlidingWindowRateLimiter {
  final int maxRequests;
  final Duration windowSize;

  final Queue<DateTime> _requestTimestamps = Queue<DateTime>();

  SlidingWindowRateLimiter({
    required this.maxRequests,
    required this.windowSize,
  });

  /// Tenta adquirir permissão
  bool tryAcquire() {
    final now = DateTime.now();
    final windowStart = now.subtract(windowSize);

    // Remover timestamps fora da janela
    while (_requestTimestamps.isNotEmpty &&
        _requestTimestamps.first.isBefore(windowStart)) {
      _requestTimestamps.removeFirst();
    }

    // Verificar se pode adicionar nova requisição
    if (_requestTimestamps.length < maxRequests) {
      _requestTimestamps.add(now);
      return true;
    }

    return false;
  }

  /// Número de requisições na janela atual
  int get currentRequests {
    final now = DateTime.now();
    final windowStart = now.subtract(windowSize);

    return _requestTimestamps.where((time) => time.isAfter(windowStart)).length;
  }

  /// Capacidade restante
  int get remainingCapacity => maxRequests - currentRequests;

  /// Reset do limiter
  void reset() {
    _requestTimestamps.clear();
  }
}
class KeyedRateLimiter {
  final Map<String, List<DateTime>> _attempts = {};

  /// Tenta adquirir permissão para uma chave específica.
  Future<bool> tryAcquire(
    String key, {
    int maxAttempts = 5,
    Duration window = const Duration(minutes: 15),
  }) async {
    final now = DateTime.now();
    final attempts = _attempts[key] ?? [];

    // Remover tentativas que já expiraram (fora da janela de tempo)
    attempts.removeWhere((attempt) => now.difference(attempt) > window);

    if (attempts.length >= maxAttempts) {
      _attempts[key] = attempts;
      return false; // Limite excedido
    }

    attempts.add(now);
    _attempts[key] = attempts;
    return true; // Permissão concedida
  }

  /// Registra uma tentativa falha para a chave,
  /// contribuindo para o limite sem conceder permissão.
  void recordFailure(String key) {
    final attempts = _attempts[key] ?? [];
    attempts.add(DateTime.now());
    _attempts[key] = attempts;
  }

  /// Reseta o contador de tentativas para uma chave.
  void reset(String key) {
    _attempts.remove(key);
  }

  /// Calcula o tempo restante até que uma nova tentativa seja permitida.
  Duration getRetryAfter(String key, {Duration window = const Duration(minutes: 15)}) {
    final attempts = _attempts[key];
    if (attempts == null || attempts.isEmpty) {
      return Duration.zero;
    }
    
    // Encontra a tentativa mais antiga dentro da janela atual
    final now = DateTime.now();
    final validAttempts = attempts.where((a) => now.difference(a) <= window).toList();

    if (validAttempts.isEmpty) {
        return Duration.zero;
    }

    final oldestAttempt = validAttempts.first;
    final elapsed = now.difference(oldestAttempt);

    return (window - elapsed).isNegative ? Duration.zero : window - elapsed;
  }
}

/// Provider do Riverpod para disponibilizar uma instância única
/// do KeyedRateLimiter na aplicação.
final keyedRateLimiterProvider = Provider<KeyedRateLimiter>((ref) => KeyedRateLimiter());
