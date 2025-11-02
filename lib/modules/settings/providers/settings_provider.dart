
// /modules/settings/providers/settings_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/settings_model.dart';
import '../repositories/settings_repository.dart';
import 'settings_repository_provider.dart';

part 'settings_provider.g.dart';

@riverpod
class Settings extends _$Settings {
  late SettingsRepository _repository;

  @override
  Future<SettingsModel> build() async {
    _repository = ref.watch(settingsRepositoryProvider);
    return await _repository.loadSettings();
  }

  /// Atualiza uma configuração específica
  Future<void> updateSetting(String key, dynamic value) async {
    final current = state.value;
    if (current == null) return;

    SettingsModel updated = current;

    // Atualiza apenas o campo alterado
    switch (key) {
      case 'theme':
        updated = current.copyWith(theme: value as String);
        break;
      case 'language':
        updated = current.copyWith(language: value as String);
        break;
      case 'fontSize':
        updated = current.copyWith(fontSize: value as int);
        break;
      case 'accentColor':
        updated = current.copyWith(accentColor: value as String);
        break;
      case 'fontFamily':
        updated = current.copyWith(fontFamily: value as String);
        break;
      case 'autoScrollSpeed':
        updated = current.copyWith(autoScrollSpeed: value as double);
        break;
      case 'autoBackup':
        updated = current.copyWith(autoBackup: value as bool);
        break;
      case 'notifications':
        updated = current.copyWith(notifications: value as bool);
        break;
      case 'notificationTime':
        updated = current.copyWith(notificationTime: value as String);
        break;
      case 'biometricLock':
        updated = current.copyWith(biometricLock: value as bool);
        break;
    }

    // Atualiza o estado local
    state = AsyncValue.data(updated);

    // Persiste no banco (escrita direta)
    await _repository.saveSettings(updated);
  }

  /// Sincroniza com o backend
  Future<void> syncWithCloud() async {
    // Implementação de sincronização será feita no settings_sync_service.dart
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(current.copyWith(lastSync: DateTime.now()));
    await _repository.saveSettings(state.value!);
  }

  /// Limpa cache local
  Future<void> clearCache() async {
    await _repository.clearCache();
  }
}
