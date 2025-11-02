import 'package:dartz/dartz.dart';
import '../../../core/observability/observability_service.dart';
import '../../../core/security/auth_service.dart';
import '../datasource/auth_local_datasource.dart';
import '../datasource/auth_remote_datasource.dart';
import '../repositories/auth_repository.dart';
import '../../../shared/entities/user_entity.dart';
import '../../../shared/models/session_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final AuthService _authService;
  final ObservabilityService _observabilityService;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required AuthService authService,
    required ObservabilityService observabilityService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _authService = authService,
        _observabilityService = observabilityService;

  @override
  Future<Either<String, UserEntity>> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final response = await _remoteDataSource.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );

      final user = UserEntity.fromJson(response['user']);
      final session = SessionModel.fromJson(response['session']);

      await _localDataSource.saveUser(user);
      await _localDataSource.saveSession(session);

      return Right(user);
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Error during standard login',
        extra: {'email': email},
      );
      return Left(_handleAuthError(e));
    }
  }

  @override
  Future<Either<String, UserEntity>> loginWithGoogle() async {
    try {
      final idToken = await _authService.signInWithGoogle();
      if (idToken == null) {
        return const Left('Login com Google cancelado ou falhou.');
      }

      final response = await _remoteDataSource.loginWithGoogle(idToken: idToken);

      final user = UserEntity.fromJson(response['user']);
      final session = SessionModel.fromJson(response['session']);

      await _localDataSource.saveUser(user);
      await _localDataSource.saveSession(session);

      return Right(user);
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Error during Google login',
      );
      return const Left('Ocorreu um erro inesperado durante o login com Google.');
    }
  }

  @override
  Future<Either<String, UserEntity>> loginWithMicrosoft() async {
    return const Left('Login com Microsoft ainda não implementado.');
  }

  @override
  Future<Either<String, UserEntity>> loginWithFacebook() async {
    return const Left('Login com Facebook ainda não implementado.');
  }

  @override
  Future<Either<String, UserEntity>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _remoteDataSource.register(
        fullName: fullName,
        email: email,
        password: password,
      );

      final user = UserEntity.fromJson(response['user']);
      final session = SessionModel.fromJson(response['session']);

      await _localDataSource.saveUser(user);
      await _localDataSource.saveSession(session);

      return Right(user);
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Error during registration',
        extra: {'email': email},
      );
      return Left(_handleAuthError(e));
    }
  }

  @override
  Future<Either<String, void>> resetPassword({required String email}) async {
    try {
      await _remoteDataSource.resetPassword(email: email);
      return const Right(null);
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Error during password reset request',
        extra: {'email': email},
      );
      return Left(_handleAuthError(e));
    }
  }
  
  @override
  Future<Either<String, void>> confirmResetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _remoteDataSource.confirmResetPassword(
        token: token,
        newPassword: newPassword,
      );
      return const Right(null);
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Error confirming password reset',
      );
      return Left(_handleAuthError(e));
    }
  }


  @override
  Future<Either<String, UserEntity>> checkSession() async {
    try {
      final hasSession = await _localDataSource.hasValidSession();
      if (!hasSession) {
        return const Left('Nenhuma sessão válida encontrada.');
      }

      final user = await _localDataSource.getUser();
      if (user == null) {
        await _localDataSource.clearSession();
        return const Left('Usuário da sessão não encontrado.');
      }

      return Right(user);
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Error checking session',
      );
      return const Left('Erro ao verificar a sessão.');
    }
  }

  @override
  Future<void> logout() async {
    try {
      final session = await _localDataSource.getSession();
      if (session != null) {
        _remoteDataSource.logout(deviceId: session.deviceId).ignore();
      }
      
      await _authService.signOut();
      await _localDataSource.clearSession();

    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Error during logout',
      );
      await _localDataSource.clearSession();
    }
  }

  @override
  Future<Either<String, void>> revokeSession({required String deviceId}) async {
    try {
      await _remoteDataSource.revokeSession(deviceId: deviceId);
      return const Right(null);
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        hint: 'Error revoking session',
        extra: {'deviceId': deviceId},
      );
      return const Left('Erro ao revogar a sessão do dispositivo.');
    }
  }

  String _handleAuthError(Object e) {
    final errorString = e.toString().toLowerCase();
    if (errorString.contains('401') || errorString.contains('invalid_credentials')) {
      return 'Email ou senha incorretos.';
    } else if (errorString.contains('403') || errorString.contains('permission_denied')) {
      return 'Permissão negada. Outro dispositivo pode estar conectado.';
    } else if (errorString.contains('409') || errorString.contains('already_exists')) {
      return 'Este email já está cadastrado.';
    } else if (errorString.contains('404') || errorString.contains('not_found')) {
      return 'O recurso solicitado não foi encontrado.';
    } else if (errorString.contains('network') || errorString.contains('unavailable')) {
      return 'Erro de conexão. Verifique sua internet e tente novamente.';
    }
    return 'Ocorreu um erro inesperado. Tente novamente mais tarde.';
  }
}
