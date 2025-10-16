// core/security/auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/api_client.dart';
import '../observability/observability_service.dart';

/// Serviço de autenticação enterprise-grade com:
/// - OAuth 2.1 com PKCE (RFC 7636)
/// - Refresh token rotation automático (RFC 6819)
/// - Single device enforcement
/// - Biometric authentication
/// - Token encryption at rest
/// - Session management
/// - Automatic token renewal
/// - Graceful degradation
/// - Security event logging
class AuthService {
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _deviceIdKey = 'auth_device_id';
  static const _sessionIdKey = 'auth_session_id';
  static const _userProfileKey = 'auth_user_profile';
  static const _biometricEnabledKey = 'auth_biometric_enabled';
  static const _lastAuthTimeKey = 'auth_last_auth_time';
  static const _pkceVerifierKey = 'auth_pkce_verifier';
  
  final FlutterSecureStorage _secureStorage;
  final ApiClient? _apiClient;
  final ObservabilityService? _observability;
  final LocalAuthentication _localAuth;
  final DeviceInfoPlugin _deviceInfo;
  
  // Estado de autenticação
  final _authStateController = StreamController<AuthState>.broadcast();
  AuthState _currentState = AuthState.unauthenticated();
  
  // Configuração
  final AuthConfig _config;
  
  // Token refresh lock
  Completer<String?>? _refreshCompleter;
  Timer? _tokenRefreshTimer;
  Timer? _sessionCheckTimer;
  
  // Cache
  UserProfile? _cachedUserProfile;
  String? _cachedDeviceId;
  
  // Métricas
  final _metrics = AuthMetrics();
  
  AuthService({
  required FlutterSecureStorage secureStorage,
  required ApiClient? apiClient,
  AuthConfig? config,
  ObservabilityService? observability,
  LocalAuthentication? localAuth,
  DeviceInfoPlugin? deviceInfo,
})  : _secureStorage = secureStorage,
      _apiClient = apiClient,
      _config = config ?? AuthConfig.defaults(),
      _observability = observability,
      _localAuth = localAuth ?? LocalAuthentication(),
      _deviceInfo = deviceInfo ?? DeviceInfoPlugin();
  
  /// Stream de estados de autenticação
  Stream<AuthState> get authStateStream => _authStateController.stream;
  
  /// Estado atual
  AuthState get currentState => _currentState;
  
  /// Verifica se está autenticado
  bool get isAuthenticated => _currentState is AuthStateAuthenticated;
  
  /// Obtém perfil do usuário em cache
  UserProfile? get currentUser => _cachedUserProfile;
  
  /// Métricas de autenticação
  AuthMetrics get metrics => _metrics;
  
