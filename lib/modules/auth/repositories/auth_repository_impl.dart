import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/security/token_manager.dart';
import 'package:myapp/modules/auth/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cantico_novo/core/observability/logger.dart';
import '../shared/entities/user_entity.dart';
import '../shared/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/auth_local_datasource.dart';
import '../shared/models/user_model.dart';
import '../shared/models/session_model.dart';


class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final GoogleSignIn _googleSignIn;
  final Logger _logger;

  AuthRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
    this._googleSignIn,
    this._logger,
  );

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

      // Salvar localmente
      await _localDataSource.saveUser(user);
      await _localDataSource.saveSession(session);

      return Right(user);
    } catch (e) {
      _logger.log(
        level: LogLevel.error,
        message: 'Login error: $e',
        module: 'AuthRepository',
      );

      if (e.toString().contains('401')) {
        return const Left('Email ou senha incorretos');
      } else if (e.toString().contains('403')) {
        return const Left('Outro dispositivo está conectado. Faça logout no outro dispositivo.');
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

      await _localDataSource.saveUser(user);
      await _localDataSource.saveSession(session);

      return Right(user);
    } catch (e) {
      _logger.log(
        level: LogLevel.error,
        message: 'Google login error: $e',
        module: 'AuthRepository',
      );

      return const Left('Erro ao fazer login com Google');
    }
  }

  @override
  Future<Either<String, UserEntity>> loginWithMicrosoft() async {
    // TODO: Implementar Microsoft OAuth
    return const Left('Login com Microsoft não implementado');
  }

  @override
  Future<Either<String, UserEntity>> loginWithFacebook() async {
    // TODO: Implementar Facebook OAuth
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

      await _localDataSource.saveUser(user);
      await _localDataSource.saveSession(session);

      return Right(user);
    } catch (e) {
      _logger.log(
        level: LogLevel.error,
        message: 'Registration error: $e',
        module: 'AuthRepository',
      );

      if (e.toString().contains('409')) {
        return const Left('Email já cadastrado');
      }

      return const Left('Erro ao criar conta. Tente novamente.');
    }
  }

  @override
  Future<Either<String, void>> resetPassword({
    required String email,
  }) async {
    try {
      await _remoteDataSource.resetPassword(email: email);
      return const Right(null);
    } catch (e) {
      _logger.log(
        level: LogLevel.error,
        message: 'Reset password error: $e',
        module: 'AuthRepository',
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

      // Verificar token com backend
      final token = await _localDataSource.getToken();
      if (token == null) {
        return const Left('Token não encontrado');
      }

      // TODO: Validar token com backend

      return Right(user);
    } catch (e) {
      _logger.log(
        level: LogLevel.error,
        message: 'Check session error: $e',
        module: 'AuthRepository',
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
    } catch (e) {
      _logger.log(
        level: LogLevel.error,
        message: 'Logout error: $e',
        module: 'AuthRepository',
      );

      // Mesmo com erro, limpar sessão local
      await _localDataSource.clearSession();
    }
  }

  @override
  Future<Either<String, void>> revokeSession({
    required String deviceId,
  }) async {
    try {
      await _remoteDataSource.revokeSession(deviceId: deviceId);
      return const Right(null);
    } catch (e) {
      _logger.log(
        level: LogLevel.error,
        message: 'Revoke session error: $e',
        module: 'AuthRepository',
      );

      return const Left('Erro ao revogar sessão');
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(authLocalDataSourceProvider),
    GoogleSignIn(
      scopes: ['email', 'profile'],
    ),
    Logger.instance,
  );
});

class AuthRepositoryImpl implements AuthRepository {
  final http.Client _client;
  final TokenManager _tokenManager;

  AuthRepositoryImpl({
    required http.Client client,
    required TokenManager tokenManager,
  }) : _client = client,
       _tokenManager = tokenManager;

  @override
  Future<void> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('https://api.example.com/login'),
      body: json.encode({'email': email, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['token'];
      await _tokenManager.storeAccessToken(token);
    } else {
      throw Exception('Failed to login');
    }
  }

  @override
  Future<void> logout() async {
    await _tokenManager.deleteAccessToken();
  }
}