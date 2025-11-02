import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Provides a singleton instance of the [Logger] throughout the application.
///
/// Supports dependency injection via Riverpod, while maintaining backward
/// compatibility for legacy code using static or direct instantiation.
final loggerProvider = Provider<Logger>((ref) {
  return ConsoleLogger();
});

/// Defines the severity levels for log entries.
enum LogLevel {
  info(800, 'INFO'),
  warning(900, 'WARNING'),
  error(1000, 'SEVERE');

  const LogLevel(this.value, this.name);
  final int value;
  final String name;
}

/// Abstract contract for the application logging system.
abstract class Logger {
  /// Minimum level threshold for logs to be recorded.
  LogLevel get minLevel;

  /// Generates a correlation ID for request tracing across modules.
  String generateCorrelationId();

  /// Logs an informational message.
  void info(String message, {Object? data, String? correlationId});

  /// Logs a warning message.
  void warning(String message,
      {Object? error, StackTrace? stackTrace, String? correlationId});

  /// Logs an error message.
  void error(String message,
      [Object? error, StackTrace? stackTrace, String? correlationId]);

  /// Legacy aliases (for backward compatibility)
  void log(String message, {Object? data}) => info(message, data: data);
  void logInfo(String message, {Object? data}) => info(message, data: data);
  void logWarning(String message,
          {Object? error, StackTrace? stackTrace}) =>
      warning(message, error: error, stackTrace: stackTrace);
  void logError(String message, [Object? err, StackTrace? stackTrace]) =>
    error(message, err, stackTrace);
}

/// Console-based implementation of [Logger].
///
/// Uses `dart:developer.log` for structured logging compatible with Dart DevTools.
/// Adds correlation ID tracing and level filtering.
class ConsoleLogger implements Logger {
  static final ConsoleLogger instance = ConsoleLogger._internal();
  factory ConsoleLogger() => instance;

  ConsoleLogger._internal();

  /// Application name for log namespace.
  final String _appName = 'CanticoNovoApp';

  /// Configurable minimum log level (default = info)
  @override
  final LogLevel minLevel = LogLevel.info;

  /// UUID generator for correlation IDs.
  final _uuid = const Uuid();

  @override
  String generateCorrelationId() => _uuid.v4();

  bool _shouldLog(LogLevel level) => level.value >= minLevel.value;

  @override
  void info(String message, {Object? data, String? correlationId}) {
    _log(
      level: LogLevel.info,
      message: message,
      data: data,
      correlationId: correlationId,
    );
  }

  @override
  void warning(String message,
      {Object? error, StackTrace? stackTrace, String? correlationId}) {
    _log(
      level: LogLevel.warning,
      message: message,
      error: error,
      stackTrace: stackTrace,
      correlationId: correlationId,
    );
  }

  @override
  void error(String message,
      [Object? error, StackTrace? stackTrace, String? correlationId]) {
    _log(
      level: LogLevel.error,
      message: message,
      error: error,
      stackTrace: stackTrace,
      correlationId: correlationId,
    );
  }

  /// Core logging method.
  void _log({
    required LogLevel level,
    required String message,
    Object? data,
    Object? error,
    StackTrace? stackTrace,
    String? correlationId,
  }) {
    if (!_shouldLog(level)) return;

    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer('[$timestamp] ${level.name}: $message');

    if (correlationId != null) buffer.write(' | CID: $correlationId');
    if (data != null) buffer.write(' | Data: $data');
    if (error != null) buffer.write(' | Error: $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');

    developer.log(
      buffer.toString(),
      name: '$_appName.${level.name}',
      level: level.value,
      error: error,
      stackTrace: stackTrace,
    );
  }

  // -----------------------
  // Legacy support methods
  // -----------------------
  @override
  void log(String message, {Object? data}) => info(message, data: data);

  @override
  void logInfo(String message, {Object? data}) => info(message, data: data);

  @override
  void logWarning(String message,
          {Object? error, StackTrace? stackTrace}) =>
      warning(message, error: error, stackTrace: stackTrace);

  @override
void logError(String message, [Object? exception, StackTrace? stackTrace]) =>
    error(message, exception, stackTrace);

}
