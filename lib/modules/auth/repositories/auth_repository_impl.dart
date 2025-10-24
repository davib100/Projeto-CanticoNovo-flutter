import 'package:dartz/dartz.dart';
//import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
//import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/observability/observability_service.dart';
import '../../auth/datasource/auth_local_datasource.dart';
import '../../auth/datasource/auth_remote_datasource.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../shared/entities/user_entity.dart';
import '../../../shared/models/session_model.dart';
import '../../../shared/models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final GoogleSignIn _googleSignIn;
  final ObservabilityService _observabilityService;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required GoogleSignIn googleSignIn,
    required ObservabilityService observabilityService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _googleSignIn = googleSignIn,
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

      final user = UserModel.fromJson(response['user']);
      final session = SessionModel.fromJson(response['session']);

      await _localDataSource.saveUser(user.toEntity());
      await _localDataSource.saveSession(session);

      return Right(user.toEntity());
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        extra: {
          'module': 'AuthRepository',
        },
      );

      if (e.toString().contains('401')) {
        return const Left('Email ou senha incorretos');
      } else if (e.toString().contains('403')) {
        return const Left(
          'Outro dispositivo está conectado. Faça logout no outro dispositivo.',
        );
      } else if (e.toString().contains('network')) {
        return const Left('Erro de conexão. Verifique sua internet.');
      }

      return const Left('Erro ao fazer login. Tente novamente.');
    }
  }

  @override
  Future<Either<String, UserEntity>> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return const Left('Login cancelado');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return const Left('Falha ao obter token do Google');
      }

      final response = await _remoteDataSource.loginWithGoogle(
        idToken: idToken,
      );

      final user = UserModel.fromJson(response['user']);
      final session = SessionModel.fromJson(response['session']);

      await _localDataSource.saveUser(user.toEntity());
      await _localDataSource.saveSession(session);

      return Right(user.toEntity());
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        extra: {
          'module': 'AuthRepository',
        },
      );

      return const Left('Erro ao fazer login com Google');
    }
  }

  @override
  Future<Either<String, UserEntity>> loginWithMicrosoft() async {
    return const Left('Login com Microsoft não implementado');
  }

  @override
  Future<Either<String, UserEntity>> loginWithFacebook() async {
    return const Left('Login com Facebook não implementado');
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

      final user = UserModel.fromJson(response['user']);
      final session = SessionModel.fromJson(response['session']);

      await _localDataSource.saveUser(user.toEntity());
      await _localDataSource.saveSession(session);

      return Right(user.toEntity());
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        extra: {
          'module': 'AuthRepository',
        },
      );

      if (e.toString().contains('409')) {
        return const Left('Email já cadastrado');
      }

      return const Left('Erro ao criar conta. Tente novamente.');
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
        extra: {
          'module': 'AuthRepository',
        },
      );

      if (e.toString().contains('404')) {
        return const Left('Email não encontrado');
      }

      return const Left('Erro ao enviar email. Tente novamente.');
    }
  }

  @override
  Future<Either<String, UserEntity>> checkSession() async {
    try {
      final hasSession = await _localDataSource.hasValidSession();

      if (!hasSession) {
        return const Left('Sessão inválida');
      }

      final user = await _localDataSource.getUser();

      if (user == null) {
        return const Left('Usuário não encontrado');
      }

      final token = await _localDataSource.getToken();
      if (token == null) {
        return const Left('Token não encontrado');
      }

      return Right(user.toEntity());
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        extra: {
          'module': 'AuthRepository',
        },
      );

      return const Left('Erro ao verificar sessão');
    }
  }

  @override
  Future<void> logout() async {
    try {
      final session = await _localDataSource.getSession();

      if (session != null) {
        await _remoteDataSource.logout(deviceId: session.deviceId);
      }

      await _localDataSource.clearSession();
      await _googleSignIn.signOut();
    } catch (e, stackTrace) {
      _observabilityService.captureException(
        e,
        stackTrace: stackTrace,
        extra: {
          'module': 'AuthRepository',
        },
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
        extra: {
          'module': 'AuthRepository',
        },
      );

      return const Left('Erro ao revogar sessão');
    }
  }
}
