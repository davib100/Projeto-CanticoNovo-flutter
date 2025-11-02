import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/observability/logger.dart';
import '../../../shared/utils/validators.dart';
import '../../../core/queue/rate_limiter.dart';
import '../../..//shared/utils/sanitizer.dart';
import '../../../shared/entities/user_entity.dart';
import '../repositories/auth_repository.dart';
import '../providers/auth_provider.dart' hide loggerProvider, keyedRateLimiterProvider, sanitizerProvider;

/// Resultado da validação de força de senha
class PasswordStrengthResult {
  final bool isValid;
  final int score; // 0-5
  final List<String> suggestions;

  const PasswordStrengthResult({
    required this.isValid,
    required this.score,
    required this.suggestions,
  });
}

/// Use case para registro de usuário com validações robustas
class RegisterUseCase {
  final AuthRepository _repository;
  final Logger _logger;
  final KeyedRateLimiter _rateLimiter;
  final Sanitizer _sanitizer;

  RegisterUseCase(
    this._repository,
    this._logger,
    this._rateLimiter,
    this._sanitizer,
  );

  /// Registra novo usuário
  /// 
  /// Validações:
  /// - Nome válido (2-100 caracteres)
  /// - Email válido e não descartável
  /// - Senha forte (8+ chars, maiúsc, minúsc, número)
  /// - Rate limiting (3 registros/hora por IP)
  /// 
  /// Retorna [Right(UserEntity)] em sucesso
  /// Retorna [Left(String)] com mensagem de erro
  Future<Either<String, UserEntity>> call({
    required String fullName,
    required String email,
    required String password,
    bool termsAccepted = false,
  }) async {
    final correlationId = _logger.generateCorrelationId();
    
    try {
      // 1. Verificar se termos foram aceitos
      if (!termsAccepted) {
        return const Left('Você deve aceitar os termos de uso');
      }

      // 2. Validar inputs
     final validationResult = _validateInputs(fullName, email, password);
if (validationResult != null) {
  _logger.warning(
    'Registration validation failed: $validationResult | '
    'Module: RegisterUseCase | '
    'CID: $correlationId | '
    'Metadata: ${{
      'email': _maskEmail(email),
    }}',
  );
  return Left(validationResult);
}


      // 3. Verificar rate limiting (por IP ou dispositivo)
final rateLimitKey = 'register:${email.toLowerCase()}';
if (!await _rateLimiter.tryAcquire(
  rateLimitKey,
  maxAttempts: 3,
  window: const Duration(hours: 1),
)) {
  final retryAfter = _rateLimiter.getRetryAfter(rateLimitKey);

  _logger.warning(
    'Registration rate limit exceeded | '
    'Module: RegisterUseCase | '
    'CID: $correlationId | '
    'Metadata: ${{
      'email': _maskEmail(email),
      'retryAfter': retryAfter.inMinutes,
    }}',
  );

  return Left(
    'Muitas tentativas de registro. Tente novamente em ${retryAfter.inMinutes} minutos.',
  );
}


      // 4. Sanitizar inputs
      final sanitizedFullName = _sanitizer.sanitizeText(fullName.trim());
      final sanitizedEmail = email.toLowerCase().trim();

      // 5. Log tentativa de registro
    _logger.info(
  'Registration attempt | '
  'Module: RegisterUseCase | '
  'CID: $correlationId | '
  'Metadata: ${{
    'email': _maskEmail(sanitizedEmail),
    'nameLength': sanitizedFullName.length,
  }}',
);


      // 6. Chamar repository
      final result = await _repository.register(
        fullName: sanitizedFullName,
        email: sanitizedEmail,
        password: password,
      );

      // 7. Processar resultado
     return result.fold(
  (error) {
    _logger.error(
      'Registration failed: $error | '
      'Module: RegisterUseCase | '
      'CID: $correlationId | '
      'Metadata: ${{
        'email': _maskEmail(sanitizedEmail),
      }}',
    );

    return Left(_processError(error));
  },
  (user) {
    // Resetar rate limiter em sucesso
    _rateLimiter.reset(rateLimitKey);

    _logger.info(
      'Registration successful | '
      'Module: RegisterUseCase | '
      'CID: $correlationId | '
      'Metadata: ${{
        'userId': user.id,
        'email': _maskEmail(user.email),
      }}',
    );

    return Right(user);
  },
);
} catch (e, stackTrace) {
  _logger.error(
    'Unexpected error during registration | '
    'Module: RegisterUseCase | '
    'CID: $correlationId | '
    'Error: $e',
    e,
    stackTrace,
  );

  return const Left('Erro inesperado ao criar conta. Tente novamente.');
}
}

  /// Valida força da senha
  PasswordStrengthResult validatePasswordStrength(String password) {
    int score = 0;
    final suggestions = <String>[];

    if (password.length >= 8) {
      score++;
    } else {
      suggestions.add('Use pelo menos 8 caracteres');
    }

    if (RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    } else {
      suggestions.add('Adicione letras minúsculas');
    }

    if (RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    } else {
      suggestions.add('Adicione letras maiúsculas');
    }

    if (RegExp(r'\\d').hasMatch(password)) {
      score++;
    } else {
      suggestions.add('Adicione números');
    }

    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
      score++;
    } else {
      suggestions.add('Adicione caracteres especiais (!@#\$%...)');
    }

    // Penalizar senhas muito comuns
    final commonPasswords = [
      'password', '12345678', 'qwerty', 'abc123', 
      'senha123', 'admin123', '123456789'
    ];
    
    if (commonPasswords.contains(password.toLowerCase())) {
      score = 0;
      suggestions.clear();
      suggestions.add('Esta senha é muito comum. Use uma senha única.');
    }

    return PasswordStrengthResult(
      isValid: score >= 4,
      score: score,
      suggestions: suggestions,
    );
  }

  /// Valida inputs de registro
  String? _validateInputs(String fullName, String email, String password) {
    // Validar nome
    if (fullName.isEmpty) {
      return 'Nome é obrigatório';
    }

    if (fullName.trim().length < 2) {
      return 'Nome deve ter pelo menos 2 caracteres';
    }

    if (fullName.trim().length > 100) {
      return 'Nome muito longo (máximo 100 caracteres)';
    }

    if (!Validators.isValidName(fullName)) {
      return 'Nome contém caracteres inválidos';
    }

    // Validar email
    if (email.isEmpty) {
      return 'Email é obrigatório';
    }

    if (!Validators.isValidEmail(email)) {
      return 'Email inválido';
    }

    if (Validators.isDisposableEmail(email)) {
      return 'Email descartável não é permitido';
    }

    // Validar senha
    final passwordStrength = validatePasswordStrength(password);
    if (!passwordStrength.isValid) {
      return 'Senha fraca: ${passwordStrength.suggestions.join(', ')}';
    }

    return null;
  }

  /// Processa mensagens de erro do repository
  String _processError(String error) {
    if (error.contains('já cadastrado')) {
      return 'Este email já está em uso. Tente fazer login ou recuperar sua senha.';
    }

    if (error.contains('network') || error.contains('connection')) {
      return 'Erro de conexão. Verifique sua internet.';
    }

    if (error.contains('timeout')) {
      return 'Tempo esgotado. Tente novamente.';
    }

    return error;
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
final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(loggerProvider),
    ref.watch(keyedRateLimiterProvider),
    ref.watch(sanitizerProvider),
  );
});
