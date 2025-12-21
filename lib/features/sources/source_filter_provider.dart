import 'package:flutter_riverpod/flutter_riverpod.dart';

class SourceFilter {
  final String searchQuery;
  final Set<String> selectedTypes;
  final Set<String> selectedTags;
  final String sortBy; // 'date', 'title', 'type'
  final bool ascending;

  SourceFilter({
    this.searchQuery = '',
    this.selectedTypes = const {},
    this.selectedTags = const {},
    this.sortBy = 'date',
    this.ascending = false,
  });

  SourceFilter copyWith({
    String? searchQuery,
    Set<String>? selectedTypes,
    Set<String>? selectedTags,
    String? sortBy,
    bool? ascending,
  }) {
    return SourceFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      selectedTags: selectedTags ?? this.selectedTags,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }
}

class SourceFilterNotifier extends StateNotifier<SourceFilter> {
  SourceFilterNotifier() : super(SourceFilter());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleType(String type) {
    final types = Set<String>.from(state.selectedTypes);
    if (types.contains(type)) {
      types.remove(type);
    } else {
      types.add(type);
    }
    state = state.copyWith(selectedTypes: types);
  }

  void toggleTag(String tagId) {
    final tags = Set<String>.from(state.selectedTags);
    if (tags.contains(tagId)) {
      tags.remove(tagId);
    } else {
      tags.add(tagId);
    }
    state = state.copyWith(selectedTags: tags);
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void toggleSortOrder() {
    state = state.copyWith(ascending: !state.ascending);
  }

  void reset() {
    state = SourceFilter();
  }
}

final sourceFilterProvider =
    StateNotifierProvider<SourceFilterNotifier, SourceFilter>(
  (ref) => SourceFilterNotifier(),
);
