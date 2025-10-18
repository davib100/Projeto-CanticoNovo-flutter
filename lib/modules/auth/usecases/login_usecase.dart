import 'package:myapp/core/security/auth_service.dart';

class LoginUseCase {
  final AuthService _authService;

  LoginUseCase({required AuthService authService}) : _authService = authService;

  Future<void> call(String email, String password) async {
    await _authService.login(email, password);
  }
}
