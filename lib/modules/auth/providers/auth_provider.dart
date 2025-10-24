import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartz/dartz.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/observability/observability_service.dart';
import '../../auth/usecases/logout_usecase.dart';
import '../../../shared/entities/user_entity.dart';
import '../usecases/login_usecase.dart';
import '../usecases/register_usecase.dart';
import '../usecases/reset_password_usecase.dart';
import '../repositories/auth_repository_impl.dart';
import '../../../core/security/auth_service.dart';
import '../../../core/db/database_adapter_impl.dart';
import '../../../core/services/api_client.dart';
import '../../../core/security/token_manager.dart';

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
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;
  final ObservabilityService _observability;

  AuthNotifier(
    this._loginUseCase,
    this._registerUseCase,
    this._logoutUseCase,
    this._resetPasswordUseCase,
  )   : _observability = ObservabilityService(),
        super(const AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _loginUseCase(email: email, password: password);
    result.fold(
      (failure) {
        _observability.addBreadcrumb(
          'Login failed',
          category: 'auth',
          level: SentryLevel.error,
          data: {'email': email, 'error': failure.toString()},
        );
        state = state.copyWith(isLoading: false, error: failure.toString());
      },
      (user) {
        final loggedUser = user as UserEntity;
        _observability.addBreadcrumb(
          'Login successful',
          category: 'auth',
          level: SentryLevel.info,
          data: {'userId': loggedUser.id},
        );
        state = state.copyWith(isLoading: false, user: loggedUser, isAuthenticated: true);
      },
    );
  }

  Future<void> register(String fullName, String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _registerUseCase(
        fullName: fullName, email: email, password: password);
    result.fold(
      (failure) {
        _observability.addBreadcrumb(
          'Registration failed',
          category: 'auth',
          level: SentryLevel.error,
          data: {'email': email, 'error': failure.toString()},
        );
        state = state.copyWith(isLoading: false, error: failure.toString());
      },
      (user) {
        final registeredUser = user as UserEntity;
        _observability.addBreadcrumb(
          'Registration successful',
          category: 'auth',
          level: SentryLevel.info,
          data: {'userId': registeredUser.id},
        );
        state = state.copyWith(isLoading: false, user: registeredUser, isAuthenticated: true);
      },
    );
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _logoutUseCase();
      _observability.addBreadcrumb(
        'Logout successful',
        category: 'auth',
        level: SentryLevel.info,
        data: {'userId': state.user?.id},
      );
      state = const AuthState(); // Reset state to initial
    } catch (failure, stackTrace) {
      _observability.addBreadcrumb(
        'Logout failed',
        category: 'auth',
        level: SentryLevel.error,
        data: {'userId': state.user?.id, 'error': failure.toString()},
      );
       _observability.captureException(
        failure,
        stackTrace: stackTrace,
        endpoint: 'logout',
      );
      state = state.copyWith(isLoading: false, error: failure.toString());
    }
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _resetPasswordUseCase(email: email);
    result.fold(
      (failure) {
        _observability.addBreadcrumb(
          'Password reset failed',
          category: 'auth',
          level: SentryLevel.error,
          data: {'email': email, 'error': failure.toString()},
        );
        state = state.copyWith(isLoading: false, error: failure.toString());
      },
      (_) {
        _observability.addBreadcrumb(
          'Password reset request successful',
          category: 'auth',
          level: SentryLevel.info,
          data: {'email': email},
        );
        state = state.copyWith(isLoading: false);
      },
    );
  }
}

// Providers
final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) {
  final dbAdapter = ref.watch(databaseAdapterProvider);
  final apiClient = ref.watch(httpServiceProvider);
  final tokenManager = ref.watch(tokenManagerProvider);
  final authService = ref.watch(authServiceProvider);

  return AuthRepositoryImpl(
    remoteDataSource: AuthRemoteDataSource(apiClient),
    localDataSource: AuthLocalDataSource(dbAdapter),
    authService: authService,
    tokenManager: tokenManager,
  );
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LoginUseCase(repository);
});

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return RegisterUseCase(repository);
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LogoutUseCase(repository);
});

final resetPasswordUseCaseProvider = Provider<ResetPasswordUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return ResetPasswordUseCase(repository);
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final loginUseCase = ref.watch(loginUseCaseProvider);
  final registerUseCase = ref.watch(registerUseCaseProvider);
  final logoutUseCase = ref.watch(logoutUseCaseProvider);
  final resetPasswordUseCase = ref.watch(resetPasswordUseCaseProvider);
  return AuthNotifier(loginUseCase, registerUseCase, logoutUseCase, resetPasswordUseCase);
});

// Dependent providers that should already exist in your project
final databaseAdapterProvider = Provider<DatabaseAdapterImpl>((ref) => throw UnimplementedError());
final httpServiceProvider = Provider<ApiClient>((ref) => throw UnimplementedError());
final tokenManagerProvider = Provider<TokenManager>((ref) => throw UnimplementedError());
final authServiceProvider = Provider<AuthService>((ref) => throw UnimplementedError());
