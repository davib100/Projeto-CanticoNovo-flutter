import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<String, UserEntity>> login({
    required String email,
    required String password,
    bool rememberMe = false,
  });

  Future<Either<String, UserEntity>> loginWithGoogle();

  Future<Either<String, UserEntity>> loginWithMicrosoft();

  Future<Either<String, UserEntity>> loginWithFacebook();

  Future<Either<String, UserEntity>> register({
    required String fullName,
    required String email,
    required String password,
  });

  Future<Either<String, void>> resetPassword({
    required String email,
  });

  Future<Either<String, UserEntity>> checkSession();

  Future<void> logout();

  Future<Either<String, void>> revokeSession({
    required String deviceId,
  });
}
