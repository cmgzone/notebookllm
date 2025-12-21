import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../core/auth/auth_service.dart';
import '../../core/api/api_service.dart';
import 'tag.dart';

class TagNotifier extends StateNotifier<List<Tag>> {
  TagNotifier(this.ref) : super([]) {
    _init();
  }

  final Ref ref;

  Future<void> _init() async {
    await loadTags();
  }

  Future<void> loadTags() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.getTags();

      state = result
          .map((row) => Tag(
                id: row['id'] as String,
                name: row['name'] as String,
                color: row['color'] as String? ?? '#3B82F6',
                createdAt: DateTime.parse(row['created_at'] as String),
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }
  }

  Future<String?> createTag(String name, String color) async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return null;

      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.createTag(name: name, color: color);

      await loadTags();
      return result['id'] as String;
    } catch (e) {
      debugPrint('Error creating tag: $e');
      return null;
    }
  }

  Future<void> deleteTag(String tagId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.deleteTag(tagId);
      await loadTags();
    } catch (e) {
      debugPrint('Error deleting tag: $e');
    }
  }
}

final tagProvider = StateNotifierProvider<TagNotifier, List<Tag>>(
  (ref) {
    ref.watch(currentUserProvider);
    return TagNotifier(ref);
  },
);
