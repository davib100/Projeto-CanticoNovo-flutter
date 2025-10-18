import 'package:freezed_annotation/freezed_annotation.dart';

part 'music_entity.freezed.dart';
part 'music_entity.g.dart';

@freezed
class MusicEntity with _$MusicEntity {
  const factory MusicEntity({
    required String id,
    required String title,
    required String artist,
    String? album,
    String? genre,
    int? year,
    int? trackNumber,
    int? duration,
    String? lyrics,
    int? accessCount,
    DateTime? lastAccessed,
  }) = _MusicEntity;

  factory MusicEntity.fromJson(Map<String, dynamic> json) => _$MusicEntityFromJson(json);
}
