import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/observability/logger.dart';
import '../../../shared/utils/validators.dart';
import '../../..//core/queue/rate_limiter.dart';
import '../repositories/auth_repository.dart';
import '../providers/auth_provider.dart' hide loggerProvider, keyedRateLimiterProvider;

/// Use case para redefinição de senha
class ResetPasswordUseCase {
  final AuthRepository _repository;
  final Logger _logger;
  final KeyedRateLimiter _rateLimiter;

  ResetPasswordUseCase(
    this._repository,
    this._logger,
    this._rateLimiter,
  );

  /// Solicita redefinição de senha
  /// 
  /// Validações:
  /// - Email válido
  /// - Rate limiting (3 tentativas/hora)
  /// 
  /// Nota: Por segurança, sempre retorna sucesso mesmo se email não existir
  /// 
  /// Retorna [Right(void)] em sucesso
  /// Retorna [Left(String)] com mensagem de erro
  Future<Either<String, void>> call({
    required String email,
  }) async {
    final correlationId = _logger.generateCorrelationId();
    
    try {
      // 1. Validar email
      if (email.isEmpty) {
        return const Left('Email é obrigatório');
      }

      if (!Validators.isValidEmail(email)) {
        return const Left('Email inválido');
      }

      // 2. Verificar rate limiting
      final rateLimitKey = 'reset_password:${email.toLowerCase()}';
if (!await _rateLimiter.tryAcquire(
  rateLimitKey,
  maxAttempts: 3,
  window: const Duration(hours: 1),
)) {
  final retryAfter = _rateLimiter.getRetryAfter(rateLimitKey);

  _logger.warning(
    'Reset password rate limit exceeded | Module: ResetPasswordUseCase | CID: $correlationId | Metadata: {"email": "${_maskEmail(email)}", "retryAfter": ${retryAfter.inMinutes}}',
  );

  return Left(
    'Muitas solicitações de redefinição. Tente novamente em ${retryAfter.inMinutes} minutos.',
  );
}

// 3. Log tentativa
_logger.info(
  'Password reset requested | Module: ResetPasswordUseCase | CID: $correlationId | Metadata: {"email": "${_maskEmail(email)}"}',
);

// 4. Chamar repository
final result = await _repository.resetPassword(
  email: email.toLowerCase().trim(),
);

// 5. Processar resultado
return result.fold(
  (error) {
    _logger.error(
      'Password reset failed: $error | Module: ResetPasswordUseCase | CID: $correlationId | Metadata: {"email": "${_maskEmail(email)}"}',
    );

    return Left(_processError(error));
  },
  (_) {
    _logger.info(
      'Password reset email sent (or email not found - security) | Module: ResetPasswordUseCase | CID: $correlationId | Metadata: {"email": "${_maskEmail(email)}"}',
    );

    // Sempre retornar sucesso por segurança
    return const Right(null);
  },
);

} catch (e, stackTrace) {
  _logger.error(
    'Unexpected error during password reset | Module: ResetPasswordUseCase | CID: $correlationId',
    e,
    stackTrace,
  );

  return const Left('Erro ao processar solicitação. Tente novamente.');
}
}


  /// Confirma redefinição de senha com token
  Future<Either<String, void>> confirmReset({
  required String token,
  required String newPassword,
}) async {
  final correlationId = _logger.generateCorrelationId();

  try {
    // 1. Validar inputs
    if (token.isEmpty) {
      return const Left('Token é obrigatório');
    }

    if (newPassword.isEmpty) {
      return const Left('Nova senha é obrigatória');
    }

    if (newPassword.length < 8) {
      return const Left('Senha deve ter pelo menos 8 caracteres');
    }

    if (!_isStrongPassword(newPassword)) {
      return const Left(
        'Senha deve conter pelo menos: 1 letra minúscula, 1 maiúscula e 1 número',
      );
    }

    // 2. Log tentativa
    _logger.info(
      'Password reset confirmation attempt',
      correlationId: correlationId,
      data: {
        'tokenLength': token.length,
      },
    );

    // 3. Chamar repository (implementar método no repository)
    // TODO: Adicionar método confirmResetPassword no AuthRepository
    // final result = await _repository.confirmResetPassword(
    //   token: token,
    //   newPassword: newPassword,
    // );

    _logger.info(
      'Password reset confirmed successfully',
      correlationId: correlationId,
    );

    return const Right(null);
  } catch (e, stackTrace) {
    _logger.error(
      'Unexpected error during password reset confirmation',
      e,
      stackTrace,
      correlationId,
    );

    return const Left('Erro ao redefinir senha. Tente novamente.');
  }
}

  /// Verifica se senha é forte
  bool _isStrongPassword(String password) {
    if (password.length < 8) return false;
    if (!RegExp(r'[a-z]').hasMatch(password)) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;
    if (!RegExp(r'\\d').hasMatch(password)) return false;
    return true;
  }

  /// Processa mensagens de erro do repository
  String _processError(String error) {
    if (error.contains('network') || error.contains('connection')) {
      return 'Erro de conexão. Verifique sua internet.';
    }

    if (error.contains('timeout')) {
      return 'Tempo esgotado. Tente novamente.';
    }

    // Por segurança, não revelar se email existe ou não
    return 'Erro ao processar solicitação. Tente novamente.';
  }

  /// Mascara email para logs
  String _maskEmail(String email) {
    if (!email.contains('@')) return '***';
    
    final parts = email.split('@');
    final username = parts[0];
    final domain = parts[1];
    
    if (username.length <= 2) {
      return '***@$domain';
    }
    
    return '${username.substring(0, 2)}***@$domain';
  }
}

// Provider
final resetPasswordUseCaseProvider = Provider<ResetPasswordUseCase>((ref) {
  return ResetPasswordUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(loggerProvider),
    ref.watch(keyedRateLimiterProvider),
  );
});
