import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import 'models/gitu_exceptions.dart';

class GituMemory {
  final String id;
  final String category;
  final String content;
  final String source;
  final double confidence;
  final bool verified;
  final bool verificationRequired;
  final List<String> tags;

  const GituMemory({
    required this.id,
    required this.category,
    required this.content,
    required this.source,
    required this.confidence,
    required this.verified,
    required this.verificationRequired,
    required this.tags,
  });

  factory GituMemory.fromJson(Map<String, dynamic> json) {
    return GituMemory(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      content: json['content'] as String? ?? '',
      source: json['source'] as String? ?? '',
      confidence: (json['confidence'] is num)
          ? (json['confidence'] as num).toDouble()
          : double.tryParse(json['confidence']?.toString() ?? '0') ?? 0.0,
      verified: json['verified'] as bool? ?? false,
      verificationRequired: json['verificationRequired'] as bool? ??
          json['verification_required'] as bool? ??
          false,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class GituMemoryState {
  final List<GituMemory> memories;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String? categoryFilter;

  const GituMemoryState({
    this.memories = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.categoryFilter,
  });

  GituMemoryState copyWith({
    List<GituMemory>? memories,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? categoryFilter,
  }) {
    return GituMemoryState(
      memories: memories ?? this.memories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: categoryFilter ?? this.categoryFilter,
    );
  }
}

class GituMemoryNotifier extends StateNotifier<GituMemoryState> {
  final Ref _ref;

  GituMemoryNotifier(this._ref) : super(const GituMemoryState());

  Future<void> loadMemories({String? category}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = _ref.read(apiServiceProvider);
      final query = <String, dynamic>{};
      final filterCategory = category ?? state.categoryFilter;
      if (filterCategory != null && filterCategory.isNotEmpty) {
        query['category'] = filterCategory;
      }
      final response = await api.get<Map<String, dynamic>>(
        '/gitu/memories',
        queryParameters: query,
      );
      final items = response['memories'] as List<dynamic>? ?? const [];
      final memories = items
          .map((e) => GituMemory.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        memories: _applySearch(memories, state.searchQuery),
        isLoading: false,
        categoryFilter: filterCategory,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: GituException.from(e).message,
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query,
      memories: _applySearch(state.memories, query),
    );
  }

  void setCategoryFilter(String? category) {
    state = state.copyWith(categoryFilter: category);
    loadMemories(category: category);
  }

  Future<void> confirmMemory(String id) async {
    try {
      final api = _ref.read(apiServiceProvider);
      final response = await api
          .post<Map<String, dynamic>>('/gitu/memories/$id/confirm', {});
      final updated = GituMemory.fromJson(
          response['memory'] as Map<String, dynamic>? ?? const {});
      final list = state.memories.map((m) => m.id == id ? updated : m).toList();
      state = state.copyWith(
        memories: _applySearch(list, state.searchQuery),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> requestVerification(String id) async {
    try {
      final api = _ref.read(apiServiceProvider);
      final response = await api.post<Map<String, dynamic>>(
          '/gitu/memories/$id/request-verification', {});
      final updated = GituMemory.fromJson(
          response['memory'] as Map<String, dynamic>? ?? const {});
      final list = state.memories.map((m) => m.id == id ? updated : m).toList();
      state = state.copyWith(
        memories: _applySearch(list, state.searchQuery),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> correctMemory(
    String id, {
    String? content,
    String? category,
  }) async {
    try {
      final api = _ref.read(apiServiceProvider);
      final payload = <String, dynamic>{};
      if (content != null) payload['content'] = content;
      if (category != null && category.isNotEmpty) {
        payload['category'] = category;
      }
      final response = await api.post<Map<String, dynamic>>(
          '/gitu/memories/$id/correct', payload);
      final updated = GituMemory.fromJson(
          response['memory'] as Map<String, dynamic>? ?? const {});
      final list = state.memories.map((m) => m.id == id ? updated : m).toList();
      state = state.copyWith(
        memories: _applySearch(list, state.searchQuery),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteMemory(String id) async {
    try {
      final api = _ref.read(apiServiceProvider);
      await api.delete<Map<String, dynamic>>('/gitu/memories/$id');
      final list = state.memories.where((m) => m.id != id).toList();
      state = state.copyWith(
        memories: _applySearch(list, state.searchQuery),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  List<GituMemory> _applySearch(List<GituMemory> items, String query) {
    if (query.isEmpty) return items;
    final lower = query.toLowerCase();
    return items
        .where((m) =>
            m.content.toLowerCase().contains(lower) ||
            m.source.toLowerCase().contains(lower) ||
            m.category.toLowerCase().contains(lower))
        .toList();
  }
}

final gituMemoryProvider =
    StateNotifierProvider<GituMemoryNotifier, GituMemoryState>((ref) {
  return GituMemoryNotifier(ref);
});
