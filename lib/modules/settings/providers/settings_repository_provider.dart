
// /modules/settings/providers/settings_repository_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/db/database_adapter.dart';
import '../../../core/observability/logger.dart';
import '../repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    db: ref.watch(databaseAdapterProvider),
    secureStorage: ref.watch(secureStorageProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

// Providers core (presumindo que existam em /core)
final databaseAdapterProvider = Provider<DatabaseAdapter>((ref) {
  throw UnimplementedError('DatabaseAdapter deve ser implementado em /core/db');
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final appLoggerProvider = Provider<AppLogger>((ref) {
  return AppLogger();
});
