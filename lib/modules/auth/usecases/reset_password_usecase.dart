
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

class ResetPasswordUseCase {
  final AuthRepository _repository;

  ResetPasswordUseCase(this._repository);

  Future<Either<String, void>> call({
    required String email,
  }) async {
    if (email.isEmpty) {
      return const Left('Email é obrigatório');
    }

    if (!_isValidEmail(email)) {
      return const Left('Email inválido');
    }

    return await _repository.resetPassword(email: email);
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }
}

final resetPasswordUseCaseProvider = Provider<ResetPasswordUseCase>((ref) {
  return ResetPasswordUseCase(ref.watch(authRepositoryProvider));
});
