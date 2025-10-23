
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required String id,
    required String fullName,
    required String email,
    String? photoUrl,
    required String deviceId,
    required DateTime createdAt,
    DateTime? lastLoginAt,
  }) : super(
          id: id,
          fullName: fullName,
          email: email,
          photoUrl: photoUrl,
          deviceId: deviceId,
          createdAt: createdAt,
          lastLoginAt: lastLoginAt,
        );

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
      deviceId: json['deviceId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'photoUrl': photoUrl,
      'deviceId': deviceId,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      fullName: entity.fullName,
      email: entity.email,
      photoUrl: entity.photoUrl,
      deviceId: entity.deviceId,
      createdAt: entity.createdAt,
      lastLoginAt: entity.lastLoginAt,
    );
  }
}
