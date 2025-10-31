import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serviço de cache
class CacheService {
  Future<void> clearAll() async {
    // Implementar limpeza de cache
  }

  Future<void> clearByPattern(String pattern) async {
    // Implementar limpeza por padrão
  }
}

final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());
