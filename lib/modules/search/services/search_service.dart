import 'package:rxdart/rxdart.dart';
import '../models/music_entity.dart';
import '../repositories/search_repository.dart';
import '../../../core/observability/logger.dart';
import '../../../core/services/connectivity_service.dart';

/// Service de busca com lógica de negócio centralizada
/// 
/// Responsabilidades:
/// - Validação de queries
/// - Orquestração de cache + API
/// - Processamento de resultados
/// - Métricas e analytics
class SearchService {
  static final SearchService instance = SearchService._internal();
  SearchService._internal();

  final SearchRepository _repository = SearchRepository.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final AppLogger _logger = AppLogger.instance;

  // Stream de métricas de busca
  final BehaviorSubject<SearchMetrics> _metricsController = 
      BehaviorSubject.seeded(SearchMetrics.empty());

  Stream<SearchMetrics> get metrics$ => _metricsController.stream;
  SearchMetrics get metrics => _metricsController.value;

  /// Busca músicas com validação e métricas
  Future<SearchResult> searchMusic(String query) async {
    final startTime = DateTime.now();
    
    try {
      // 1. Validação
      final validationError = _validateQuery(query);
      if (validationError != null) {
        _logger.warning('Search validation failed', {
          'query': query,
          'error': validationError,
        });
        
        return SearchResult.error(validationError);
      }

      // 2. Normaliza query
      final normalizedQuery = _normalizeQuery(query);

      // 3. Busca no repository (cache + API)
      final results = await _repository.searchMusic(normalizedQuery);

      // 4. Processa resultados
      final processedResults = _processResults(results, normalizedQuery);

      // 5. Atualiza métricas
      _updateMetrics(
        query: normalizedQuery,
        resultsCount: processedResults.length,
        duration: DateTime.now().difference(startTime),
        hasError: false,
      );

      // 6. Log de sucesso
      _logger.info('Search completed', {
        'query': normalizedQuery,
        'resultsCount': processedResults.length,
        'durationMs': DateTime.now().difference(startTime).inMilliseconds,
      });

      return SearchResult.success(
        results: processedResults,
        query: normalizedQuery,
        duration: DateTime.now().difference(startTime),
      );

    } catch (e, stackTrace) {
      // Log de erro
      _logger.error('Search failed', {
        'query': query,
        'error': e.toString(),
      }, stackTrace);

      // Atualiza métricas
      _updateMetrics(
        query: query,
        resultsCount: 0,
        duration: DateTime.now().difference(startTime),
        hasError: true,
      );

      return SearchResult.error(
        'Erro ao buscar músicas: ${e.toString()}',
      );
    }
  }

  /// Busca sugestões com cache local
  Future<List<String>> getSuggestions(String query) async {
    try {
      if (query.isEmpty || query.length < 2) {
        return [];
      }

      final normalizedQuery = _normalizeQuery(query);

      // Busca sugestões (repository já faz fallback para histórico local)
      final suggestions = await _repository.fetchSuggestions(normalizedQuery);

      // Remove duplicatas e limita
      return suggestions.toSet().take(5).toList();

    } catch (e) {
      _logger.warning('Failed to get suggestions', {
        'query': query,
        'error': e.toString(),
      });
      return [];
    }
  }

  /// Busca músicas relacionadas (similar)
  Future<List<MusicEntity>> getRelatedMusic(MusicEntity music) async {
    try {
      // Busca por artista ou gênero similar
      final query = music.artist ?? music.genre?.name ?? music.title;
      
      final results = await _repository.searchMusic(query);

      // Remove a música atual e limita a 5
      return results
          .where((m) => m.id != music.id)
          .take(5)
          .toList();

    } catch (e) {
      _logger.error('Failed to get related music', {
        'musicId': music.id,
        'error': e.toString(),
      });
      return [];
    }
  }

  /// Busca histórico do usuário
  Future<List<String>> getSearchHistory() async {
    try {
      return _repository.searchHistory;
    } catch (e) {
      _logger.error('Failed to get search history', {
        'error': e.toString(),
      });
      return [];
    }
  }