  /// Inicializa o serviço
  Future<void> initialize() async {
    try {
      // Carregar device ID ou gerar novo
      _cachedDeviceId = await _getOrCreateDeviceId();
      
      // Verificar se há sessão válida
      final hasSession = await hasValidSession();
      
      if (hasSession) {
        // Carregar perfil do usuário
        await _loadUserProfile();
        
        // Iniciar monitoramento de token
        _startTokenRefreshMonitoring();
        
        // Iniciar verificação de sessão
        _startSessionChecking();
        
        _updateState(AuthState.authenticated(user: _cachedUserProfile!));
        
        _metrics.sessionsRestored++;
        
        if (kDebugMode) {
          debugPrint('✅ Auth session restored for: ${_cachedUserProfile?.email}');
        }
      } else {
        _updateState(AuthState.unauthenticated());
      }
      
      _observability?.addBreadcrumb(
        'AuthService initialized',
        category: 'auth',
        data: {
          'device_id': _cachedDeviceId,
          'has_session': hasSession,
        },
      );
      
    } catch (e, stackTrace) {
      await _observability?.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'auth_service.initialize',
      );
      
      _updateState(AuthState.error(error: 'Failed to initialize: $e'));
    }
  }
  
  /// Login com OAuth 2.1 + PKCE
  Future<AuthResult> loginWithOAuth({
    required AuthProvider provider,
    List<String>? scopes,
    Map<String, String>? additionalParams,
  }) async {
    if (_apiClient == null) {
      return AuthResult.failure(error: 'API client not configured');
    }
    
    _updateState(AuthState.authenticating(provider: provider));
    
    final transaction = _observability?.startTransaction(
      'auth.login',
      'auth.oauth',
      data: {'provider': provider.name},
    );
    
    try {
      // Gerar PKCE challenge
      final pkce = await _generatePKCE();
      
      // Obter authorization code via OAuth flow
      final authCode = await _performOAuthFlow(
        provider: provider,
        codeChallenge: pkce.challenge,
        codeChallengeMethod: 'S256',
        scopes: scopes ?? _config.defaultScopes,
        additionalParams: additionalParams,
      );
      
      if (authCode == null) {
        throw AuthException('Authorization cancelled or failed');
      }
      
      // Trocar code por tokens
      final tokenResponse = await _exchangeCodeForTokens(
        provider: provider,
        authorizationCode: authCode,
        codeVerifier: pkce.verifier,
      );
      
      // Armazenar tokens de forma segura
      await _storeTokens(
        accessToken: tokenResponse.accessToken,
        refreshToken: tokenResponse.refreshToken,
        expiresIn: tokenResponse.expiresIn,
      );
      
      // Obter perfil do usuário
      final userProfile = await _fetchUserProfile(tokenResponse.accessToken);
      
      // Criar sessão no backend
      final sessionId = await _createSession(userProfile);
      
      await _secureStorage.write(key: _sessionIdKey, value: sessionId);
      
      _cachedUserProfile = userProfile;
      
      // Iniciar monitoramentos
      _startTokenRefreshMonitoring();
      _startSessionChecking();
      
      _updateState(AuthState.authenticated(user: userProfile));
      
      _metrics.successfulLogins++;
      _metrics.lastLoginTime = DateTime.now();
      
      await transaction?.finish(status: SpanStatus.ok());
      
      await _observability?.captureMessage(
        'User logged in successfully',
        level: SentryLevel.info,
        extra: {
          'provider': provider.name,
          'user_id': userProfile.id,
        },
      );
      
      return AuthResult.success(user: userProfile);
      
    } catch (e, stackTrace) {
      _metrics.failedLogins++;
      
      await _observability?.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'auth_service.login',
        extra: {'provider': provider.name},
      );
      
      await transaction?.finish(status: SpanStatus.unauthenticated());
      
      _updateState(AuthState.error(error: e.toString()));
      
      return AuthResult.failure(error: e.toString());
    }
  }
  
  /// Login com biometria
  Future<AuthResult> loginWithBiometric() async {
    if (!await isBiometricEnabled()) {
      return AuthResult.failure(error: 'Biometric not enabled');
    }
    
    _updateState(AuthState.authenticating(
      provider: AuthProvider.biometric,
    ));
    
    try {
      // Verificar se dispositivo suporta biometria
      final canCheckBiometric = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!canCheckBiometric || !isDeviceSupported) {
        throw AuthException('Biometric not available on this device');
      }
      
      // Obter biometrias disponíveis
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      if (availableBiometrics.isEmpty) {
        throw AuthException('No biometric enrolled on device');
      }
      
      // Autenticar com biometria
      final authenticated = await _localAuth.authenticate(
        localizedReason: _config.biometricPrompt,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          sensitiveTransaction: true,
        ),
      );
      
      if (!authenticated) {
        _metrics.biometricFailures++;
        return AuthResult.failure(error: 'Biometric authentication failed');
      }
      
      // Obter tokens armazenados
      final accessToken = await _getAccessToken();
      
      if (accessToken == null) {
        throw AuthException('No stored session found');
      }
      
      // Validar token
      if (_isTokenExpired(accessToken)) {
        final refreshed = await refreshToken();
        if (refreshed == null) {
          throw AuthException('Session expired');
        }
      }
      
      // Carregar perfil
      await _loadUserProfile();
      
      _updateState(AuthState.authenticated(user: _cachedUserProfile!));
      
      _metrics.biometricLogins++;
      _metrics.lastLoginTime = DateTime.now();
      
      await _secureStorage.write(
        key: _lastAuthTimeKey,
        value: DateTime.now().toIso8601String(),
      );
      
      return AuthResult.success(user: _cachedUserProfile!);
      
    } catch (e, stackTrace) {
      await _observability?.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'auth_service.biometric_login',
      );
      
      _updateState(AuthState.error(error: e.toString()));
      
      return AuthResult.failure(error: e.toString());
    }
  }
  
  /// Logout
  Future<void> logout({bool revokeTokens = true}) async {
    _updateState(AuthState.loggingOut());
    
    try {
      if (revokeTokens && _apiClient != null) {
        // Revogar tokens no servidor
        await _revokeTokens();
        
        // Destruir sessão
        await _destroySession();
      }
      
      // Limpar storage
      await _clearSecureStorage();
      
      // Parar monitoramentos
      _stopTokenRefreshMonitoring();
      _stopSessionChecking();
      
      // Limpar cache
      _cachedUserProfile = null;
      
      _updateState(AuthState.unauthenticated());
      
      _metrics.logouts++;
      
      await _observability?.captureMessage(
        'User logged out',
        level: SentryLevel.info,
      );
      
      if (kDebugMode) {
        debugPrint('✅ User logged out successfully');
      }
      
    } catch (e, stackTrace) {
      await _observability?.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'auth_service.logout',
      );
      
      // Mesmo com erro, limpar localmente
      await _clearSecureStorage();
      _updateState(AuthState.unauthenticated());
    }
  }
  
  /// Obtém access token válido (com auto-refresh)
  Future<String?> getAccessToken() async {
    try {
      final token = await _getAccessToken();
      
      if (token == null) return null;
      
      // Verificar expiração
      if (_isTokenExpired(token)) {
        // Token expirado, tentar refresh
        return await refreshToken();
      }
      
      // Token válido
      return token;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  Error getting access token: $e');
      }
      return null;
    }
  }
  
  /// Refresh de token com rotation
  Future<String?> refreshToken() async {
    // Prevenir múltiplas chamadas simultâneas
    if (_refreshCompleter != null) {
      return await _refreshCompleter!.future;
    }
    
    _refreshCompleter = Completer<String?>();
    
    if (_apiClient == null) {
      _refreshCompleter!.complete(null);
      _refreshCompleter = null;
      return null;
    }
    
    try {
      final currentRefreshToken = await _getRefreshToken();
      
      if (currentRefreshToken == null) {
        throw AuthException('No refresh token available');
      }
      
      _observability?.addBreadcrumb(
        'Refreshing access token',
        category: 'auth',
      );
      
      // Chamar endpoint de refresh
      final response = await _apiClient!.post(
        '/auth/refresh',
        {
          'refresh_token': currentRefreshToken,
          'device_id': _cachedDeviceId,
          'grant_type': 'refresh_token',
        },
      );
      
      final newAccessToken = response['access_token'] as String;
      final newRefreshToken = response['refresh_token'] as String;
      final expiresIn = response['expires_in'] as int?;
      
      // Armazenar novos tokens (rotation)
      await _storeTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresIn: expiresIn,
      );
      
      _metrics.tokenRefreshes++;
      
      _refreshCompleter!.complete(newAccessToken);
      
      return newAccessToken;
      
    } on ApiException catch (e) {
      // Se refresh falhar com 401, sessão expirou
      if (e.statusCode == 401) {
        await logout(revokeTokens: false);
        
        _updateState(AuthState.sessionExpired());
        
        await _observability?.captureMessage(
          'Session expired - refresh token invalid',
          level: SentryLevel.warning,
        );
      }
      
      _refreshCompleter!.complete(null);
      return null;
      
    } catch (e, stackTrace) {
      await _observability?.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'auth_service.refresh_token',
      );
      
      _refreshCompleter!.complete(null);
      return null;
      
    } finally {
      _refreshCompleter = null;
    }
  }
  
  /// Verifica se tem sessão válida
  Future<bool> hasValidSession() async {
    try {
      final accessToken = await _getAccessToken();
      
      if (accessToken == null) return false;
      
      // Verificar se token não está expirado
      if (_isTokenExpired(accessToken)) {
        // Tentar refresh
        final refreshed = await refreshToken();
        return refreshed != null;
      }
      
      // Verificar sessão no servidor (se configurado)
      if (_config.validateSessionOnBackend && _apiClient != null) {
        return await _validateSessionOnServer();
      }
      
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Habilita autenticação biométrica
  Future<bool> enableBiometric() async {
    try {
      final canCheckBiometric = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!canCheckBiometric || !isDeviceSupported) {
        return false;
      }
      
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Enable biometric authentication',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (authenticated) {
        await _secureStorage.write(
          key: _biometricEnabledKey,
          value: 'true',
        );
        
        _metrics.biometricEnabled++;
        
        return true;
      }
      
      return false;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Desabilita autenticação biométrica
  Future<void> disableBiometric() async {
    await _secureStorage.delete(key: _biometricEnabledKey);
    _metrics.biometricDisabled++;
  }
  
  /// Verifica se biometria está habilitada
  Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(key: _biometricEnabledKey);
    return enabled == 'true';
  }
  
  /// Verifica biometrias disponíveis
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
  
  /// Atualiza perfil do usuário
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (!isAuthenticated || _apiClient == null) {
      throw AuthException('Not authenticated');
    }
    
    try {
      await _apiClient!.put(
        '/users/profile',
        updates,
      );
      
      // Recarregar perfil
      await _loadUserProfile();
      
      _updateState(AuthState.authenticated(user: _cachedUserProfile!));
      
    } catch (e, stackTrace) {
      await _observability?.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'auth_service.update_profile',
      );
      rethrow;
    }
  }
  
  /// Troca senha
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!isAuthenticated || _apiClient == null) {
      throw AuthException('Not authenticated');
    }
    
    try {
      await _apiClient!.post(
        '/auth/change-password',
        {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      
      await _observability?.captureMessage(
        'Password changed successfully',
        level: SentryLevel.info,
      );
      
    } catch (e, stackTrace) {
      await _observability?.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'auth_service.change_password',
      );
      rethrow;
    }
  }
  
  /// Solicita reset de senha
  Future<void> requestPasswordReset(String email) async {
    if (_apiClient == null) {
      throw AuthException('API client not configured');
    }
    
    try {
      await _apiClient!.post(
        '/auth/forgot-password',
        {'email': email},
      );
      
    } catch (e, stackTrace) {
      await _observability?.captureException(
        e,
        stackTrace: stackTrace,
        endpoint: 'auth_service.request_password_reset',
      );
      rethrow;
    }
  }
  
  // ══════════════════════════════════════════
  // MÉTODOS PRIVADOS
  // ══════════════════════════════════════════
  
  /// Gera PKCE code verifier e challenge
  Future<PKCEChallenge> _generatePKCE() async {
    final random = Random.secure();
    final verifier = base64Url.encode(
      List<int>.generate(32, (_) => random.nextInt(256))
    ).replaceAll('=', '');
    
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    final challenge = base64Url.encode(digest.bytes).replaceAll('=', '');
    
    // Armazenar verifier temporariamente
    await _secureStorage.write(key: _pkceVerifierKey, value: verifier);
    
    return PKCEChallenge(verifier: verifier, challenge: challenge);
  }
  
  /// Realiza OAuth flow (simplificado - na prática usaria AppAuth ou similar)
  Future<String?> _performOAuthFlow({
    required AuthProvider provider,
    required String codeChallenge,
    required String codeChallengeMethod,
    required List<String> scopes,
    Map<String, String>? additionalParams,
  }) async {
    // Na implementação real, isso usaria flutter_appauth ou oauth2
    // para lidar com o flow completo incluindo redirect
    
    // Aqui está simplificado para exemplo
    throw UnimplementedError('OAuth flow should use flutter_appauth');
  }
  
  /// Troca authorization code por tokens
  Future<TokenResponse> _exchangeCodeForTokens({
    required AuthProvider provider,
    required String authorizationCode,
    required String codeVerifier,
  }) async {
    if (_apiClient == null) {
      throw AuthException('API client not configured');
    }
    
    final response = await _apiClient!.post(
      '/auth/token',
      {
        'grant_type': 'authorization_code',
        'code': authorizationCode,
        'code_verifier': codeVerifier,
        'redirect_uri': _config.redirectUri,
        'client_id': _config.clientId,
        'device_id': _cachedDeviceId,
      },
    );
    
    return TokenResponse(
      accessToken: response['access_token'] as String,
      refreshToken: response['refresh_token'] as String,
      expiresIn: response['expires_in'] as int?,
      tokenType: response['token_type'] as String? ?? 'Bearer',
    );
  }
  
  /// Busca perfil do usuário
  Future<UserProfile> _fetchUserProfile(String accessToken) async {
    if (_apiClient == null) {
      throw AuthException('API client not configured');
    }
    
    final response = await _apiClient!.get('/users/me');
    
    final profile = UserProfile.fromJson(response);
    
    // Armazenar em cache criptografado
    await _secureStorage.write(
      key: _userProfileKey,
      value: jsonEncode(profile.toJson()),
    );
    
    return profile;
  }
  
  /// Cria sessão no backend
  Future<String> _createSession(UserProfile user) async {
    if (_apiClient == null) {
      throw AuthException('API client not configured');
    }
    
    final packageInfo = await PackageInfo.fromPlatform();
    
    final response = await _apiClient!.post(
      '/auth/sessions',
      {
        'device_id': _cachedDeviceId,
        'device_name': await _getDeviceName(),
        'app_version': packageInfo.version,
        'platform': defaultTargetPlatform.name,
      },
    );
    
    return response['session_id'] as String;
  }
  
  /// Valida sessão no servidor
  Future<bool> _validateSessionOnServer() async {
    if (_apiClient == null) return false;
    
    try {
      final sessionId = await _secureStorage.read(key: _sessionIdKey);
      
      if (sessionId == null) return false;
      
      final response = await _apiClient!.get('/auth/sessions/$sessionId');
      
      return response['valid'] == true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Destrói sessão no servidor
  Future<void> _destroySession() async {
    if (_apiClient == null) return;
    
    try {
      final sessionId = await _secureStorage.read(key: _sessionIdKey);
      
      if (sessionId != null) {
        await _apiClient!.delete('/auth/sessions/$sessionId');
      }
    } catch (e) {
      // Ignorar erros ao destruir sessão
    }
  }
  
  /// Revoga tokens no servidor
  Future<void> _revokeTokens() async {
    if (_apiClient == null) return;
    
    try {
      final refreshToken = await _getRefreshToken();
      
      if (refreshToken != null) {
        await _apiClient!.post(
          '/auth/revoke',
          {'refresh_token': refreshToken},
        );
      }
    } catch (e) {
      // Ignorar erros ao revogar
    }
  }
  
  /// Armazena tokens de forma segura
  Future<void> _storeTokens({
    required String accessToken,
    required String refreshToken,
    int? expiresIn,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    
    if (expiresIn != null) {
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
      await _secureStorage.write(
        key: '${_accessTokenKey}_expires_at',
        value: expiresAt.toIso8601String(),
      );
    }
  }
  
  /// Obtém access token do storage
  Future<String?> _getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }
  
  /// Obtém refresh token do storage
  Future<String?> _getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }
  
  /// Verifica se token está expirado
  bool _isTokenExpired(String token) {
    try {
      return JwtDecoder.isExpired(token);
    } catch (e) {
      // Se não conseguir decodificar, considerar expirado
      return true;
    }
  }
  
  /// Obtém tempo restante do token
  Duration? _getTokenRemainingTime(String token) {
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
  
  /// Carrega perfil do usuário do cache
  Future<void> _loadUserProfile() async {
    final profileJson = await _secureStorage.read(key: _userProfileKey);
    
    if (profileJson != null) {
      _cachedUserProfile = UserProfile.fromJson(jsonDecode(profileJson));
    }
  }
  
  /// Obtém ou cria device ID
  Future<String> _getOrCreateDeviceId() async {
    var deviceId = await _secureStorage.read(key: _deviceIdKey);
    
    if (deviceId == null) {
      // Gerar novo device ID único
      deviceId = _generateDeviceId();
      await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    }
    
    return deviceId;
  }
  
  /// Gera device ID único
  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
  
  /// Obtém nome do dispositivo
  Future<String> _getDeviceName() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.model}';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }
  
  /// Inicia monitoramento de refresh de token
  void _startTokenRefreshMonitoring() {
    _stopTokenRefreshMonitoring();
    
    _tokenRefreshTimer = Timer.periodic(
      _config.tokenCheckInterval,
      (_) async {
        final token = await _getAccessToken();
        
        if (token != null) {
          final remaining = _getTokenRemainingTime(token);
          
          // Refresh proativo antes de expirar
          if (remaining != null && 
              remaining < _config.tokenRefreshThreshold) {
            await refreshToken();
          }
        }
      },
    );
  }
  
  /// Para monitoramento de refresh
  void _stopTokenRefreshMonitoring() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }
  
  /// Inicia verificação periódica de sessão
  void _startSessionChecking() {
    _stopSessionChecking();
    
    if (!_config.validateSessionOnBackend) return;
    
    _sessionCheckTimer = Timer.periodic(
      _config.sessionCheckInterval,
      (_) async {
        if (!await hasValidSession()) {
          await logout(revokeTokens: false);
          _updateState(AuthState.sessionExpired());
        }
      },
    );
  }
  
  /// Para verificação de sessão
  void _stopSessionChecking() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = null;
  }
  
  /// Limpa storage seguro
  Future<void> _clearSecureStorage() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _sessionIdKey);
    await _secureStorage.delete(key: _userProfileKey);
    await _secureStorage.delete(key: _lastAuthTimeKey);
    await _secureStorage.delete(key: _pkceVerifierKey);
    await _secureStorage.delete(key: '${_accessTokenKey}_expires_at');
  }
  
  /// Atualiza estado
  void _updateState(AuthState newState) {
    _currentState = newState;
    _authStateController.add(newState);
  }
  
  /// Libera recursos
  Future<void> dispose() async {
    _stopTokenRefreshMonitoring();
    _stopSessionChecking();
    await _authStateController.close();
    
    if (kDebugMode) {
      debugPrint('🔒 AuthService disposed');
    }
  }
}

