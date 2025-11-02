
class SessionModel {
  final String? id;
  final String accessToken;
  final String refreshToken;
  final String deviceId;
  final DateTime expiresAt;
  final DateTime createdAt;

  const SessionModel({
    this.id,
    required this.accessToken,
    required this.refreshToken,
    required this.deviceId,
    required this.expiresAt,
    required this.createdAt,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as String?,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      deviceId: json['deviceId'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'deviceId': deviceId,
      'expiresAt': expiresAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  SessionModel copyWith({
    String? id,
    String? accessToken,
    String? refreshToken,
    String? deviceId,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return SessionModel(
      id: id ?? this.id,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      deviceId: deviceId ?? this.deviceId,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
