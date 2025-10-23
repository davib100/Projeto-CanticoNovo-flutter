
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/database_adapter.dart';
import '../../../core/db/database_adapter_impl.dart';
import '../../../core/security/token_manager.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/session_model.dart';

class AuthLocalDataSource {
  final DatabaseAdapter _db;
  final TokenManager _tokenManager;

  AuthLocalDataSource(this._db, this._tokenManager);

  Future<void> saveUser(UserModel user) async {
    await _db.insert(
      table: 'users',
      data: user.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserModel?> getUser() async {
    final result = await _db.query(
      table: 'users',
      limit: 1,
    );

    if (result.isEmpty) return null;

    return UserModel.fromJson(result.first);
  }

  Future<void> saveSession(SessionModel session) async {
    // Salvar tokens com segurança
    await _tokenManager.storeAccessToken(session.token);
    await _tokenManager.storeRefreshToken(session.refreshToken);

    // Salvar metadados da sessão no DB
    await _db.insert(
      table: 'sessions',
      data: session.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SessionModel?> getSession() async {
    final result = await _db.query(
      table: 'sessions',
      orderBy: 'createdAt DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;

    return SessionModel.fromJson(result.first);
  }

  Future<String?> getToken() async {
    return await _tokenManager.getAccessToken();
  }

  Future<String?> getRefreshToken() async {
    return await _tokenManager.getRefreshToken();
  }

  Future<void> clearSession() async {
    await _tokenManager.deleteTokens();
    await _db.delete(table: 'sessions');
    await _db.delete(table: 'users');
  }

  Future<bool> hasValidSession() async {
    final session = await getSession();
    if (session == null) return false;
    return !session.isExpired;
  }
}

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSource(
    ref.watch(databaseAdapterProvider),
    ref.watch(tokenManagerProvider),
  );
});
