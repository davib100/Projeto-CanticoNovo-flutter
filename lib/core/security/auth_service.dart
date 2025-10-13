import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../services/api_client.dart';
import '../../modules/auth/providers/auth_provider.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage;
  final ApiClient _apiClient;
  String? _deviceId;

  // Construtor que inicializa as variáveis finais
  AuthService({
    required FlutterSecureStorage secureStorage,
    required ApiClient apiClient,
  })  : _secureStorage = secureStorage,
        _apiClient = apiClient;

   
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> _getDeviceId() async {
  if (_deviceId != null) return _deviceId!;
  
  try {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      final androidData = androidInfo.data;
      _deviceId = androidData['androidId'] ?? 'unknown_android_id';
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      _deviceId = iosInfo.identifierForVendor ?? 'unknown_ios_id';
    } else {
      _deviceId = 'unsupported_platform_device_id';
    }
  } catch (e) {
    _deviceId = 'error_getting_device_id';
  }

  return _deviceId!;
}

  Future<void> login(AuthProvider provider) async {
    final credentials = await _getOAuthCredentials(provider);

    final response = await _apiClient.post('/auth/login', {
      'provider': provider.name,
      'credentials': credentials,
      'device_id': await _getDeviceId(),
    });

    await _storeTokens(
      response['access_token'],
      response['refresh_token'],
    );
  }

  Future<void> _storeTokens(String access, String refresh) async {
    await _secureStorage.write(key: 'access_token', value: access);
    await _secureStorage.write(key: 'refresh_token', value: refresh);
  }

  Future<String?> getAccessToken() async {
    final token = await _secureStorage.read(key: 'access_token');

    if (token == null) return null;

    if (_isTokenExpired(token)) {
      return await _refreshToken();
    }

    return token;
  }

  Future<String?> refreshToken() async {
    final refreshToken = await _secureStorage.read(key: 'refresh_token');

    try {
      final response = await _apiClient.post('/auth/refresh', {
        'refresh_token': refreshToken,
        'device_id': await _getDeviceId(),
      });

      await _storeTokens(
        response['access_token'],
        response['refresh_token'],
      );

      return response['access_token'];
    } catch (e) {
      await logout();
      throw SessionExpiredException();
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    // Outras lógicas como limpar device_id, navegar para login, etc.
  }
  Future<bool> hasValidSession() async {
  final token = await getAccessToken();
  return token != null;
   }

  // Aqui você ainda precisa definir os métodos que não foram mostrados:
  // - _getOAuthCredentials
  // - _getDeviceId
  // - _isTokenExpired
  // - _refreshToken (provavelmente já implementado)
}
