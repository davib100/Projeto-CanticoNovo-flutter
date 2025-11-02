
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/db/database_adapter.dart';
import '../../../core/observability/logger.dart';
import '../../../core/observability/observability_service.dart';
import '../../../core/queue/rate_limiter.dart';
import '../../../core/security/auth_service.dart';
import '../../../core/security/device_info_service.dart';
import '../../../core/security/token_manager.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/cache_service.dart';
import '../../../shared/entities/user_entity.dart';
import '../../../shared/utils/sanitizer.dart';
import '../datasource/auth_local_datasource.dart';
import '../datasource/auth_local_datasource_impl.dart';
import '../datasource/auth_remote_datasource.dart';
import '../repositories/auth_repository.dart';
import '../repositories/auth_repository_impl.dart';
import '../usecases/login_usecase.dart';
import '../usecases/logout_usecase.dart';
import '../usecases/register_usecase.dart';
import '../usecases/reset_password_usecase.dart';

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
    this._observability,
  ) : super(const AuthState());

  Future<dynamic> login(String email, String password) async {
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
        final loggedUser = user;
        _observability.addBreadcrumb(
          'Login successful',
          category: 'auth',
          level: SentryLevel.info,
          data: {'userId': loggedUser.id},
        );
        state = state.copyWith(
            isLoading: false, user: loggedUser, isAuthenticated: true);
      },
    );
    return result;
  }

  Future<dynamic> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _loginUseCase.loginWithGoogle();
    result.fold(
      (failure) {
        _observability.addBreadcrumb(
          'Google login failed',
          category: 'auth',
          level: SentryLevel.error,
          data: {'error': failure.toString()},
        );
        state = state.copyWith(isLoading: false, error: failure.toString());
      },
      (user) {
        final loggedUser = user;
        _observability.addBreadcrumb(
          'Google login successful',
          category: 'auth',
          level: SentryLevel.info,
          data: {'userId': loggedUser.id},
        );
        state = state.copyWith(
            isLoading: false, user: loggedUser, isAuthenticated: true);
      },
    );
    return result;
  }

  Future<dynamic> register(String fullName, String email, String password) async {
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
        final registeredUser = user;
        _observability.addBreadcrumb(
          'Registration successful',
          category: 'auth',
          level: SentryLevel.info,
          data: {'userId': registeredUser.id},
        );
        state = state.copyWith(
            isLoading: false, user: registeredUser, isAuthenticated: true);
      },
    );
    return result;
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

  Future<dynamic> resetPassword(String email) async {
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
    return result;
  }
}

// --- Core Providers ---

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

final observabilityServiceProvider = Provider<ObservabilityService>((ref) {
  return ObservabilityService();
});

// --- Datasource Providers ---

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  final dbAdapter = ref.watch(databaseAdapterProvider);
  return AuthLocalDataSourceImpl(dbAdapter);
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final apiClient = ref.watch(httpServiceProvider);
  final deviceInfoService = ref.watch(deviceInfoServiceProvider);
  return AuthRemoteDataSource(apiClient, deviceInfoService);
});

// --- Repository Provider ---

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
    authService: ref.watch(authServiceProvider),
    observabilityService: ref.watch(observabilityServiceProvider),
  );
});

// --- Use Case Providers ---

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final rateLimiter = ref.watch(keyedRateLimiterProvider);
  return LoginUseCase(repository, logger, rateLimiter);
});

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final rateLimiter = ref.watch(keyedRateLimiterProvider);
  final sanitizer = ref.watch(sanitizerProvider);
  return RegisterUseCase(repository, logger, rateLimiter, sanitizer);
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  final apiClient = ref.watch(apiClientProvider);
  return LogoutUseCase(repository, logger, cacheService, apiClient);
});

final resetPasswordUseCaseProvider = Provider<ResetPasswordUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final rateLimiter = ref.watch(keyedRateLimiterProvider);
  return ResetPasswordUseCase(repository, logger, rateLimiter);
});

// --- State Notifier Provider ---

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(loginUseCaseProvider),
    ref.watch(registerUseCaseProvider),
    ref.watch(logoutUseCaseProvider),
    ref.watch(resetPasswordUseCaseProvider),
    ref.watch(observabilityServiceProvider),
  );
});

// --- Unimplemented Core Dependencies (to be provided by the main app) ---

final databaseAdapterProvider =
    Provider<DatabaseAdapter>((ref) => throw UnimplementedError());
final httpServiceProvider =
    Provider<ApiClient>((ref) => throw UnimplementedError());
final tokenManagerProvider =
    Provider<TokenManager>((ref) => throw UnimplementedError());
final authServiceProvider =
    Provider<AuthService>((ref) => throw UnimplementedError());
final loggerProvider = Provider<Logger>((ref) => throw UnimplementedError());
final keyedRateLimiterProvider =
    Provider<KeyedRateLimiter>((ref) => throw UnimplementedError());
final sanitizerProvider =
    Provider<Sanitizer>((ref) => throw UnimplementedError());
final cacheServiceProvider =
    Provider<CacheService>((ref) => throw UnimplementedError());
final apiClientProvider = Provider<ApiClient>((ref) => throw UnimplementedError());
final deviceInfoServiceProvider =
    Provider<DeviceInfoService>((ref) => throw UnimplementedError());
