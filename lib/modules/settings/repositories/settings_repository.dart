
// /modules/settings/repositories/settings_repository.dart

import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/db/database_adapter.dart';
import '../../../core/observability/logger.dart';
import '../models/settings_model.dart';

class SettingsRepository {
  final DatabaseAdapter _db;
  final FlutterSecureStorage _secureStorage;
  final AppLogger _logger;

  SettingsRepository({
    required DatabaseAdapter db,
    required FlutterSecureStorage secureStorage,
    required AppLogger logger,
  })  : _db = db,
        _secureStorage = secureStorage,
        _logger = logger;

  /// Carrega configurações do banco local
  Future<SettingsModel> loadSettings() async {
    try {
      _logger.info('SettingsRepository', 'Carregando configurações locais');
      
      final result = await _db.query(
        'settings',
        where: 'id = ?',
        whereArgs: [1],
      );

      if (result.isNotEmpty) {
        return SettingsModel.fromJson(result.first);
      }

      // Retorna configurações padrão se não existir
      return const SettingsModel();
    } catch (e, stackTrace) {
      _logger.error('SettingsRepository', 'Erro ao carregar configurações', e, stackTrace);
      return const SettingsModel();
    }
  }

  /// Salva configurações no banco local (escrita direta)
  Future<void> saveSettings(SettingsModel settings) async {
    try {
      _logger.info('SettingsRepository', 'Salvando configurações localmente');

      await _db.insertOrUpdate(
        'settings',
        settings.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _logger.success('SettingsRepository', '✅ Configurações salvas localmente');
    } catch (e, stackTrace) {
      _logger.error('SettingsRepository', 'Erro ao salvar configurações', e, stackTrace);
      rethrow;
    }
  }

  /// Salva token biométrico de forma segura
  Future<void> saveBiometricToken(String token) async {
    await _secureStorage.write(key: 'biometric_token', value: token);
  }

  /// Recupera token biométrico
  Future<String?> getBiometricToken() async {
    return await _secureStorage.read(key: 'biometric_token');
  }

  /// Remove token biométrico
  Future<void> deleteBiometricToken() async {
    await _secureStorage.delete(key: 'biometric_token');
  }

  /// Limpa cache (preserva configurações essenciais)
  Future<void> clearCache() async {
    try {
      _logger.info('SettingsRepository', 'Limpando cache local');

      // Preserva configurações essenciais antes de limpar
      final currentSettings = await loadSettings();
      
      await _db.delete('quick_access');
      await _db.delete('search_history');
      await _db.delete('temp_data');

      _logger.success('SettingsRepository', '✅ Cache limpo com sucesso');
    } catch (e, stackTrace) {
      _logger.error('SettingsRepository', 'Erro ao limpar cache', e, stackTrace);
      rethrow;
    }
  }
}