// ══════════════════════════════════════════
// CLASSES DE SUPORTE
// ══════════════════════════════════════════

class AuthConfig {
  final String clientId;
  final String redirectUri;
  final List<String> defaultScopes;
  final Duration tokenCheckInterval;
  final Duration tokenRefreshThreshold;
  final Duration sessionCheckInterval;
  final bool validateSessionOnBackend;
  final String biometricPrompt;
  
  const AuthConfig({
    required this.clientId,
    required this.redirectUri,
    required this.defaultScopes,
    required this.tokenCheckInterval,
    required this.tokenRefreshThreshold,
    required this.sessionCheckInterval,
    required this.validateSessionOnBackend,
    required this.biometricPrompt,
  });
  
  factory AuthConfig.defaults() {
    return const AuthConfig(
      clientId: 'com.canticonovo.app',
      redirectUri: 'com.canticonovo://oauth-callback',
      defaultScopes: ['profile', 'email', 'offline_access'],
      tokenCheckInterval: Duration(minutes: 1),
      tokenRefreshThreshold: Duration(minutes: 5),
      sessionCheckInterval: Duration(minutes: 15),
      validateSessionOnBackend: true,
      biometricPrompt: 'Authenticate to access your account',
    );
  }
}

class PKCEChallenge {
  final String verifier;
  final String challenge;
  
