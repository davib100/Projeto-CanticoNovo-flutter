// core/observability/observability_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Serviço centralizado de observabilidade com Sentry
class ObservabilityService {
  static final ObservabilityService _instance = ObservabilityService._internal();
  factory ObservabilityService() => _instance;
  ObservabilityService._internal();

  bool _isInitialized = false;
  PackageInfo? _packageInfo;
  String? _deviceInfo;

  final List<BootLogEntry> _bootLogs = [];
  final List<Breadcrumb> _customBreadcrumbs = [];

  /// Verifica se o serviço foi inicializado
  bool get isInitialized => _isInitialized;

  /// Obtém os logs de boot
  List<BootLogEntry> get bootLogs => List.unmodifiable(_bootLogs);

  /// Inicializa o Sentry
  Future<void> initSentry({
    String? dsn,
    String environment = 'production',
    double tracesSampleRate = 1.0,
    double profilesSampleRate = 1.0,
    bool enableAutoSessionTracking = true,
    bool attachStacktrace = true,
    bool enableAutoPerformanceTracing = true,
    bool enableUserInteractionTracing = true,
    List<String>? inAppIncludes,
  }) async {
    if (_isInitialized) {
      if (kDebugMode) {
        debugPrint('⚠️  ObservabilityService already initialized');
      }
      return;
    }

    try {
      // Carregar informações do app
      _packageInfo = await PackageInfo.fromPlatform();
      _deviceInfo = await _getDeviceInfo();

      await SentryFlutter.init(
        (options) {
          // DSN (obrigatório)
          options.dsn = dsn ?? _getDefaultDsn();

          // Ambiente
          options.environment = environment;

          // Release e distribuição
          options.release = '${_packageInfo?.packageName}@${_packageInfo?.version}';
          options.dist = _packageInfo?.buildNumber;

          // Sampling
          options.tracesSampleRate = tracesSampleRate;
          options.profilesSampleRate = profilesSampleRate;

          // Performance
          options.enableAutoSessionTracking = enableAutoSessionTracking;
          options.enableAutoPerformanceTracing = enableAutoPerformanceTracing;
          options.enableUserInteractionTracing = enableUserInteractionTracing;

          // Stack traces
          options.attachStacktrace = attachStacktrace;
          options.attachScreenshot = true;
          options.screenshotQuality = SentryScreenshotQuality.high;

          // In-app includes
          if (inAppIncludes != null) {
            for (var i = 0; i < inAppIncludes.length; i++) {
              options.addInAppInclude(inAppIncludes[i]);
            }
          }

          // Filtros e callbacks
          options.beforeSend = _beforeSend;
          options.beforeBreadcrumb = _beforeBreadcrumb;

          // Debug
          options.debug = kDebugMode;

          if (kDebugMode) {
            debugPrint('🔍 Sentry initialized:');
            debugPrint('   Environment: $environment');
            debugPrint('   Release: ${options.release}');
            debugPrint('   Traces Sample Rate: ${tracesSampleRate * 100}%');
          }
        },
      );

      // Configurar contexto global
      await _setupGlobalContext();

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ ObservabilityService initialized successfully');
      }

    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize ObservabilityService: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  /// Captura uma exceção
  Future<SentryId> captureException(
    dynamic exception, {
    dynamic stackTrace,
    String? hint,
    Map<String, dynamic>? extra,
    String? endpoint,
    SentryLevel level = SentryLevel.error,
  }) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        debugPrint('⚠️  ObservabilityService not initialized. Exception not captured.');
      }
      return SentryId.empty();
    }

    try {
      return await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        hint: hint != null ? Hint.withMap({'hint': hint}) : null,
        withScope: (scope) {
          // Adicionar contexto extra
          if (extra != null) {
            scope.setContexts('extra', extra);
          }

          if (endpoint != null) {
            scope.setTag('endpoint', endpoint);
          }

          scope.level = level;

          // Adicionar breadcrumbs customizados
          for (final breadcrumb in _customBreadcrumbs) {
            scope.addBreadcrumb(breadcrumb);
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error capturing exception: $e');
      }
      return SentryId.empty();
    }
  }

  /// Captura uma mensagem
  Future<SentryId> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? extra,
    List<String>? tags,
  }) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        debugPrint('⚠️  ObservabilityService not initialized. Message not captured.');
      }
      return SentryId.empty();
    }

    return await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        if (extra != null) {
          scope.setContexts('extra', extra);
        }

        if (tags != null) {
          for (final tag in tags) {
            final parts = tag.split(':');
            if (parts.length == 2) {
              scope.setTag(parts[0].trim(), parts[1].trim());
            }
          }
        }
      },
    );
  }

  /// Adiciona um breadcrumb
  void addBreadcrumb(
    String message, {
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
    DateTime? timestamp,
  }) {
    if (!_isInitialized) return;

    final breadcrumb = Breadcrumb(
      message: message,
      category: category,
      level: level,
      data: data,
      timestamp: timestamp ?? DateTime.now(),
    );

    _customBreadcrumbs.add(breadcrumb);
    Sentry.addBreadcrumb(breadcrumb);

    // Manter apenas os últimos 50 breadcrumbs
    if (_customBreadcrumbs.length > 50) {
      _customBreadcrumbs.removeAt(0);
    }
  }

  /// Loga evento de boot do módulo
  void logBoot({
    required DateTime timestamp,
    required String module,
    required String persistence,
    required String action,
    required String status,
  }) {
    final entry = BootLogEntry(
      timestamp: timestamp,
      module: module,
      persistence: persistence,
      action: action,
      status: status,
    );

    _bootLogs.add(entry);

    // Adicionar como breadcrumb
    addBreadcrumb(
      'Module boot: $module',
      category: 'boot',
      level: status.contains('✅') ? SentryLevel.info : SentryLevel.error,
      data: {
        'module': module,
        'persistence': persistence,
        'action': action,
        'status': status,
        'duration_ms': DateTime.now().difference(timestamp).inMilliseconds,
      },
    );

    // Se houver erro, criar transaction
    if (status.contains('❌')) {
      final transaction = Sentry.startTransaction(
        'module.boot.failure',
        'boot',
      );

      transaction.setData('module', module);
      transaction.setData('persistence', persistence);
      transaction.setData('action', action);

      transaction.finish(status: SpanStatus.internalError());
    }
  }

  /// Inicia uma transação
  ISentrySpan startTransaction(
    String name,
    String operation, {
    String? description,
    Map<String, dynamic>? data,
    bool bindToScope = true,
  }) {
    if (!_isInitialized) {
      return NoOpSentrySpan();
    }

    final transaction = Sentry.startTransaction(
      name,
      operation,
      description: description,
      bindToScope: bindToScope,
    );

    if (data != null) {
      data.forEach((key, value) {
        transaction.setData(key, value);
      });
    }

    return transaction;
  }

  /// Cria um span filho
  ISentrySpan? startChild(
    String operation, {
    String? description,
    Map<String, dynamic>? data,
  }) {
    final span = Sentry.getSpan();
    if (span == null) return null;

    final child = span.startChild(
      operation,
      description: description,
    );

    if (data != null) {
      data.forEach((key, value) {
        child.setData(key, value);
      });
    }

    return child;
  }

  /// Define o usuário atual
  Future<void> setUser({
    required String id,
    String? email,
    String? username,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized) return;

    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: id,
        email: email,
        username: username,
        data: data,
      ));
    });
  }

  /// Remove o usuário atual
  Future<void> clearUser() async {
    if (!_isInitialized) return;

    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Define uma tag global
  Future<void> setTag(String key, String value) async {
    if (!_isInitialized) return;

    await Sentry.configureScope((scope) {
      scope.setTag(key, value);
    });
  }

  /// Define contexto extra global
  Future<void> setExtra(String key, dynamic value) async {
    if (!_isInitialized) return;

    await Sentry.configureScope((scope) {
      scope.setContexts(key, value);
    });
  }

  /// Define contexto customizado
  Future<void> setContext(String key, Map<String, dynamic> context) async {
    if (!_isInitialized) return;

    await Sentry.configureScope((scope) {
      scope.setContexts(key, context);
    });
  }

  /// Registra uma métrica de performance
  void recordMetric(
    String name,
    num value, {
    SentryMeasurementUnit? unit,
    Map<String, dynamic>? tags,
  }) {
    final span = Sentry.getSpan();
    if (span == null) return;

    span.setMeasurement(name, value, unit: unit ?? SentryMeasurementUnit.none);

    if (tags != null && kDebugMode) {
      debugPrint('📊 Metric recorded: $name = $value ${unit?.name ?? 'none'}');
    }
  }

  /// Configura contexto global
  Future<void> _setupGlobalContext() async {
    await Sentry.configureScope((scope) {
      // Device context
      if (_deviceInfo != null) {
        scope.setContexts('device_details', {
          'info': _deviceInfo,
        });
      }

      // App context
      if (_packageInfo != null) {
        scope.setContexts('app', {
          'app_name': _packageInfo!.appName,
          'package_name': _packageInfo!.packageName,
          'version': _packageInfo!.version,
          'build_number': _packageInfo!.buildNumber,
        });
      }

      // Runtime context
      scope.setContexts('runtime', {
        'name': 'Flutter',
        'version': kDebugMode ? 'debug' : 'release',
      });
    });
  }

 /// Callback antes de enviar evento
FutureOr<SentryEvent?> _beforeSend(SentryEvent event, Hint hint) {
  // Adicionar informações extras aos eventos
  if (kDebugMode) {
    debugPrint('📤 Sending event to Sentry: ${event.eventId}');
    debugPrint('   Level: ${event.level}');
    debugPrint('   Message: ${event.message?.formatted}');
  }

  // Filtrar eventos sensíveis em produção
  if (!kDebugMode && event.message?.formatted.contains('password') == true) {
    return null; // Não enviar
  }

  return event;
}

/// Callback antes de adicionar breadcrumb
Breadcrumb? _beforeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null) return null;

  // Filtrar breadcrumbs sensíveis
  if (breadcrumb.data?.containsKey('password') == true) {
    final newData = Map<String, dynamic>.from(breadcrumb.data!);
    newData.remove('password');

    return Breadcrumb(
      message: breadcrumb.message,
      category: breadcrumb.category,
      level: breadcrumb.level,
      type: breadcrumb.type,
      timestamp: breadcrumb.timestamp,
      data: newData,
    );
  }

  return breadcrumb;
}

  /// Obtém DSN padrão (deve ser configurado em environment variables)
  String _getDefaultDsn() {
    return const String.fromEnvironment(
      'SENTRY_DSN',
      defaultValue: '',
    );
  }

  /// Obtém informações do dispositivo
  Future<String> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model} (Android ${androidInfo.version.release})';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.model} (iOS ${iosInfo.systemVersion})';
      }

      return 'Unknown device';
    } catch (e) {
      return 'Error getting device info';
    }
  }

  /// Gera relatório de observabilidade
  ObservabilityReport generateReport() {
    return ObservabilityReport(
      isInitialized: _isInitialized,
      bootLogs: _bootLogs,
      breadcrumbsCount: _customBreadcrumbs.length,
      packageInfo: _packageInfo,
      deviceInfo: _deviceInfo,
    );
  }

  /// Fecha o serviço
  Future<void> close() async {
    if (!_isInitialized) return;

    await Sentry.close();
    _isInitialized = false;
    _bootLogs.clear();
    _customBreadcrumbs.clear();

    if (kDebugMode) {
      debugPrint('🔒 ObservabilityService closed');
    }
  }
}

