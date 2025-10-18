
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:myapp/shared/models/music_model.dart';
import '../repositories/search_repository.dart';
import '../services/search_service.dart';
import '../models/search_state.dart';


final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(); 
});

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(ref.read(searchRepositoryProvider));
});

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(
    ref.read(searchRepositoryProvider),
    ref.read(searchServiceProvider),
  );
});

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchRepository _repository;
  final SearchService _service;
  final BehaviorSubject<String> _querySubject = BehaviorSubject.seeded('');

  SearchNotifier(this._repository, this._service) : super(const SearchState()) {
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
    try {
      final history = await _repository.getSearchHistory();
      state = state.copyWith(searchHistory: history);
    } catch (e) {
      // Handle error loading history
      print('Error loading search history: $e');
    }
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
    _querySubject.add(query);

    if (query.isNotEmpty) {
      _fetchSuggestions(query);
    } else {
      state = state.copyWith(suggestions: []);
    }
  }

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
      final result = await _service.searchMusic(query);

       state = state.copyWith(
        results: result,
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

  Future<void> _fetchSuggestions(String query) async {
    try {
      final suggestions = await _repository.getSearchSuggestions(query);
      state = state.copyWith(suggestions: suggestions);
    } catch (e) {
      // Silently handle suggestion errors
      print('Error fetching suggestions: $e');
    }
  }

  void selectSuggestion(String suggestion) {
    setQuery(suggestion);
  }

  Future<void> trackMusicAccess(Music music) async {
    // This seems to be related to quick access, might need a different service/repo
    // await _repository.trackMusicAccess(music);
  }

  Future<void> clearHistory() async {
    await _repository.clearSearchHistory();
    state = state.copyWith(searchHistory: []);
  }

  @override
  void dispose() {
    _querySubject.close();
    super.dispose();
  }
}
