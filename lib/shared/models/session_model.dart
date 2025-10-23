
class SessionModel {
  final String token;
  final String refreshToken;
  final String deviceId;
  final DateTime expiresAt;
  final DateTime createdAt;

  const SessionModel({
    required this.token,
    required this.refreshToken,
    required this.deviceId,
    required this.expiresAt,
    required this.createdAt,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String,
      deviceId: json['deviceId'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'refreshToken': refreshToken,
      'deviceId': deviceId,
      'expiresAt': expiresAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
