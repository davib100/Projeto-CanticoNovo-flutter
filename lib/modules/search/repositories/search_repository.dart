import 'package:rxdart/rxdart.dart';
import '../../../core/db/database_adapter.dart';
import '../models/music_entity.dart';
import '../services/search_api.dart';

class SearchRepository {
  static final SearchRepository instance = SearchRepository._internal();
  SearchRepository._internal();

  final SearchApi _api = SearchApi();
  final DatabaseAdapter _db = DatabaseAdapter.instance;
  
  final BehaviorSubject<List<String>> _searchHistoryController = 
      BehaviorSubject.seeded([]);

  Stream<List<String>> get searchHistory$ => _searchHistoryController.stream;
  List<String> get searchHistory => _searchHistoryController.value;

  /// Busca músicas (prioriza cache local, depois API)
  Future<List<MusicEntity>> searchMusic(String query) async {
    if (query.isEmpty) return [];

    try {
      // 1. Tenta buscar no cache local primeiro
      final localResults = await _searchLocalCache(query);
      
      // 2. Se encontrou resultados locais, retorna imediatamente
      if (localResults.isNotEmpty) {
        return localResults;
      }

      // 3. Busca na API
      final apiResults = await _api.searchMusic(query: query);
      
      // 4. Salva resultados no cache local
      await _cacheSearchResults(apiResults);
      
      // 5. Adiciona ao histórico
      await addToSearchHistory(query);
      
      return apiResults;
    } catch (e) {
      // Em caso de erro de rede, tenta retornar cache local
      print('Erro na busca remota: $e');
      return await _searchLocalCache(query);
    }
  }

  /// Busca no cache local (SQLite)
  Future<List<MusicEntity>> _searchLocalCache(String query) async {
    final results = await _db.query(
      'music_table',
      where: 'title LIKE ? OR lyrics LIKE ? OR artist LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'access_count DESC, last_accessed DESC',
      limit: 50,
    );

    return results.map((row) => MusicEntity.fromJson(row)).toList();
  }

  /// Salva resultados no cache
  Future<void> _cacheSearchResults(List<MusicEntity> results) async {
    for (final music in results) {
      await _db.insertOrUpdate(
        'music_table',
        music.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Adiciona termo ao histórico de buscas
  Future<void> addToSearchHistory(String query) async {
    final history = List<String>.from(_searchHistoryController.value);
    
    // Remove duplicatas
    history.remove(query);
    
    // Adiciona no início
    history.insert(0, query);
    
    // Limita a 20 itens
    if (history.length > 20) {
      history.removeRange(20, history.length);
    }
    
    // Salva no banco local
    await _db.insert(
      'search_history',
      {
        'query': query,
        'searched_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    _searchHistoryController.add(history);
  }

  /// Carrega histórico de buscas
  Future<void> loadSearchHistory() async {
    final results = await _db.query(
      'search_history',
      orderBy: 'searched_at DESC',
      limit: 20,
    );
    
    final history = results.map((row) => row['query'] as String).toList();
    _searchHistoryController.add(history);
  }

  /// Limpa histórico de buscas
  Future<void> clearSearchHistory() async {
    await _db.delete('search_history');
    _searchHistoryController.add([]);
  }

  /// Registra acesso à música
  Future<void> trackMusicAccess(MusicEntity music) async {
    final updatedMusic = music.copyWith(
      lastAccessed: DateTime.now(),
      accessCount: music.accessCount + 1,
    );

    // Atualiza local
    await _db.update(
      'music_table',
      updatedMusic.toJson(),
      where: 'id = ?',
      whereArgs: [music.id],
    );

    // Atualiza remoto (sem bloquear UI)
    _api.updateMusicAccess(
      musicId: music.id,
      lastAccessed: updatedMusic.lastAccessed!,
      accessCount: updatedMusic.accessCount,
    ).catchError((e) => print('Erro ao sincronizar acesso: $e'));
  }

  /// Busca sugestões
  Future<List<String>> fetchSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    try {
      return await _api.fetchSuggestions(query);
    } catch (e) {
      // Fallback: retorna do histórico local
      return searchHistory
          .where((h) => h.toLowerCase().contains(query.toLowerCase()))
          .take(5)
          .toList();
    }
  }

  void dispose() {
    _searchHistoryController.close();
  }
}