  /// Limpa histórico de buscas
  Future<void> clearSearchHistory() async {
    try {
      await _repository.clearSearchHistory();
      
      _logger.info('Search history cleared');
    } catch (e) {
      _logger.error('Failed to clear search history', {
        'error': e.toString(),
      });
      rethrow;
    }
  }

  /// Registra acesso à música
  Future<void> trackMusicAccess(MusicEntity music) async {
    try {
      await _repository.trackMusicAccess(music);
      
      _logger.info('Music access tracked', {
        'musicId': music.id,
        'title': music.title,
      });
    } catch (e) {
      _logger.warning('Failed to track music access', {
        'musicId': music.id,
        'error': e.toString(),
      });
      // Não lança erro - é operação secundária
    }
  }

  /// Busca com filtros avançados
  Future<SearchResult> searchWithFilters({
    required String query,
    MusicGenre? genre,
    MusicTempo? tempo,
    List<String>? tags,
    bool sortByPopularity = false,
  }) async {
    try {
      final results = await searchMusic(query);

      if (!results.isSuccess) {
        return results;
      }

      var filtered = results.results;

      // Aplica filtros
      if (genre != null) {
        filtered = filtered.where((m) => m.genre == genre).toList();
      }

      if (tempo != null) {
        filtered = filtered.where((m) => m.tempo == tempo).toList();
      }

      if (tags != null && tags.isNotEmpty) {
        filtered = filtered.where((m) {
          return m.tags?.any((tag) => tags.contains(tag)) ?? false;
        }).toList();
      }

      // Ordenação
      if (sortByPopularity) {
        filtered.sort((a, b) => b.accessCount.compareTo(a.accessCount));
      }

      return SearchResult.success(
        results: filtered,
        query: query,
        duration: results.duration,
      );

    } catch (e, stackTrace) {
      _logger.error('Search with filters failed', {
        'query': query,
        'error': e.toString(),
      }, stackTrace);
      
      return SearchResult.error('Erro ao buscar com filtros');
    }
  }

  /// Valida query de busca
  String? _validateQuery(String query) {
    if (query.trim().isEmpty) {
      return 'Query não pode estar vazia';
    }

    if (query.length < 2) {
      return 'Query deve ter pelo menos 2 caracteres';
    }

    if (query.length > 100) {
      return 'Query muito longa (máximo 100 caracteres)';
    }

    return null;
  }

  /// Normaliza query (remove acentos, lowercase, trim)
  String _normalizeQuery(String query) {
    return query
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' '); // Remove espaços extras
  }

  /// Processa resultados (ranking, deduplicação)
  List<MusicEntity> _processResults(List<MusicEntity> results, String query) {
    if (results.isEmpty) return [];

    // Remove duplicatas (por ID)
    final uniqueResults = <String, MusicEntity>{};
    for (final music in results) {
      uniqueResults[music.id] = music;
    }

    final processed = uniqueResults.values.toList();

    // Ordenação por relevância
    processed.sort((a, b) {
      // 1. Prioriza match exato no título
      final aExactTitle = a.title.toLowerCase() == query.toLowerCase();
      final bExactTitle = b.title.toLowerCase() == query.toLowerCase();
      
      if (aExactTitle && !bExactTitle) return -1;
      if (!aExactTitle && bExactTitle) return 1;

      // 2. Prioriza título que começa com a query
      final aStartsWithQuery = a.title.toLowerCase().startsWith(query);
      final bStartsWithQuery = b.title.toLowerCase().startsWith(query);
      
      if (aStartsWithQuery && !bStartsWithQuery) return -1;
      if (!aStartsWithQuery && bStartsWithQuery) return 1;

      // 3. Ordena por popularidade (accessCount)
      return b.accessCount.compareTo(a.accessCount);
    });

    return processed;
  }

  /// Atualiza métricas de busca
  void _updateMetrics({
    required String query,
    required int resultsCount,
    required Duration duration,
    required bool hasError,
  }) {
    final currentMetrics = _metricsController.value;

    _metricsController.add(
      currentMetrics.copyWith(
        totalSearches: currentMetrics.totalSearches + 1,
        successfulSearches: hasError 
            ? currentMetrics.successfulSearches 
            : currentMetrics.successfulSearches + 1,
        failedSearches: hasError 
            ? currentMetrics.failedSearches + 1 
            : currentMetrics.failedSearches,
        totalResultsFound: currentMetrics.totalResultsFound + resultsCount,
        averageDuration: Duration(
          milliseconds: ((currentMetrics.averageDuration.inMilliseconds * 
              currentMetrics.totalSearches) + duration.inMilliseconds) ~/ 
              (currentMetrics.totalSearches + 1),
        ),
        lastSearchQuery: query,
        lastSearchTime: DateTime.now(),
      ),
    );
  }

  /// Reseta métricas
  void resetMetrics() {
    _metricsController.add(SearchMetrics.empty());
    _logger.info('Search metrics reset');
  }

  /// Verifica conectividade antes de buscar
  Future<bool> hasConnectivity() async {
    return await _connectivity.hasConnection();
  }

  void dispose() {
    _metricsController.close();
  }
}

