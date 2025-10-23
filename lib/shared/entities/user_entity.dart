
class UserEntity {
  final String id;
  final String fullName;
  final String email;
  final String? photoUrl;
  final String deviceId;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const UserEntity({
    required this.id,
    required this.fullName,
    required this.email,
    this.photoUrl,
    required this.deviceId,
    required this.createdAt,
    this.lastLoginAt,
  });

  UserEntity copyWith({
    String? id,
    String? fullName,
    String? email,
    String? photoUrl,
    String? deviceId,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
