
import 'package:myapp/core/security/token_manager.dart';
import 'package:myapp/modules/auth/repositories/auth_repository.dart';

class AuthService {
  final AuthRepository _authRepository;
  final TokenManager _tokenManager;

  AuthService({
    required AuthRepository authRepository,
    required TokenManager tokenManager,
  })  : _authRepository = authRepository,
        _tokenManager = tokenManager;

  Future<void> login(String email, String password) async {
    await _authRepository.login(email, password);
  }

  Future<void> logout() async {
    await _authRepository.logout();
  }

  Future<String?> getAccessToken() async {
    return await _tokenManager.getAccessToken();
  }

  Future<void> refreshToken() async {
    // Implement refresh token logic here if needed
  }
}
