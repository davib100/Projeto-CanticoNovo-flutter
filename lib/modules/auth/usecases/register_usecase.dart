
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  RegisterUseCase(this._repository);

  Future<Either<String, UserEntity>> call({
    required String fullName,
    required String email,
    required String password,
  }) async {
    // Validações de negócio
    if (fullName.trim().length < 2) {
      return const Left('Nome deve ter pelo menos 2 caracteres');
    }

    if (!_isValidEmail(email)) {
      return const Left('Email inválido');
    }

    if (!_isStrongPassword(password)) {
      return const Left(
        'Senha deve ter pelo menos 8 caracteres, incluindo maiúsculas, minúsculas e números',
      );
    }

    return await _repository.register(
      fullName: fullName,
      email: email,
      password: password,
    );
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _isStrongPassword(String password) {
    if (password.length < 8) return false;
    if (!RegExp(r'[a-z]').hasMatch(password)) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;
    if (!RegExp(r'\d').hasMatch(password)) return false;
    return true;
  }
}

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(ref.watch(authRepositoryProvider));
});