  PKCEChallenge({required this.verifier, required this.challenge});
}

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final int? expiresIn;
  final String tokenType;
  
  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
    required this.tokenType,
  });
}

class UserProfile {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final Map<String, dynamic> metadata;
  
  UserProfile({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.metadata = const {},
  });
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'metadata': metadata,
    };
  }
}

enum AuthProvider {
  google,
  microsoft,
  facebook,
  apple,
  biometric,
}

abstract class AuthState {
  const AuthState();
  
  factory AuthState.unauthenticated() = AuthStateUnauthenticated;
  factory AuthState.authenticating({required AuthProvider provider}) = 
    AuthStateAuthenticating;
  factory AuthState.authenticated({required UserProfile user}) = 
    AuthStateAuthenticated;
  factory AuthState.sessionExpired() = AuthStateSessionExpired;
  factory AuthState.loggingOut() = AuthStateLoggingOut;
  factory AuthState.error({required String error}) = AuthStateError;
}

class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

class AuthStateAuthenticating extends AuthState {
  final AuthProvider provider;
  const AuthStateAuthenticating({required this.provider});
}

class AuthStateAuthenticated extends AuthState {
  final UserProfile user;
  const AuthStateAuthenticated({required this.user});
}

class AuthStateSessionExpired extends AuthState {
  const AuthStateSessionExpired();
}

