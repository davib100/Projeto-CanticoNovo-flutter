import '../../../shared/models/session_model.dart';
import '../../../shared/models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveUser(UserModel user);

  Future<void> saveSession(SessionModel session);

  Future<UserModel?> getUser();

  Future<SessionModel?> getSession();

  Future<String?> getToken();

  Future<bool> hasValidSession();

  Future<void> clearSession();
}
