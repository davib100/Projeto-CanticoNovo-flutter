import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/observability/logger.dart';
import '../../../shared/utils/validators.dart';
import '../../../core/queue/rate_limiter.dart';
import '../providers/auth_provider.dart' hide loggerProvider;
import '../../../shared/entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use case para login com validações robustas e rate limiting
class LoginUseCase {
  final AuthRepository _repository;
  final Logger _logger;
  final KeyedRateLimiter _rateLimiter;

  LoginUseCase(this._repository, this._logger, this._rateLimiter);

  /// Realiza login com email e senha
  ///
  /// Validações:
  /// - Email formato válido
  /// - Senha não vazia
  /// - Rate limiting (5 tentativas/15min)
  /// - Device ID presente
  ///
  /// Retorna [Right(UserEntity)] em sucesso
  /// Retorna [Left(String)] com mensagem de erro
  Future<Either<String, UserEntity>> call({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final correlationId = _logger.generateCorrelationId();

    try {
      // 1. Validar inputs
      final validationResult = _validateInputs(email, password);
      if (validationResult != null) {
        _logger.warning(
          'Login validation failed: $validationResult | '
          'Module: LoginUseCase | '
          'CID: $correlationId | '
          'Metadata: ${{'email': _maskEmail(email)}}',
        );
        return Left(validationResult);
      }

      // 2. Verificar rate limiting
      final rateLimitKey = 'login:${email.toLowerCase()}';
      if (!await _rateLimiter.tryAcquire(rateLimitKey)) {
        final retryAfter = _rateLimiter.getRetryAfter(rateLimitKey);

        _logger.warning(
          'Login rate limit exceeded | '
          'Module: LoginUseCase | '
          'CID: $correlationId | '
          'Metadata: ${{'email': _maskEmail(email), 'retryAfter': retryAfter.inSeconds}}',
        );

        return Left(
          'Muitas tentativas de login. Tente novamente em ${retryAfter.inMinutes} minutos.',
        );
      }

      // 3. Log tentativa de login (adaptado)
      _logger.info(
        'Login attempt | '
        'Module: LoginUseCase | '
        'CID: $correlationId | '
        'Metadata: ${{'email': _maskEmail(email), 'rememberMe': rememberMe}}',
      );

      // 4. Chamar repository
      final result = await _repository.login(
        email: email.toLowerCase().trim(),
        password: password,
        rememberMe: rememberMe,
      );

      // 5. Processar resultado
      return result.fold(
        (error) {
          // Incrementar contador de falhas no rate limiter
          _rateLimiter.recordFailure(rateLimitKey);

          _logger.error(
            'Login failed: $error | Module: LoginUseCase | CID: $correlationId | Metadata: ${{'email': _maskEmail(email)}}',
          );

          return Left(_processError(error));
        },
        (user) {
          // Resetar rate limiter em sucesso
          _rateLimiter.reset(rateLimitKey);

          _logger.info(
            'Login successful | Module: LoginUseCase | CID: $correlationId | Metadata: ${{'userId': user.id, 'email': _maskEmail(user.email)}}',
          );

          return Right(user);
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected error during login | Module: LoginUseCase | CID: $correlationId',
        e,
        stackTrace,
      );

      return const Left('Erro inesperado ao fazer login. Tente novamente.');
    }
  }

  /// Login com Google OAuth
  Future<Either<String, UserEntity>> loginWithGoogle() async {
    final correlationId = _logger.generateCorrelationId();

    try {
      _logger.info(
        'Google OAuth login attempt | Module: LoginUseCase | CID: $correlationId',
      );

      final result = await _repository.loginWithGoogle();

      return result.fold(
        (error) {
          _logger.error(
            'Google OAuth login failed: $error | Module: LoginUseCase | CID: $correlationId',
          );
          return Left(_processError(error));
        },
        (user) {
          _logger.info(
            'Google OAuth login successful | Module: LoginUseCase | CID: $correlationId | Metadata: ${{'userId': user.id, 'email': _maskEmail(user.email), 'provider': 'google'}}',
          );
          return Right(user);
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected error during Google OAuth login | Module: LoginUseCase | CID: $correlationId',
        e,
        stackTrace,
      );

      return const Left('Erro ao fazer login com Google. Tente novamente.');
    }
  }

  /// Login com Microsoft OAuth
  Future<Either<String, UserEntity>> loginWithMicrosoft() async {
    final correlationId = _logger.generateCorrelationId();

    try {
      _logger.info(
        'Microsoft OAuth login attempt | Module: LoginUseCase | CID: $correlationId',
      );

      final result = await _repository.loginWithMicrosoft();

      return result.fold(
        (error) {
          _logger.error(
            'Microsoft OAuth login failed: $error | Module: LoginUseCase | CID: $correlationId',
          );
          return Left(_processError(error));
        },
        (user) {
          _logger.info(
            'Microsoft OAuth login successful | Module: LoginUseCase | CID: $correlationId | Metadata: ${{'userId': user.id, 'email': _maskEmail(user.email), 'provider': 'microsoft'}}',
          );
          return Right(user);
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected error during Microsoft OAuth login | Module: LoginUseCase | CID: $correlationId',
        e,
        stackTrace,
      );

      return const Left('Erro ao fazer login com Microsoft. Tente novamente.');
    }
  }

  /// Login com Facebook OAuth
  Future<Either<String, UserEntity>> loginWithFacebook() async {
    final correlationId = _logger.generateCorrelationId();

    try {
      _logger.info(
        'Facebook OAuth login attempt | Module: LoginUseCase | CID: $correlationId',
      );

      final result = await _repository.loginWithFacebook();

      return result.fold(
        (error) {
          _logger.error(
            'Facebook OAuth login failed: $error | Module: LoginUseCase | CID: $correlationId',
          );
          return Left(_processError(error));
        },
        (user) {
          _logger.info(
            'Facebook OAuth login successful | Module: LoginUseCase | CID: $correlationId | Metadata: ${{'userId': user.id, 'email': _maskEmail(user.email), 'provider': 'facebook'}}',
          );
          return Right(user);
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected error during Facebook OAuth login | Module: LoginUseCase | CID: $correlationId',
        e,
        stackTrace,
      );

      return const Left('Erro ao fazer login com Facebook. Tente novamente.');
    }
  }

  /// Verifica se há sessão válida
  Future<Either<String, UserEntity>> checkSession() async {
    final correlationId = _logger.generateCorrelationId();

    try {
      _logger.info(
        'Checking session | Module: LoginUseCase | CID: $correlationId',
      );

      final result = await _repository.checkSession();

      return result.fold(
        (error) {
          _logger.warning(
            'Session check failed: $error | Module: LoginUseCase | CID: $correlationId',
          );
          return Left(error);
        },
        (user) {
          _logger.info(
            'Session valid | Module: LoginUseCase | CID: $correlationId | Metadata: ${{'userId': user.id, 'email': _maskEmail(user.email)}}',
          );
          return Right(user);
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected error checking session | Module: LoginUseCase | CID: $correlationId',
        e,
        stackTrace,
      );

      return const Left('Erro ao verificar sessão');
    }
  }

  /// Valida inputs de login
  String? _validateInputs(String email, String password) {
    if (email.isEmpty) {
      return 'Email é obrigatório';
    }

    if (!Validators.isValidEmail(email)) {
      return 'Email inválido';
    }

    if (password.isEmpty) {
      return 'Senha é obrigatória';
    }

    if (password.length < 3) {
      return 'Senha muito curta';
    }

    return null;
  }

  /// Processa mensagens de erro do repository
  String _processError(String error) {
    // Mapear erros técnicos para mensagens amigáveis
    if (error.contains('network') || error.contains('connection')) {
      return 'Erro de conexão. Verifique sua internet.';
    }

    if (error.contains('timeout')) {
      return 'Tempo esgotado. Tente novamente.';
    }

    if (error.contains('401') || error.contains('incorretos')) {
      return 'Email ou senha incorretos';
    }

    if (error.contains('403') || error.contains('bloqueada')) {
      return 'Conta temporariamente bloqueada. Tente novamente mais tarde.';
    }

    if (error.contains('dispositivo')) {
      return 'Outro dispositivo está conectado. Faça logout no outro dispositivo.';
    }

    // Retornar erro original se não for mapeado
    return error;
  }

  /// Mascara email para logs (privacidade)
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
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(loggerProvider),
    ref.watch(keyedRateLimiterProvider),
  );
});
final keyedRateLimiterProvider = Provider<KeyedRateLimiter>(
  (ref) => KeyedRateLimiter(),
);