/// Entrada de log de boot
class BootLogEntry {
  final DateTime timestamp;
  final String module;
  final String persistence;
  final String action;
  final String status;

  BootLogEntry({
    required this.timestamp,
    required this.module,
    required this.persistence,
    required this.action,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'module': module,
      'persistence': persistence,
      'action': action,
      'status': status,
    };
  }

  @override
  String toString() {
    return '${timestamp.toIso8601String()} | $module | $persistence | $action | $status';
  }
}

/// Relatório de observabilidade
class ObservabilityReport {
  final bool isInitialized;
  final List<BootLogEntry> bootLogs;
  final int breadcrumbsCount;
  final PackageInfo? packageInfo;
  final String? deviceInfo;

  ObservabilityReport({
    required this.isInitialized,
    required this.bootLogs,
    required this.breadcrumbsCount,
    this.packageInfo,
    this.deviceInfo,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('     OBSERVABILITY REPORT');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('Initialized:       ${isInitialized ? "✅ Yes" : "❌ No"}');
    buffer.writeln('Boot Logs:         ${bootLogs.length}');
    buffer.writeln('Breadcrumbs:       $breadcrumbsCount');

    if (packageInfo != null) {
      buffer.writeln();
      buffer.writeln('App Info:');
      buffer.writeln('  Name:            ${packageInfo!.appName}');
      buffer.writeln('  Version:         ${packageInfo!.version}');
      buffer.writeln('  Build:           ${packageInfo!.buildNumber}');
    }

    if (deviceInfo != null) {
      buffer.writeln();
      buffer.writeln('Device:            $deviceInfo');
    }

    if (bootLogs.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('═══════════════════════════════════════');
      buffer.writeln('Boot Sequence:');
      buffer.writeln('───────────────────────────────────────');

      for (final log in bootLogs) {
        buffer.writeln(log);
      }
    }

    buffer.writeln('═══════════════════════════════════════');

    return buffer.toString();
  }
}

/// A no-op implementation of [ISentrySpan] for when Sentry is not initialized.
class NoOpSentrySpan implements ISentrySpan {
  @override
  Future<void> finish({DateTime? endTimestamp, Hint? hint, SpanStatus? status}) async {}

