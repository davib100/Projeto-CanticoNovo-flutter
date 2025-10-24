
import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
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

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        photoUrl,
        deviceId,
        createdAt,
        lastLoginAt,
      ];
}
