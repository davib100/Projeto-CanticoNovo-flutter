import '../../../core/db/database_adapter.dart';
import '../../../shared/entities/user_entity.dart';
import '../../../shared/models/session_model.dart';
import '../../../shared/models/user_model.dart';
import 'auth_local_datasource.dart';

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final DatabaseAdapter _dbAdapter;

  AuthLocalDataSourceImpl(this._dbAdapter);

  static const String _usersTable = 'users';
  static const String _sessionsTable = 'sessions';
  static const String _currentUserKey = 'currentUser';
  static const String _currentSessionKey = 'currentSession';

  @override
  Future<void> saveUser(UserEntity user) async {
    final userModel = user is UserModel ? user : UserModel.fromEntity(user);
    await _dbAdapter.insert(
      table: _usersTable,
      data: (userModel as UserModel).copyWith(id: _currentUserKey).toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveSession(SessionModel session) async {
    await _dbAdapter.insert(
      table: _sessionsTable,
      data: (session).copyWith(id: _currentSessionKey).toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<UserEntity?> getUser() async {
    final result = await _dbAdapter.query(
      table: _usersTable,
      where: 'id = ?',
      whereArgs: [_currentUserKey],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return UserModel.fromJson(result.first).toEntity();
    }
    return null;
  }

  @override
  Future<SessionModel?> getSession() async {
    final result = await _dbAdapter.query(
      table: _sessionsTable,
      where: 'id = ?',
      whereArgs: [_currentSessionKey],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return SessionModel.fromJson(result.first);
    }
    return null;
  }

  @override
  Future<String?> getToken() async {
    final session = await getSession();
    return session?.accessToken;
  }

  @override
  Future<bool> hasValidSession() async {
    final session = await getSession();
    return session != null && !session.isExpired;
  }

  @override
  Future<void> clearSession() async {
    await _dbAdapter.delete(table: _usersTable, where: 'id = ?', whereArgs: [_currentUserKey]);
    await _dbAdapter.delete(table: _sessionsTable, where: 'id = ?', whereArgs: [_currentSessionKey]);
  }
}
