import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartz/dartz.dart';
import 'package:cantico_novo/core/observability/logger.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';

// State
class AuthState {
  final UserEntity? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    UserEntity? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

// Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;
  final Logger _logger;

  AuthNotifier(
    this._loginUseCase,
    this._registerUseCase,
    this._logoutUseCase,
    this._resetPasswordUseCase,
    this._logger,
  ) : super(const AuthState()) {
    _checkSession();
  }

  Future<void> _checkSession() async {
    state = state.copyWith(isLoading: true);

    try {
      // Verificar se há sessão válida
      final result = await _loginUseCase.checkSession();

      result.fold(
        (error) {
          state = state.copyWith(
            isLoading: false,
            isAuthenticated: false,
          );
        },
        (user) {
          state = state.copyWith(
            user: user,
            isLoading: false,
            isAuthenticated: true,
          );

          _logger.log(
            level: LogLevel.info,
            message: 'Session restored for user: ${user.email}',
            module: 'AuthModule',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
      );
    }
  }

  Future<Either<String, UserEntity>> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    _logger.log(
      level: LogLevel.info,
      message: 'Login attempt for email: $email',
      module: 'AuthModule',
    );

    try {
      final result = await _loginUseCase(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );

      return result.fold(
        (error) {
          state = state.copyWith(
            isLoading: false,
            error: error,
          );

          _logger.log(
            level: LogLevel.error,
            message: 'Login failed: $error',
            module: 'AuthModule',
          );

          return Left(error);
        },
        (user) {
          state = state.copyWith(
            user: user,
            isLoading: false,
            isAuthenticated: true,
          );

          _logger.log(
            level: LogLevel.info,
            message: 'Login successful for user: ${user.email}',
            module: 'AuthModule',
            metadata: {
              'userId': user.id,
              'deviceId': user.deviceId,
            },
          );

          return Right(user);
        },
      );
    } catch (e) {
      final errorMessage = 'Erro inesperado ao fazer login';
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );

      _logger.log(
        level: LogLevel.error,
        message: 'Login exception: $e',
        module: 'AuthModule',
      );

      return Left(errorMessage);
    }
  }

  Future<Either<String, UserEntity>> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    _logger.log(
      level: LogLevel.info,
      message: 'Google OAuth login attempt',
      module: 'AuthModule',
    );

    try {
      final result = await _loginUseCase.loginWithGoogle();

      return result.fold(
        (error) {
          state = state.copyWith(
            isLoading: false,
            error: error,
          );

          _logger.log(
            level: LogLevel.error,
            message: 'Google login failed: $error',
            module: 'AuthModule',
          );

          return Left(error);
        },
        (user) {
          state = state.copyWith(
            user: user,
            isLoading: false,
            isAuthenticated: true,
          );

          _logger.log(
            level: LogLevel.info,
            message: 'Google login successful for user: ${user.email}',
            module: 'AuthModule',
          );

          return Right(user);
        },
      );
    } catch (e) {
      final errorMessage = 'Erro ao fazer login com Google';
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );

      _logger.log(
        level: LogLevel.error,
        message: 'Google login exception: $e',
        module: 'AuthModule',
      );

      return Left(errorMessage);
    }
  }

  Future<Either<String, UserEntity>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    _logger.log(
      level: LogLevel.info,
      message: 'Registration attempt for email: $email',
      module: 'AuthModule',
    );

    try {
      final result = await _registerUseCase(
        fullName: fullName,
        email: email,
        password: password,
      );

      return result.fold(
        (error) {
          state = state.copyWith(
            isLoading: false,
            error: error,
          );

          _logger.log(
            level: LogLevel.error,
            message: 'Registration failed: $error',
            module: 'AuthModule',
          );

          return Left(error);
        },
        (user) {
          state = state.copyWith(
            user: user,
            isLoading: false,
            isAuthenticated: true,
          );

          _logger.log(
            level: LogLevel.info,
            message: 'Registration successful for user: ${user.email}',
            module: 'AuthModule',
            metadata: {
              'userId': user.id,
            },
          );

          return Right(user);
        },
      );
    } catch (e) {
      final errorMessage = 'Erro inesperado ao criar conta';
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );

      _logger.log(
        level: LogLevel.error,
        message: 'Registration exception: $e',
        module: 'AuthModule',
      );

      return Left(errorMessage);
    }
  }

  Future<Either<String, void>> resetPassword({
    required String email,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    _logger.log(
      level: LogLevel.info,
      message: 'Password reset attempt for email: $email',
      module: 'AuthModule',
    );

    try {
      final result = await _resetPasswordUseCase(email: email);

      state = state.copyWith(isLoading: false);

      result.fold(
        (error) {
          _logger.log(
            level: LogLevel.error,
            message: 'Password reset failed: $error',
            module: 'AuthModule',
          );
        },
        (_) {
          _logger.log(
            level: LogLevel.info,
            message: 'Password reset email sent to: $email',
            module: 'AuthModule',
          );
        },
      );

      return result;
    } catch (e) {
      final errorMessage = 'Erro ao enviar email de redefinição';
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );

      _logger.log(
        level: LogLevel.error,
        message: 'Password reset exception: $e',
        module: 'AuthModule',
      );

      return Left(errorMessage);
    }
  }

  Future<void> logout() async {
    _logger.log(
      level: LogLevel.info,
      message: 'Logout initiated for user: ${state.user?.email}',
      module: 'AuthModule',
    );

    await _logoutUseCase();

    state = const AuthState();

    _logger.log(
      level: LogLevel.info,
      message: 'Logout completed',
      module: 'AuthModule',
    );
  }
}

// Provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(loginUseCaseProvider),
    ref.watch(registerUseCaseProvider),
    ref.watch(logoutUseCaseProvider),
    ref.watch(resetPasswordUseCaseProvider),
    Logger.instance,
  );
});

enum CustomAuthProvider {
  google,
  facebook,
  apple,
  // Adicione os que precisar
}
extension AuthProviderExtension on AuthProvider {
  String get name {
    switch (this) {
      case AuthProvider.google:
        return 'google';
      case AuthProvider.apple:
        return 'apple';
    }
  }
}