// ========== MODELS DE SUPORTE ==========

/// Resultado de busca encapsulado
class SearchResult {
  final bool isSuccess;
  final List<MusicEntity> results;
  final String query;
  final String? errorMessage;
  final Duration duration;

  SearchResult.success({
    required this.results,
    required this.query,
    required this.duration,
  })  : isSuccess = true,
        errorMessage = null;

  SearchResult.error(this.errorMessage)
      : isSuccess = false,
        results = const [],
        query = '',
        duration = Duration.zero;

  bool get hasResults => results.isNotEmpty;
  int get count => results.length;
}

/// Métricas de busca
class SearchMetrics {
  final int totalSearches;
  final int successfulSearches;
  final int failedSearches;
  final int totalResultsFound;
  final Duration averageDuration;
  final String lastSearchQuery;
  final DateTime? lastSearchTime;

  const SearchMetrics({
    required this.totalSearches,
    required this.successfulSearches,
    required this.failedSearches,
    required this.totalResultsFound,
    required this.averageDuration,
    required this.lastSearchQuery,
    this.lastSearchTime,
  });

  factory SearchMetrics.empty() {
    return const SearchMetrics(
      totalSearches: 0,
      successfulSearches: 0,
      failedSearches: 0,
      totalResultsFound: 0,
      averageDuration: Duration.zero,
      lastSearchQuery: '',
      lastSearchTime: null,
    );
  }

  double get successRate {
    if (totalSearches == 0) return 0.0;
    return (successfulSearches / totalSearches) * 100;
  }

  double get averageResultsPerSearch {
    if (successfulSearches == 0) return 0.0;
    return totalResultsFound / successfulSearches;
  }

  SearchMetrics copyWith({
    int? totalSearches,
    int? successfulSearches,
    int? failedSearches,
    int? totalResultsFound,
    Duration? averageDuration,
    String? lastSearchQuery,
    DateTime? lastSearchTime,
  }) {
    return SearchMetrics(
      totalSearches: totalSearches ?? this.totalSearches,
      successfulSearches: successfulSearches ?? this.successfulSearches,
      failedSearches: failedSearches ?? this.failedSearches,
      totalResultsFound: totalResultsFound ?? this.totalResultsFound,
      averageDuration: averageDuration ?? this.averageDuration,
      lastSearchQuery: lastSearchQuery ?? this.lastSearchQuery,
      lastSearchTime: lastSearchTime ?? this.lastSearchTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSearches': totalSearches,
      'successfulSearches': successfulSearches,
      'failedSearches': failedSearches,
      'totalResultsFound': totalResultsFound,
      'averageDurationMs': averageDuration.inMilliseconds,
      'lastSearchQuery': lastSearchQuery,
      'lastSearchTime': lastSearchTime?.toIso8601String(),
      'successRate': successRate,
      'averageResultsPerSearch': averageResultsPerSearch,
    };
  }
}
