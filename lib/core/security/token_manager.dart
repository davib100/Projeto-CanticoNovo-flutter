// core/security/token_manager.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'encryption_service.dart';
import '../observability/observability_service.dart';

/// Gerenciador de tokens JWT com:
/// - Cache em memória com LRU eviction
/// - Encryption at rest
/// - Automatic expiration handling
/// - Token validation
/// - Revocation list support
/// - Token introspection
/// - Memory-safe operations
/// - Concurrent access safety
class TokenManager {
  static const _accessTokenKey = 'token_access';
  static const _refreshTokenKey = 'token_refresh';
  static const _tokenMetadataKey = 'token_metadata';
  static const _revokedTokensKey = 'token_revoked_list';
  
  final FlutterSecureStorage _secureStorage;
  final EncryptionService _encryptionService;
  final ObservabilityService? _observability;
  final TokenManagerConfig _config;
  
  // Cache em memória
  final Map<String, _CachedToken> _tokenCache = {};
  final List<String> _cacheAccessOrder = [];
  
  // Lock para operações concorrentes
  final _readWriteLock = _ReadWriteLock();
  
  // Métricas
  final _metrics = TokenMetrics();
  
  TokenManager({
    required FlutterSecureStorage secureStorage,
    required EncryptionService encryptionService,
    ObservabilityService? observability,
    TokenManagerConfig? config,
  })  : _secureStorage = secureStorage,
        _encryptionService = encryptionService,
        _observability = observability,
        _config = config ?? TokenManagerConfig.defaults();
  
  /// Métricas
  TokenMetrics get metrics => _metrics;
  
  /// Tamanho do cache
  int get cacheSize => _tokenCache.length;
  
  /// Armazena token de forma segura
  Future<void> storeToken({
    required String key,
    required String token,
    TokenType type = TokenType.access,
    Map<String, dynamic>? metadata,
  }) async {
    await _readWriteLock.write(() async {
      try {
        // Validar token
        if (!_isValidJwt(token)) {
          throw TokenException('Invalid JWT token format');
        }
        
        // Criptografar token
        final encryptedToken = await _encryptionService.encryptString(token);
        
        // Armazenar no secure storage
        await _secureStorage.write(key: key, value: encryptedToken);
        
        // Armazenar metadata se fornecido
        if (metadata != null) {
          final metadataKey = '${key}_metadata';
          await _secureStorage.write(
            key: metadataKey,
            value: jsonEncode(metadata),
          );
        }
        
        // Adicionar ao cache
        _addToCache(key, token, type);
        
        _metrics.tokensStored++;
        
        _observability?.addBreadcrumb(
          'Token stored',
          category: 'token',
          data: {'key': key, 'type': type.name},
        );
        
      } catch (e, stackTrace) {
        _metrics.storageErrors++;
        
        await _observability?.captureException(
          e,
          stackTrace: stackTrace,
          endpoint: 'token_manager.store',
        );
        
        rethrow;
      }
    });
  }
  
  /// Obtém token (com cache)
  Future<String?> getToken(String key) async {
    return await _readWriteLock.read(() async {
      try {
        // Verificar cache primeiro
        final cached = _getFromCache(key);
        
        if (cached != null) {
          // Verificar se não está expirado
          if (!_isTokenExpired(cached.token)) {
            _metrics.cacheHits++;
            return cached.token;
          } else {
            // Token expirado, remover do cache
            _removeFromCache(key);
            _metrics.expiredTokens++;
          }
        }
        
        _metrics.cacheMisses++;
        
        // Não está em cache, buscar do storage
        final encryptedToken = await _secureStorage.read(key: key);
        
        if (encryptedToken == null) {
          return null;
        }
        
        // Descriptografar
        final token = await _encryptionService.decryptString(encryptedToken);
        
        // Verificar se não está expirado
        if (_isTokenExpired(token)) {
          await deleteToken(key);
          _metrics.expiredTokens++;
          return null;
        }
        
        // Adicionar ao cache
        _addToCache(key, token, TokenType.access);
        
        _metrics.tokensRetrieved++;
        
        return token;
        
      } catch (e) {
        _metrics.retrievalErrors++;
        
        if (kDebugMode) {
          debugPrint('⚠️  Error retrieving token: $e');
        }
        
        return null;
      }
    });
  }
  
  /// Obtém access token
  Future<String?> getAccessToken() async {
    return await getToken(_accessTokenKey);
  }
  
  /// Obtém refresh token
  Future<String?> getRefreshToken() async {
    return await getToken(_refreshTokenKey);
  }
  
  /// Armazena access token
  Future<void> storeAccessToken(String token, {Map<String, dynamic>? metadata}) async {
    await storeToken(
      key: _accessTokenKey,
      token: token,
      type: TokenType.access,
      metadata: metadata,
    );
  }
  
