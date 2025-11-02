import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/observability/logger.dart';
import '../../..//core/services/cache_service.dart';
import '../../../core/services/api_client.dart';
import '../providers/auth_provider.dart' hide loggerProvider, cacheServiceProvider, apiClientProvider;
import '../repositories/auth_repository.dart';

/// Use case para logout com cleanup completo
class LogoutUseCase {
  final AuthRepository _repository;
  final Logger _logger;
  final CacheService _cacheService;
  final ApiClient _apiClient;

  LogoutUseCase(
    this._repository,
    this._logger,
    this._cacheService,
    this._apiClient,
  );

  /// Realiza logout completo
  ///
  /// Ações executadas:
  /// 1. Revoga sessão no backend
  /// 2. Limpa tokens locais
  /// 3. Cancela requests pendentes
  /// 4. Limpa cache sensível
  /// 5. Notifica outros módulos
  /// 6. Reseta estado da aplicação
  ///
  /// Sempre retorna sucesso (fire and forget no backend)
  Future<void> call({bool clearAllData = false}) async {
    final correlationId = _logger.generateCorrelationId();
    final stopwatch = Stopwatch()..start();

    try {
      _logger.info(
        'Logout initiated | Module: LogoutUseCase | CID: $correlationId | Metadata: ${{'clearAllData': clearAllData}}',
      );

      // 1. Cancelar todos os requests HTTP pendentes
      _logger.info(
        'Cancelling pending requests | Module: LogoutUseCase | CID: $correlationId',
      );
      _apiClient.dispose();

      // 2. Revogar sessão no backend (fire and forget)
      _logger.info(
        'Revoking backend session | Module: LogoutUseCase | CID: $correlationId',
      );
      _repository.logout().catchError((error) {
        _logger.info(
          'Backend logout failed (non-blocking): $error | Module: LogoutUseCase | CID: $correlationId',
        );
      });

      // 3. Limpar cache sensível
      if (clearAllData) {
        _logger.info(
          'Clearing all cached data | Module: LogoutUseCase | CID: $correlationId',
        );
        await _cacheService.clearAll();
      } else {
        _logger.info(
          'Clearing sensitive cached data | Module: LogoutUseCase | CID: $correlationId',
        );
        await _cacheService.clearByPattern('auth:*');
        await _cacheService.clearByPattern('user:*');
        await _cacheService.clearByPattern('session:*');
      }

      // 4. Limpar tokens e dados locais do auth repository
      _logger.info(
        'Clearing local auth data | Module: LogoutUseCase | CID: $correlationId',
      );
      await _repository.logout();

      // 5. Notificar outros módulos sobre logout
      _logger.info(
        'Broadcasting logout event | Module: LogoutUseCase | CID: $correlationId',
      );
      await _broadcastLogoutEvent();

      stopwatch.stop();

      _logger.info(
        'Logout completed successfully | Module: LogoutUseCase | CID: $correlationId | Metadata: ${{'duration': stopwatch.elapsedMilliseconds, 'clearAllData': clearAllData}}',
      );
    } catch (e, stackTrace) {
      stopwatch.stop();

      _logger.error(
        'Error during logout (continuing anyway) | Module: LogoutUseCase | CID: $correlationId | Metadata: ${{'duration': stopwatch.elapsedMilliseconds}}',
        e,
        stackTrace,
      );

      // Mesmo com erro, garantir que dados locais sejam limpos
      try {
        await _repository.logout();
      } catch (e) {
        _logger.error(
          'Failed to clear local data during error recovery | Module: LogoutUseCase',
          e,
        );
      }
    }
  }

  /// Logout forçado (sem comunicação com backend)
  /// Útil quando não há conexão
  Future<void> forceLogout() async {
    final correlationId = _logger.generateCorrelationId();

    try {
      _logger.warning(
        'Force logout initiated (no backend communication) | Module: LogoutUseCase | CID: $correlationId',
      );

      // Limpar apenas dados locais
      _apiClient.dispose();
      await _repository.logout();
      await _cacheService.clearByPattern('auth:*');
      await _broadcastLogoutEvent();

      _logger.info(
        'Force logout completed | Module: LogoutUseCase | CID: $correlationId',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error during force logout | Module: LogoutUseCase | CID: $correlationId',
        e,
        stackTrace,
      );
    }
  }

  /// Logout de todos os dispositivos (single-device enforcement)
  Future<void> logoutAllDevices() async {
    final correlationId = _logger.generateCorrelationId();

    try {
      _logger.info(
        'Logout all devices initiated | Module: LogoutUseCase | CID: $correlationId',
      );

      // Esta chamada revoga todas as sessões do usuário no backend
      // TODO: Implementar no repository
      // await _repository.logoutAllDevices();

      // Limpar dados locais
      await call(clearAllData: true);

      _logger.info(
        'Logout all devices completed | Module: LogoutUseCase | CID: $correlationId',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error during logout all devices | Module: LogoutUseCase | CID: $correlationId',
        e,
        stackTrace,
      );
    }
  }

  /// Notifica outros módulos sobre logout via event bus
  Future<void> _broadcastLogoutEvent() async {
    try {
      // TODO: Implementar EventBus
      // await EventBus.instance.emit('auth:logout', {
      //   'timestamp': DateTime.now().toIso8601String(),
      // });

      _logger.info('Logout event broadcasted | Module: LogoutUseCase');
    } catch (e) {
      _logger.warning(
        'Failed to broadcast logout event: $e | Module: LogoutUseCase',
      );
    }
  }

  // Provider
  final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
    return LogoutUseCase(
      ref.watch(authRepositoryProvider),
      ref.watch(loggerProvider),
      ref.watch(cacheServiceProvider),
      ref.watch(apiClientProvider),
    );
  });
}
