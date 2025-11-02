import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/observability/logger.dart';
import '../../../shared/utils/validators.dart';
import '../repositories/auth_repository.dart';
import '../providers/auth_provider.dart' hide loggerProvider;

class ConfirmResetPasswordUseCase {
  final AuthRepository _repository;
  final Logger _logger;

  ConfirmResetPasswordUseCase(this._repository, this._logger);

  Future<Either<String, void>> call({
    required String token,
    required String newPassword,
  }) async {
    final correlationId = _logger.generateCorrelationId();

    try {
      // 1. Validar inputs
      final validationError = _validateInputs(token, newPassword);
      if (validationError != null) {
        _logger.warning(
          'Confirm password reset validation failed: $validationError | '
          'Module: ConfirmResetPasswordUseCase | '
          'CID: $correlationId',
        );
        return Left(validationError);
      }

      _logger.info(
        'Attempting to confirm password reset | '
        'Module: ConfirmResetPasswordUseCase | '
        'CID: $correlationId',
      );

      // 2. Chamar o repositório
      final result = await _repository.confirmResetPassword(
        token: token,
        newPassword: newPassword,
      );

      // 3. Processar resultado
      return result.fold(
        (error) {
          _logger.error(
            'Password reset confirmation failed: $error | '
            'Module: ConfirmResetPasswordUseCase | '
            'CID: $correlationId',
          );
          return Left(error);
        },
        (_) {
          _logger.info(
            'Password reset confirmed successfully | '
            'Module: ConfirmResetPasswordUseCase | '
            'CID: $correlationId',
          );
          return const Right(null);
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected error during password reset confirmation | '
        'Module: ConfirmResetPasswordUseCase | '
        'CID: $correlationId',
        e,
        stackTrace,
      );
      return const Left('Ocorreu um erro inesperado. Tente novamente.');
    }
  }

  String? _validateInputs(String token, String newPassword) {
    if (token.isEmpty) {
      return 'O token de confirmação é obrigatório.';
    }
    final passwordError = Validators.password(newPassword);
    if (passwordError != null) {
      return passwordError;
    }
    return null;
  }
}

final confirmResetPasswordUseCaseProvider = Provider<ConfirmResetPasswordUseCase>((ref) {
  return ConfirmResetPasswordUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(loggerProvider),
  );
});
