// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'music_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MusicEntityImpl _$$MusicEntityImplFromJson(Map<String, dynamic> json) =>
    _$MusicEntityImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String?,
      genre: json['genre'] as String?,
      year: (json['year'] as num?)?.toInt(),
      trackNumber: (json['trackNumber'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toInt(),
      lyrics: json['lyrics'] as String?,
      accessCount: (json['accessCount'] as num?)?.toInt(),
      lastAccessed: json['lastAccessed'] == null
          ? null
          : DateTime.parse(json['lastAccessed'] as String),
    );

Map<String, dynamic> _$$MusicEntityImplToJson(_$MusicEntityImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'artist': instance.artist,
      'album': instance.album,
      'genre': instance.genre,
      'year': instance.year,
      'trackNumber': instance.trackNumber,
      'duration': instance.duration,
      'lyrics': instance.lyrics,
      'accessCount': instance.accessCount,
      'lastAccessed': instance.lastAccessed?.toIso8601String(),
    };
