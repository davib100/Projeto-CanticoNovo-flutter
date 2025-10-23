import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myapp/core/services/api_client.dart';
import 'package:myapp/core/security/token_manager.dart';

class AuthService {
  final ApiClient _apiClient;
  final TokenManager _tokenManager;
  final GoogleSignIn _googleSignIn;

  AuthService({
    required ApiClient apiClient,
    required TokenManager tokenManager,
    required GoogleSignIn googleSignIn,
  })  : _apiClient = apiClient,
        _tokenManager = tokenManager,
        _googleSignIn = googleSignIn;

  Future<bool> hasValidSession() async {
    return await _tokenManager.getAccessToken() != null;
  }

  Future<void> login(String email, String password) async {
    final response = await _apiClient.post('/auth/login', {
      'email': email,
      'password': password,
    });

    if (response.containsKey('accessToken')) {
      await _tokenManager.storeAccessToken(response['accessToken']);
    } else {
      throw Exception('Login failed: Access token not found in response');
    }
  }

  Future<void> logout() async {
    await _tokenManager.deleteTokens();
    await _googleSignIn.signOut();
  }
}
