import 'package:myapp/core/security/auth_service.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

class LoginUseCase {
  final AuthService _authService;

  LoginUseCase({required AuthService authService}) : _authService = authService;

  Future<void> call(String email, String password) async {
    await _authService.login(email, password);
  }
  final AuthRepository _repository;

  Future<Either<String, UserEntity>> call({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    return await _repository.login(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
  }

  Future<Either<String, UserEntity>> loginWithGoogle() async {
    return await _repository.loginWithGoogle();
  }

  Future<Either<String, UserEntity>> checkSession() async {
    return await _repository.checkSession();
  }
}

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});
