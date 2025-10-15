// core/queue/circuit_breaker.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Circuit Breaker Pattern para prevenir falhas em cascata
/// 
/// Estados:
/// - CLOSED: Operação normal, requisições passam
/// - OPEN: Muitas falhas, requisições são bloqueadas
/// - HALF_OPEN: Testando recuperação, algumas requisições passam
class CircuitBreaker {
  final int failureThreshold;
  final Duration timeout;
  final Duration halfOpenTimeout;
  final void Function(CircuitBreakerState)? onStateChange;
  
  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  DateTime? _lastFailureTime;
  Timer? _resetTimer;
  
  CircuitBreaker({
    required this.failureThreshold,
    required this.timeout,
    Duration? halfOpenTimeout,
    this.onStateChange,
  }) : halfOpenTimeout = halfOpenTimeout ?? const Duration(seconds: 30);
  
  /// Estado atual do circuit breaker
  CircuitBreakerState get state => _state;
  
  /// Contador de falhas
  int get failureCount => _failureCount;
  
  /// Contador de sucessos
  int get successCount => _successCount;
  
  /// Verifica se pode executar operação
  bool get canExecute {
    switch (_state) {
      case CircuitBreakerState.closed:
        return true;
        
      case CircuitBreakerState.open:
        // Verificar se deve mudar para half-open
        if (_lastFailureTime != null) {
          final timeSinceFailure = DateTime.now().difference(_lastFailureTime!);
          
          if (timeSinceFailure >= timeout) {
            _transitionTo(CircuitBreakerState.halfOpen);
            return true;
          }
        }
        return false;
        
      case CircuitBreakerState.halfOpen:
        return true;
    }
  }
  
  /// Registra sucesso de operação
  void recordSuccess() {
    _successCount++;
    
    switch (_state) {
      case CircuitBreakerState.closed:
        // Reset do contador de falhas em caso de sucesso
        _failureCount = 0;
        break;
        
      case CircuitBreakerState.halfOpen:
        // Se teve sucesso em half-open, voltar para closed
        _transitionTo(CircuitBreakerState.closed);
        _failureCount = 0;
        _successCount = 0;
        break;
        
      case CircuitBreakerState.open:
        // Não deveria chegar aqui, mas por segurança
        break;
    }
  }
  
  /// Registra falha de operação
  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    switch (_state) {
      case CircuitBreakerState.closed:
        if (_failureCount >= failureThreshold) {
          _transitionTo(CircuitBreakerState.open);
          _scheduleReset();
        }
        break;
        
      case CircuitBreakerState.halfOpen:
        // Falhou em half-open, voltar para open
        _transitionTo(CircuitBreakerState.open);
        _scheduleReset();
        break;
        
      case CircuitBreakerState.open:
        // Já está aberto, apenas atualizar timestamp
        _scheduleReset();
        break;
    }
  }
  
  /// Força reset do circuit breaker
  void reset() {
    _transitionTo(CircuitBreakerState.closed);
    _failureCount = 0;
    _successCount = 0;
    _lastFailureTime = null;
    _resetTimer?.cancel();
  }
  
  /// Força abertura do circuit breaker
  void forceOpen() {
    _transitionTo(CircuitBreakerState.open);
    _scheduleReset();
  }
  
  /// Transição de estado
  void _transitionTo(CircuitBreakerState newState) {
    if (_state != newState) {
      final oldState = _state;
      _state = newState;
      
      if (kDebugMode) {
        debugPrint('Circuit Breaker: $oldState → $newState');
      }
      
      onStateChange?.call(newState);
    }
  }
  
  /// Agenda reset automático
  void _scheduleReset() {
    _resetTimer?.cancel();
    
    _resetTimer = Timer(timeout, () {
      if (_state == CircuitBreakerState.open) {
        _transitionTo(CircuitBreakerState.halfOpen);
        
        // Agendar volta para open se não houver atividade
        Timer(halfOpenTimeout, () {
          if (_state == CircuitBreakerState.halfOpen) {
            _transitionTo(CircuitBreakerState.open);
            _scheduleReset();
          }
        });
      }
    });
  }
  
  /// Obtém métricas do circuit breaker
  CircuitBreakerMetrics getMetrics() {
    return CircuitBreakerMetrics(
      state: _state,
      failureCount: _failureCount,
      successCount: _successCount,
      lastFailureTime: _lastFailureTime,
    );
  }
  
  /// Libera recursos
  void dispose() {
    _resetTimer?.cancel();
  }
}

/// Estados do circuit breaker
enum CircuitBreakerState {
  /// Circuito fechado - operando normalmente
  closed,
  
  /// Circuito aberto - bloqueando requisições
  open,
  
  /// Circuito semi-aberto - testando recuperação
  halfOpen,
}

/// Métricas do circuit breaker
class CircuitBreakerMetrics {
  final CircuitBreakerState state;
  final int failureCount;
  final int successCount;
  final DateTime? lastFailureTime;
  
  CircuitBreakerMetrics({
    required this.state,
    required this.failureCount,
    required this.successCount,
    this.lastFailureTime,
  });
  
  double get errorRate {
    final total = failureCount + successCount;
    return total > 0 ? (failureCount / total) * 100 : 0.0;
  }
  
  @override
  String toString() {
    return 'CircuitBreakerMetrics(\n'
           '  state: ${state.name}\n'
           '  failures: $failureCount\n'
           '  successes: $successCount\n'
           '  errorRate: ${errorRate.toStringAsFixed(1)}%\n'
           '  lastFailure: ${lastFailureTime ?? "Never"}\n'
           ')';
  }
}