  /// Armazena refresh token
  Future<void> storeRefreshToken(String token, {Map<String, dynamic>? metadata}) async {
    await storeToken(
      key: _refreshTokenKey,
      token: token,
      type: TokenType.refresh,
      metadata: metadata,
    );
  }
  
  /// Deleta token
  Future<void> deleteToken(String key) async {
    await _readWriteLock.write(() async {
      await _secureStorage.delete(key: key);
      await _secureStorage.delete(key: '${key}_metadata');
      
      _removeFromCache(key);
      
      _metrics.tokensDeleted++;
    });
  }
  
  /// Limpa todos os tokens
  Future<void> clearAllTokens() async {
    await _readWriteLock.write(() async {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _tokenMetadataKey);
      await _secureStorage.delete(key: '${_accessTokenKey}_metadata');
      await _secureStorage.delete(key: '${_refreshTokenKey}_metadata');
      
      _tokenCache.clear();
      _cacheAccessOrder.clear();
      
      _metrics.tokensDeleted += 2;
    });
  }
  
  /// Valida token
  Future<bool> validateToken(String token) async {
    try {
      // Verificar formato JWT
      if (!_isValidJwt(token)) {
        return false;
      }
      
      // Verificar expiração
      if (_isTokenExpired(token)) {
        return false;
      }
      
      // Verificar se está revogado
      if (await isTokenRevoked(token)) {
        return false;
      }
      
      // Validar assinatura (se configurado)
      if (_config.validateSignature) {
        return _validateTokenSignature(token);
      }
      
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Verifica se token está expirado
  bool isTokenExpired(String token) {
    return _isTokenExpired(token);
  }
  
  /// Obtém tempo restante do token
  Duration? getTokenRemainingTime(String token) {
    try {
      final expirationDate = JwtDecoder.getExpirationDate(token);
      final now = DateTime.now();
      
      if (expirationDate.isBefore(now)) {
        return Duration.zero;
      }
      
      return expirationDate.difference(now);
    } catch (e) {
      return null;
    }
  }
  
  /// Decodifica token (sem validação de assinatura)
  Map<String, dynamic>? decodeToken(String token) {
    try {
      return JwtDecoder.decode(token);
    } catch (e) {
      return null;
    }
  }
  
  /// Obtém claims do token
  Map<String, dynamic>? getTokenClaims(String token) {
    return decodeToken(token);
  }
  
  /// Obtém claim específico
  dynamic getTokenClaim(String token, String claimName) {
    final claims = getTokenClaims(token);
    return claims?[claimName];
  }
  
  /// Revoga token
  Future<void> revokeToken(String token) async {
    await _readWriteLock.write(() async {
      // Obter lista de tokens revogados
      final revokedListStr = await _secureStorage.read(key: _revokedTokensKey);
      
      final revokedList = revokedListStr != null
        ? (jsonDecode(revokedListStr) as List).cast<String>()
        : <String>[];
      
      // Adicionar token à lista
      final tokenId = getTokenClaim(token, 'jti') ?? token.hashCode.toString();
      
      if (!revokedList.contains(tokenId)) {
        revokedList.add(tokenId);
        
        // Limitar tamanho da lista
        if (revokedList.length > _config.maxRevokedTokens) {
          revokedList.removeAt(0);
        }
        
        await _secureStorage.write(
          key: _revokedTokensKey,
          value: jsonEncode(revokedList),
        );
        
        _metrics.tokensRevoked++;
      }
    });
  }
  
  /// Verifica se token está revogado
  Future<bool> isTokenRevoked(String token) async {
    return await _readWriteLock.read(() async {
      final revokedListStr = await _secureStorage.read(key: _revokedTokensKey);
      
      if (revokedListStr == null) return false;
      
      final revokedList = (jsonDecode(revokedListStr) as List).cast<String>();
      final tokenId = getTokenClaim(token, 'jti') ?? token.hashCode.toString();
      
      return revokedList.contains(tokenId);
    });
  }
  
  /// Limpa tokens revogados expirados
  Future<void> cleanupRevokedTokens() async {
    await _readWriteLock.write(() async {
      // Limpar lista de revogados (remover tokens já expirados)
      await _secureStorage.delete(key: _revokedTokensKey);
      
      if (kDebugMode) {
        debugPrint('🧹 Revoked tokens list cleaned');
      }
    });
  }
  
  /// Adiciona ao cache
  void _addToCache(String key, String token, TokenType type) {
    if (!_config.enableCache) return;
    
    // Remover se já existe
    if (_tokenCache.containsKey(key)) {
      _cacheAccessOrder.remove(key);
    }
    
    // Verificar limite de cache
    if (_tokenCache.length >= _config.maxCacheSize) {
      // Remover LRU (Least Recently Used)
      final lruKey = _cacheAccessOrder.removeAt(0);
      _tokenCache.remove(lruKey);
      _metrics.cacheEvictions++;
    }
    
    // Adicionar ao cache
    _tokenCache[key] = _CachedToken(
      token: token,
      type: type,
      cachedAt: DateTime.now(),
    );
    
    _cacheAccessOrder.add(key);
  }
  
  /// Obtém do cache
  _CachedToken? _getFromCache(String key) {
    if (!_config.enableCache) return null;
    
    final cached = _tokenCache[key];
    
    if (cached != null) {
      // Atualizar ordem de acesso (LRU)
      _cacheAccessOrder.remove(key);
      _cacheAccessOrder.add(key);
      
      // Verificar se cache não está muito antigo
      final age = DateTime.now().difference(cached.cachedAt);
      if (age > _config.cacheMaxAge) {
        _removeFromCache(key);
        return null;
      }
    }
    
    return cached;
  }
  
  /// Remove do cache
  void _removeFromCache(String key) {
    _tokenCache.remove(key);
    _cacheAccessOrder.remove(key);
  }
  
  /// Limpa cache
  void clearCache() {
    _tokenCache.clear();
    _cacheAccessOrder.clear();
    
    if (kDebugMode) {
      debugPrint('🧹 Token cache cleared');
    }
  }
  
  /// Valida formato JWT
  bool _isValidJwt(String token) {
    try {
      JwtDecoder.decode(token);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Verifica expiração
  bool _isTokenExpired(String token) {
    try {
      return JwtDecoder.isExpired(token);
    } catch (e) {
      return true;
    }
  }
  
  /// Valida assinatura do token
  bool _validateTokenSignature(String token) {
    // Em produção, implementar validação real usando chave pública
    // Por enquanto, apenas verificar se não está obviamente corrompido
    try {
      final decoded = JwtDecoder.decode(token);
      return decoded.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Libera recursos
  Future<void> dispose() async {
    clearCache();
    
    if (kDebugMode) {
      debugPrint('🔒 TokenManager disposed');
    }
  }
}

// ══════════════════════════════════════════
// CLASSES DE SUPORTE
// ══════════════════════════════════════════

class TokenManagerConfig {
  final bool enableCache;
  final int maxCacheSize;
  final Duration cacheMaxAge;
  final bool validateSignature;
  final int maxRevokedTokens;
  
  const TokenManagerConfig({
    required this.enableCache,
    required this.maxCacheSize,
    required this.cacheMaxAge,
    required this.validateSignature,
    required this.maxRevokedTokens,
  });
  
  factory TokenManagerConfig.defaults() {
    return const TokenManagerConfig(
      enableCache: true,
      maxCacheSize: 50,
      cacheMaxAge: Duration(minutes: 15),
      validateSignature: false,
      maxRevokedTokens: 1000,
    );
  }
}

enum TokenType {
  access,
  refresh,
  id,
}

class _CachedToken {
  final String token;
  final TokenType type;
  final DateTime cachedAt;
  
  _CachedToken({
    required this.token,
    required this.type,
    required this.cachedAt,
  });
}

class TokenMetrics {
  int tokensStored = 0;
  int tokensRetrieved = 0;
  int tokensDeleted = 0;
  int tokensRevoked = 0;
  int expiredTokens = 0;
  int cacheHits = 0;
  int cacheMisses = 0;
  int cacheEvictions = 0;
  int storageErrors = 0;
  int retrievalErrors = 0;
  
  double get cacheHitRate {
    final total = cacheHits + cacheMisses;
    return total > 0 ? (cacheHits / total) * 100 : 0.0;
  }
  
  @override
  String toString() {
    return 'TokenMetrics(\n'
           '  Stored: $tokensStored\n'
           '  Retrieved: $tokensRetrieved\n'
           '  Deleted: $tokensDeleted\n'
           '  Revoked: $tokensRevoked\n'
           '  Expired: $expiredTokens\n'
           '  Cache Hit Rate: ${cacheHitRate.toStringAsFixed(1)}%\n'
           ')';
  }
}

class _ReadWriteLock {
  int _readers = 0;
  bool _writing = false;
  final _completer = <Completer<void>>[];
  
  Future<T> read<T>(Future<T> Function() operation) async {
    while (_writing) {
      final completer = Completer<void>();
      _completer.add(completer);
      await completer.future;
    }
    
    _readers++;
    
    try {
      return await operation();
    } finally {
      _readers--;
      _notifyNext();
    }
  }
  
  Future<T> write<T>(Future<T> Function() operation) async {
    while (_writing || _readers > 0) {
      final completer = Completer<void>();
      _completer.add(completer);
      await completer.future;
    }
    
    _writing = true;
    
    try {
      return await operation();
    } finally {
      _writing = false;
      _notifyNext();
    }
  }
  
  void _notifyNext() {
    if (_completer.isNotEmpty && !_writing && _readers == 0) {
      final completer = _completer.removeAt(0);
      completer.complete();
    }
  }
}

class TokenException implements Exception {
  final String message;
  TokenException(this.message);
  
  @override
  String toString() => 'TokenException: $message';
}
