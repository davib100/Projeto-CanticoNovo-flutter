import 'package:json_annotation/json_annotation.dart';
import 'package:drift/drift.dart' as drift;

part '../../../shared/entities/music_entity.g.dart';

enum MusicGenre {
  gospel,
  hino,
  contemporaneo,
  tradicional,
  louvor,
  adoracao,
}

enum MusicTempo {
  lento,
  moderado,
  rapido,
}

@JsonSerializable()
class MusicEntity {
  final String id;
  final String title;
  final String? artist;
  final String lyrics;
  final String? chords;
  @JsonKey(name: 'category_id')
  final String? categoryId;
  final MusicGenre? genre;
  final String? key;
  final MusicTempo? tempo;
  final String? duration;
  @JsonKey(name: 'sheet_music_url')
  final String? sheetMusicUrl;
  @JsonKey(name: 'audio_url')
  final String? audioUrl;
  final List<String>? tags;
  @JsonKey(name: 'last_accessed')
  final DateTime? lastAccessed;
  @JsonKey(name: 'access_count')
  final int accessCount;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  MusicEntity({
    required this.id,
    required this.title,
    this.artist,
    required this.lyrics,
    this.chords,
    this.categoryId,
    this.genre,
    this.key,
    this.tempo,
    this.duration,
    this.sheetMusicUrl,
    this.audioUrl,
    this.tags,
    this.lastAccessed,
    this.accessCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory MusicEntity.fromJson(Map<String, dynamic> json) =>
      _$MusicEntityFromJson(json);

  Map<String, dynamic> toJson() => _$MusicEntityToJson(this);

  MusicEntity copyWith({
    String? id,
    String? title,
    String? artist,
    String? lyrics,
    String? chords,
    String? categoryId,
    MusicGenre? genre,
    String? key,
    MusicTempo? tempo,
    String? duration,
    String? sheetMusicUrl,
    String? audioUrl,
    List<String>? tags,
    DateTime? lastAccessed,
    int? accessCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MusicEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      lyrics: lyrics ?? this.lyrics,
      chords: chords ?? this.chords,
      categoryId: categoryId ?? this.categoryId,
      genre: genre ?? this.genre,
      key: key ?? this.key,
      tempo: tempo ?? this.tempo,
      duration: duration ?? this.duration,
      sheetMusicUrl: sheetMusicUrl ?? this.sheetMusicUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      tags: tags ?? this.tags,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      accessCount: accessCount ?? this.accessCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Verifica se a música contém o termo de busca
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return title.toLowerCase().contains(lowerQuery) ||
        (artist?.toLowerCase().contains(lowerQuery) ?? false) ||
        lyrics.toLowerCase().contains(lowerQuery) ||
        (tags?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ?? false);
  }

  /// Retorna fragmento da letra que contém a busca
  String? getLyricFragment(String query, {int contextLength = 50}) {
    if (!lyrics.toLowerCase().contains(query.toLowerCase())) {
      return null;
    }

    final index = lyrics.toLowerCase().indexOf(query.toLowerCase());
    final start = (index - contextLength).clamp(0, lyrics.length);
    final end = (index + query.length + contextLength).clamp(0, lyrics.length);

    String fragment = lyrics.substring(start, end);
    
    if (start > 0) fragment = '...$fragment';
    if (end < lyrics.length) fragment = '$fragment...';

    return fragment;
  }
}

/// Tabela Drift para armazenamento local
@drift.DataClassName('MusicRecord')
class MusicTable extends drift.Table {
  drift.TextColumn get id => text()();
  drift.TextColumn get title => text()();
  drift.TextColumn get artist => text().nullable()();
  drift.TextColumn get lyrics => text()();
  drift.TextColumn get chords => text().nullable()();
  drift.TextColumn get categoryId => text().nullable()();
  drift.TextColumn get genre => text().nullable()();
  drift.TextColumn get key => text().nullable()();
  drift.TextColumn get tempo => text().nullable()();
  drift.TextColumn get duration => text().nullable()();
  drift.TextColumn get sheetMusicUrl => text().nullable()();
  drift.TextColumn get audioUrl => text().nullable()();
  drift.TextColumn get tags => text().nullable()(); // JSON array
  drift.DateTimeColumn get lastAccessed => dateTime().nullable()();
  drift.IntColumn get accessCount => integer().withDefault(const drift.Constant(0))();
  drift.DateTimeColumn get createdAt => dateTime().nullable()();
  drift.DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<drift.Column> get primaryKey => {id};
}
