import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'serper_service.dart';

enum SearchStatus { idle, loading, success, error }

enum SearchType { web, images, news, videos }

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._ref) : super(SearchState());
  final Ref _ref;

  Future<void> search(
    String query, {
    SearchType type = SearchType.web,
    int num = 10,
  }) async {
    state = state.copyWith(
      status: SearchStatus.loading,
      error: null,
      searchType: type,
    );

    try {
      final service = SerperService(_ref);
      // Map SearchType to Serper API type string
      final typeString = type == SearchType.web ? 'search' : type.name;
      final results = await service.search(query, type: typeString, num: num);
      state = state.copyWith(
        status: SearchStatus.success,
        results: results,
        lastQuery: query,
        searchType: type,
      );
    } catch (e) {
      state = state.copyWith(
        status: SearchStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<String> fetchPageContent(String url) async {
    try {
      final service = SerperService(_ref);
      return await service.fetchPageContent(url);
    } catch (e) {
      throw Exception('Failed to fetch page content: $e');
    }
  }

  void clearResults() {
    state = SearchState();
  }

  // Verification not supported in basic SerperService
  Future<void> verifyYouTube(String url) async {
    // No-op
  }
}

class SearchState {
  final SearchStatus status;
  final List<SerperSearchResult> results;
  final String? error;
  final String? lastQuery;
  final dynamic verification;
  final SearchType searchType;

  SearchState({
    this.status = SearchStatus.idle,
    this.results = const [],
    this.error,
    this.lastQuery,
    this.verification,
    this.searchType = SearchType.web,
  });

  SearchState copyWith({
    SearchStatus? status,
    List<SerperSearchResult>? results,
    String? error,
    String? lastQuery,
    dynamic verification,
    SearchType? searchType,
  }) {
    return SearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      error: error ?? this.error,
      lastQuery: lastQuery ?? this.lastQuery,
      verification: verification ?? this.verification,
      searchType: searchType ?? this.searchType,
    );
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
