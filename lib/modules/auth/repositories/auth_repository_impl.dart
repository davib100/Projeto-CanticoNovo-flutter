import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myapp/core/security/token_manager.dart';
import 'package:myapp/modules/auth/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final http.Client _client;
  final TokenManager _tokenManager;

  AuthRepositoryImpl({
    required http.Client client,
    required TokenManager tokenManager,
  }) : _client = client,
       _tokenManager = tokenManager;

  @override
  Future<void> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('https://api.example.com/login'),
      body: json.encode({'email': email, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['token'];
      await _tokenManager.storeAccessToken(token);
    } else {
      throw Exception('Failed to login');
    }
  }

  @override
  Future<void> logout() async {
    await _tokenManager.deleteAccessToken();
  }
}
