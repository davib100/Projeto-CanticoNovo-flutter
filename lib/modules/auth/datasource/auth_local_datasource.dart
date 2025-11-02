import '../../../shared/entities/user_entity.dart';
import '../../../shared/models/session_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveUser(UserEntity user);

  Future<void> saveSession(SessionModel session);

  Future<UserEntity?> getUser();

  Future<SessionModel?> getSession();

  Future<String?> getToken();

  Future<bool> hasValidSession();

  Future<void> clearSession();
}