  @override
  void removeData(String key) {}

  @override
  void removeTag(String key) {}

  @override
  void setData(String key, value) {}

  @override
  void setMeasurement(String name, num value, {SentryMeasurementUnit? unit}) {}

  @override
  void setTag(String key, String value) {}

  @override
  ISentrySpan startChild(String operation, {String? description, DateTime? startTimestamp}) {
    return this;
  }

  @override
  SpanStatus? get status => null;

  @override
  set status(SpanStatus? status) {}

  @override
  SentryTraceHeader toSentryTrace() {
    return SentryTraceHeader(SentryId.empty(), SpanId.empty());
  }

  @override
  SentrySpanContext get context => SentrySpanContext(
        traceId: SentryId.empty(),
        spanId: SpanId.empty(),
        parentSpanId: SpanId.empty(),
        operation: 'noop',
      );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);


  @override
  SentryTraceContextHeader? traceContext() {
  return null;
}

  @override
  SentryTracesSamplingDecision? get samplingDecision => null;

  @override
  bool get finished => true;

  @override
  Future<void> scheduleFinish() async {}

  @override
  SentryBaggageHeader? toBaggageHeader() => null;

  @override
  String get origin => 'auto.ui.noop';

  @override
  set origin(String? origin) {}

  @override
  dynamic get throwable => null;

  @override
  set throwable(dynamic throwable) {}

  @override
  DateTime get startTimestamp => DateTime(1970);

  @override
  DateTime? get endTimestamp => DateTime(1970);
}
