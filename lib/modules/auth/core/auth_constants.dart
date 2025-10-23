
class AuthConstants {
  AuthConstants._();

  // Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String logoutEndpoint = '/auth/logout';
  static const String resetPasswordEndpoint = '/auth/reset-password';
  static const String refreshTokenEndpoint = '/auth/refresh';
  static const String googleAuthEndpoint = '/auth/google';
  static const String microsoftAuthEndpoint = '/auth/microsoft';
  static const String facebookAuthEndpoint = '/auth/facebook';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'auth_refresh_token';
  static const String userKey = 'auth_user';
  static const String deviceIdKey = 'device_id';

  // Session
  static const Duration tokenExpiration = Duration(hours: 1);
  static const Duration refreshTokenExpiration = Duration(days: 30);

  // Validation
  static const int minPasswordLength = 8;
  static const int minNameLength = 2;
  static const int maxNameLength = 100;

  // OAuth Scopes
  static const List<String> googleScopes = ['email', 'profile'];
  static const List<String> microsoftScopes = ['User.Read'];
  static const List<String> facebookScopes = ['email', 'public_profile'];
}
