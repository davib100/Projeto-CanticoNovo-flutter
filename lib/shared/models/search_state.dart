import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../shared/models/music_entity.dart';

part '../../../shared/models/search_state.freezed.dart';

@freezed
class SearchState with _$SearchState {
  const factory SearchState({
    @Default('') String query,
    @Default('') String debouncedQuery,
    @Default([]) List<MusicEntity> results,
    @Default([]) List<String> suggestions,
    @Default([]) List<String> searchHistory,
    @Default(false) bool isLoading,
    @Default(false) bool hasError,
    String? errorMessage,
  }) = _SearchState;

  const SearchState._();

  bool get hasResults => results.isNotEmpty;
  bool get hasQuery => debouncedQuery.isNotEmpty;
  bool get showEmptyState => hasQuery && !isLoading && !hasResults && !hasError;
  bool get showResults => hasQuery && hasResults && !isLoading;
}
