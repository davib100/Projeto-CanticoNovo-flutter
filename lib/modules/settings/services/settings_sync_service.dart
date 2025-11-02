
// /modules/settings/services/settings_sync_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/observability/logger.dart';
import '../../../core/config/api_config.dart';
import '../models/settings_model.dart';
import '../repositories/settings_repository.dart';

/// Serviço de sincronização de configurações com o backend
/// Implementa sincronização bidirecional (push/pull) e detecção de conflitos
class SettingsSyncService {
  final http.Client _httpClient;
  final SettingsRepository _repository;
  final AuthService _authService;
  final AppLogger _logger;
  final Connectivity _connectivity;

  SettingsSyncService({
    required http.Client httpClient,
    required SettingsRepository repository,
    required AuthService authService,
    required AppLogger logger,
    Connectivity? connectivity,
  })  : _httpClient = httpClient,
        _repository = repository,
        _authService = authService,
        _logger = logger,
        _connectivity = connectivity ?? Connectivity();

  /// Sincroniza configurações locais com o servidor (PUSH)
  Future<SyncResult> pushSettings(SettingsModel settings) async {
    try {
      _logger.info('SettingsSyncService', '⬆️ Iniciando push de configurações');

      // Verifica conectividade
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _logger.warn('SettingsSyncService', '📡 Sem conexão - push cancelado');
        return SyncResult.noConnection();
      }

      // Obtém token de autenticação
      final token = await _authService.getAccessToken();
      if (token == null) {
        _logger.error('SettingsSyncService', '🔒 Token não encontrado');
        return SyncResult.authError();
      }

      // Envia para o backend
      final response = await _httpClient.put(
        Uri.parse('${ApiConfig.baseUrl}/api/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(settings.toJson()),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Timeout ao sincronizar'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.success('SettingsSyncService', '✅ Push concluído com sucesso');

        // Atualiza timestamp de sincronização
        final updatedSettings = settings.copyWith(lastSync: DateTime.now());
        await _repository.saveSettings(updatedSettings);

        return SyncResult.success(updatedSettings);
      } else if (response.statusCode == 409) {
        // Conflito detectado - servidor tem versão mais recente
        _logger.warn('SettingsSyncService', '⚠️ Conflito detectado - executando pull');
        return await pullSettings();
      } else {
        _logger.error('SettingsSyncService', '❌ Erro no push: ${response.statusCode}');
        return SyncResult.error('Erro ao sincronizar: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      _logger.error('SettingsSyncService', 'Timeout no push', e);
      return SyncResult.error('Timeout ao conectar ao servidor');
    } catch (e, stackTrace) {
      _logger.error('SettingsSyncService', 'Erro no push', e, stackTrace);
      return SyncResult.error('Erro ao sincronizar: $e');
    }
  }

  /// Baixa configurações do servidor (PULL)
  Future<SyncResult> pullSettings() async {
    try {
      _logger.info('SettingsSyncService', '⬇️ Iniciando pull de configurações');

      // Verifica conectividade
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _logger.warn('SettingsSyncService', '📡 Sem conexão - pull cancelado');
        return SyncResult.noConnection();
      }

      // Obtém token de autenticação
      final token = await _authService.getAccessToken();
      if (token == null) {
        _logger.error('SettingsSyncService', '🔒 Token não encontrado');
        return SyncResult.authError();
      }

      // Busca do backend
      final response = await _httpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/settings'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Timeout ao buscar configurações'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverSettings = SettingsModel.fromJson(data['settings']);

        // Salva localmente
        await _repository.saveSettings(serverSettings);

        _logger.success('SettingsSyncService', '✅ Pull concluído com sucesso');
        return SyncResult.success(serverSettings);
      } else {
        _logger.error('SettingsSyncService', '❌ Erro no pull: ${response.statusCode}');
        return SyncResult.error('Erro ao buscar configurações: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      _logger.error('SettingsSyncService', 'Timeout no pull', e);
      return SyncResult.error('Timeout ao conectar ao servidor');
    } catch (e, stackTrace) {
      _logger.error('SettingsSyncService', 'Erro no pull', e, stackTrace);
      return SyncResult.error('Erro ao buscar configurações: $e');
    }
  }

  /// Sincronização automática (verifica versão local vs servidor)
  Future<SyncResult> autoSync() async {
    try {
      _logger.info('SettingsSyncService', '🔄 Iniciando sincronização automática');

      // Carrega configurações locais
      final localSettings = await _repository.loadSettings();

      // Tenta fazer pull primeiro para verificar versão do servidor
      final pullResult = await pullSettings();

      if (!pullResult.success) {
        // Se pull falhar, tenta push
        return await pushSettings(localSettings);
      }

      // Compara timestamps
      if (pullResult.settings != null) {
        final serverSync = pullResult.settings!.lastSync;
        final localSync = localSettings.lastSync;

        if (serverSync != null && localSync != null && serverSync.isAfter(localSync)) {
          _logger.info('SettingsSyncService', '📥 Servidor mais recente - usando versão remota');
          return pullResult;
        } else {
          _logger.info('SettingsSyncService', '📤 Local mais recente - fazendo push');
          return await pushSettings(localSettings);
        }
      }

      return pullResult;
    } catch (e, stackTrace) {
      _logger.error('SettingsSyncService', 'Erro na sincronização automática', e, stackTrace);
      return SyncResult.error('Erro na sincronização: $e');
    }
  }

  /// Monitora conectividade e sincroniza automaticamente quando disponível
  Stream<SyncResult> watchAndSync() async* {
    await for (final connectivityResult in _connectivity.onConnectivityChanged) {
      if (connectivityResult != ConnectivityResult.none) {
        _logger.info('SettingsSyncService', '📡 Conectividade restaurada - sincronizando');
        yield await autoSync();
      }
    }
  }

  /// Fecha recursos
  void dispose() {
    _httpClient.close();
  }
}

/// Resultado de operações de sincronização
class SyncResult {
  final bool success;
  final String? errorMessage;
  final SettingsModel? settings;
  final SyncStatus status;

  SyncResult._({
    required this.success,
    this.errorMessage,
    this.settings,
    required this.status,
  });

  factory SyncResult.success(SettingsModel settings) {
    return SyncResult._(
      success: true,
      settings: settings,
      status: SyncStatus.synced,
    );
  }

  factory SyncResult.error(String message) {
    return SyncResult._(
      success: false,
      errorMessage: message,
      status: SyncStatus.error,
    );
  }

  factory SyncResult.noConnection() {
    return SyncResult._(
      success: false,
      errorMessage: 'Sem conexão com a internet',
      status: SyncStatus.pending,
    );
  }

  factory SyncResult.authError() {
    return SyncResult._(
      success: false,
      errorMessage: 'Erro de autenticação',
      status: SyncStatus.error,
    );
  }
}

enum SyncStatus {
  pending,
  synced,
  error,
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}

/// Provider do serviço de sincronização
final settingsSyncServiceProvider = Provider<SettingsSyncService>((ref) {
  return SettingsSyncService(
    httpClient: http.Client(),
    repository: ref.watch(settingsRepositoryProvider),
    authService: ref.watch(authServiceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});