class AuthStateLoggingOut extends AuthState {
  const AuthStateLoggingOut();
}

class AuthStateError extends AuthState {
  final String error;
  const AuthStateError({required this.error});
}

class AuthResult {
  final bool success;
  final UserProfile? user;
  final String? error;
  
  AuthResult._({
    required this.success,
    this.user,
    this.error,
  });
  
  factory AuthResult.success({required UserProfile user}) {
    return AuthResult._(success: true, user: user);
  }
  
  factory AuthResult.failure({required String error}) {
    return AuthResult._(success: false, error: error);
  }
}

class AuthMetrics {
  int successfulLogins = 0;
  int failedLogins = 0;
  int logouts = 0;
  int tokenRefreshes = 0;
  int sessionsRestored = 0;
  int biometricLogins = 0;
  int biometricFailures = 0;
  int biometricEnabled = 0;
  int biometricDisabled = 0;
  DateTime? lastLoginTime;
  
  @override
  String toString() {
    return 'AuthMetrics(\n'
           '  Successful Logins: $successfulLogins\n'
           '  Failed Logins: $failedLogins\n'
           '  Token Refreshes: $tokenRefreshes\n'
           '  Biometric Logins: $biometricLogins\n'
           '  Last Login: ${lastLoginTime ?? "Never"}\n'
           ')';
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  
  @override
  String toString() => 'AuthException: $message';
}
