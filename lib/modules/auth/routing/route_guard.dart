import 'package:flutter/material.dart';

/// Interface para guards de rota
abstract class RouteGuard {
  /// Verifica se pode acessar a rota
  Future<bool> canActivate(BuildContext context);

  /// Rota de redirecionamento se não puder acessar
  String get redirectTo;
}

/// Guard para rotas autenticadas
class AuthGuard implements RouteGuard {
  @override
  Future<bool> canActivate(BuildContext context) async {
    // Implementar verificação de autenticação
    return true;
  }

  @override
  String get redirectTo => '/login';
}
