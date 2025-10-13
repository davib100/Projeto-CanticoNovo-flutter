import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../models/search_state.dart';
import '../models/music_entity.dart';
import '../repositories/search_repository.dart';
import '../../quickaccess/providers/quickaccess_provider.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository.instance;
});

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.read(searchRepositoryProvider));
});

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchRepository _repository;
  final BehaviorSubject<String> _querySubject = BehaviorSubject.seeded('');

  SearchNotifier(this._repository) : super(const SearchState()) {
    _initializeDebounce();
    _loadSearchHistory();
  }

  void _initializeDebounce() {
    _querySubject
        .debounceTime(const Duration(milliseconds: 500))
        .distinct()
        .listen((query) {
      _performSearch(query);
    });
  }

  Future<void> _loadSearchHistory() async {
    await _repository.loadSearchHistory();
    _repository.searchHistory$.listen((history) {
      state = state.copyWith(searchHistory: history);
    });
  }

  /// Atualiza query (com debounce automático)
  void setQuery(String query) {
    state = state.copyWith(query: query);
    _querySubject.add(query);
    
    // Atualiza sugestões
    if (query.isNotEmpty) {
      _fetchSuggestions(query);
    } else {
      state = state.copyWith(suggestions: []);
    }
  }

  /// Executa busca
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(
        debouncedQuery: '',
        results: [],
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(
      debouncedQuery: query,
      isLoading: true,
      hasError: false,
      errorMessage: null,
    );

    try {
      final results = await _repository.searchMusic(query);
      
      state = state.copyWith(
        results: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Busca sugestões
  Future<void> _fetchSuggestions(String query) async {
    try {
      final suggestions = await _repository.fetchSuggestions(query);
      state = state.copyWith(suggestions: suggestions);
    } catch (e) {
      // Erro silencioso
      print('Erro ao buscar sugestões: $e');
    }
  }

  /// Seleciona sugestão
  void selectSuggestion(String suggestion) {
    setQuery(suggestion);
  }

  /// Registra acesso à música
  Future<void> trackMusicAccess(MusicEntity music) async {
    await _repository.trackMusicAccess(music);
  }

  /// Limpa histórico
  Future<void> clearHistory() async {
    await _repository.clearSearchHistory();
  }

  @override
  void dispose() {
    _querySubject.close();
    super.dispose();
  }
}
import '../services/search_service.dart';

// Adicione o provider do service
final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService.instance;
});

// Atualize o SearchNotifier para usar o service
class SearchNotifier extends StateNotifier<SearchState> {
  final SearchRepository _repository;
  final SearchService _service; // ← NOVO

  SearchNotifier(this._repository, this._service) : super(const SearchState()) {
    _initializeDebounce();
    _loadSearchHistory();
  }

  // ... resto do código ...

  /// Executa busca usando o service
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(
        debouncedQuery: '',
        results: [],
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(
      debouncedQuery: query,
      isLoading: true,
      hasError: false,
      errorMessage: null,
    );

    try {
      // Usa o service ao invés do repository diretamente
      final result = await _service.searchMusic(query);
      
      if (result.isSuccess) {
        state = state.copyWith(
          results: result.results,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          hasError: true,
          errorMessage: result.errorMessage,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }
}

// Atualize o provider principal
final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(
    ref.read(searchRepositoryProvider),
    ref.read(searchServiceProvider), // ← NOVO
  );
});
