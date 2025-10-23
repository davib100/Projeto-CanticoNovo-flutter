import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:myapp/core/observability/observability_service.dart';
import 'package:myapp/core/security/encryption_service.dart';

class TokenManager {
  final FlutterSecureStorage _secureStorage;
  final EncryptionService _encryptionService;
  final ObservabilityService _observabilityService;

  // Cache em memória para os tokens
  String? _accessToken;
  String? _refreshToken;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  TokenManager({
    required FlutterSecureStorage secureStorage,
    required EncryptionService encryptionService,
    required ObservabilityService observabilityService,
  })  : _secureStorage = secureStorage,
        _encryptionService = encryptionService,
        _observabilityService = observabilityService;

  /// Armazena o Access Token de forma segura.
  Future<void> storeAccessToken(String token) async {
    try {
      final encryptedToken = await _encryptionService.encryptString(token);
      await _secureStorage.write(key: _accessTokenKey, value: encryptedToken);
      _accessToken = token; // Atualiza o cache
      _observabilityService.addBreadcrumb('Access token stored successfully');
    } catch (e, stackTrace) {
      _observabilityService.captureException(e, stackTrace: stackTrace);
      throw Exception('Failed to store access token');
    }
  }

  /// Armazena o Refresh Token de forma segura.
  Future<void> storeRefreshToken(String token) async {
    try {
      final encryptedToken = await _encryptionService.encryptString(token);
      await _secureStorage.write(key: _refreshTokenKey, value: encryptedToken);
      _refreshToken = token; // Atualiza o cache
      _observabilityService.addBreadcrumb('Refresh token stored successfully');
    } catch (e, stackTrace) {
      _observabilityService.captureException(e, stackTrace: stackTrace);
      throw Exception('Failed to store refresh token');
    }
  }

  /// Carrega ambos os tokens do armazenamento seguro para o cache em memória.
  Future<void> loadTokens() async {
    _accessToken = await getAccessToken();
    _refreshToken = await getRefreshToken();
  }

  /// Retorna o Access Token (do cache ou do armazenamento seguro).
  Future<String?> getAccessToken() async {
    if (_accessToken != null) return _accessToken;

    try {
      final encryptedToken = await _secureStorage.read(key: _accessTokenKey);
      if (encryptedToken == null) return null;
      
      final token = await _encryptionService.decryptString(encryptedToken);
      _accessToken = token; // Armazena em cache
      _observabilityService.addBreadcrumb('Access token retrieved successfully');
      return token;
    } catch (e, stackTrace) {
      _observabilityService.captureException(e, stackTrace: stackTrace);
      // Em caso de erro de decriptografia, o token pode estar corrompido. Limpar.
      await deleteTokens(); 
      return null;
    }
  }

  /// Retorna o Refresh Token (do cache ou do armazenamento seguro).
  Future<String?> getRefreshToken() async {
    if (_refreshToken != null) return _refreshToken;

    try {
      final encryptedToken = await _secureStorage.read(key: _refreshTokenKey);
      if (encryptedToken == null) return null;

      final token = await _encryptionService.decryptString(encryptedToken);
      _refreshToken = token; // Armazena em cache
      _observabilityService.addBreadcrumb('Refresh token retrieved successfully');
      return token;
    } catch (e, stackTrace) {
      _observabilityService.captureException(e, stackTrace: stackTrace);
      await deleteTokens();
      return null;
    }
  }

  /// Deleta ambos os tokens do armazenamento seguro e do cache.
  Future<void> deleteTokens() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      _accessToken = null;
      _refreshToken = null;
      _observabilityService.addBreadcrumb('All tokens deleted successfully');
    } catch (e, stackTrace) {
      _observabilityService.captureException(e, stackTrace: stackTrace);
      throw Exception('Failed to delete tokens');
    }
  }

  /// Limpa o cache de tokens em memória.
  void dispose() {
    _accessToken = null;
    _refreshToken = null;
  }
}

final tokenManagerProvider = Provider<TokenManager>((ref) {
  return TokenManager(
    secureStorage: ref.watch(flutterSecureStorageProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    observabilityService: ref.watch(observabilityServiceProvider),
  );
});
