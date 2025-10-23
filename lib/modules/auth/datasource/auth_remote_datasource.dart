
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../../core/security/device_info_service.dart';
//import '../../../shared/models/user_model.dart';
//import '../../../shared/models/session_model.dart';

class AuthRemoteDataSource {
  final ApiClient _apiClient;
  final DeviceInfoService _deviceInfoService;

  AuthRemoteDataSource(this._apiClient, this._deviceInfoService);

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final deviceId = await _deviceInfoService.getDeviceId();

    final response = await _apiClient.post(
      '/auth/login',
      {
        'email': email,
        'password': password,
        'deviceId': deviceId,
        'rememberMe': rememberMe,
      },
    );

    return response;
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
  }) async {
    final deviceId = await _deviceInfoService.getDeviceId();

    final response = await _apiClient.post(
      '/auth/google',
      {
        'idToken': idToken,
        'deviceId': deviceId,
      },
    );

    return response;
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final deviceId = await _deviceInfoService.getDeviceId();

    final response = await _apiClient.post(
      '/auth/register',
      {
        'fullName': fullName,
        'email': email,
        'password': password,
        'deviceId': deviceId,
      },
    );

    return response;
  }

  Future<void> resetPassword({
    required String email,
  }) async {
    await _apiClient.post(
      '/auth/reset-password',
      {
        'email': email,
      },
    );
  }

  Future<Map<String, dynamic>> refreshToken({
    required String refreshToken,
  }) async {
    final response = await _apiClient.post(
      '/auth/refresh',
      {
        'refreshToken': refreshToken,
      },
    );

    return response;
  }

  Future<void> logout({
    required String deviceId,
  }) async {
    await _apiClient.post(
      '/auth/logout',
      {
        'deviceId': deviceId,
      },
    );
  }

  Future<void> revokeSession({
    required String deviceId,
  }) async {
    await _apiClient.post(
      '/auth/revoke-session',
      {
        'deviceId': deviceId,
      },
    );
  }
}

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(
    ref.watch(apiClientProvider),
    ref.watch(deviceInfoServiceProvider),
  );
});
