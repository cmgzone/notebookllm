import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'notebook.dart';
import '../gamification/gamification_provider.dart';
import '../../core/auth/custom_auth_service.dart';
import '../../core/api/api_service.dart';

class NotebookNotifier extends StateNotifier<List<Notebook>> {
  NotebookNotifier(this.ref) : super([]) {
    _init();
  }

  final Ref ref;

  Future<void> _init() async {
    await loadNotebooks();
  }

  Future<void> loadNotebooks() async {
    try {
      final authState = ref.read(customAuthStateProvider);
      final user = authState.user;
      if (user == null) {
        debugPrint('⚠️ NotebookNotifier: No user logged in');
        state = [];
        return;
      }

      final apiService = ref.read(apiServiceProvider);
      debugPrint('Notebook loadNotebooks: user=${user.uid}');

      final notebooks = await apiService.getNotebooks();

      state = notebooks.map((notebook) {
        return Notebook(
          id: notebook['id'] as String,
          userId: notebook['user_id'] as String,
          title: notebook['title'] as String,
          description: notebook['description'] as String? ?? '',
          coverImage: notebook['cover_image'] as String?,
          sourceCount: 0, // Will be calculated from sources if needed
          createdAt: DateTime.parse(notebook['created_at'] as String),
          updatedAt: DateTime.parse(notebook['updated_at'] as String),
        );
      }).toList();

      debugPrint('Loaded ${state.length} notebooks');
    } catch (e) {
      debugPrint('Error loading notebooks: $e');
      state = [];
    }
  }

  Future<void> addNotebook(String title) async {
    try {
      final authState = ref.read(customAuthStateProvider);
      final user = authState.user;
      if (user == null) return;

      final apiService = ref.read(apiServiceProvider);

      debugPrint(
          'NotebookNotifier addNotebook: title=$title, user=${user.uid}');

      final notebookData = await apiService.createNotebook(
        title: title,
        description: '',
      );

      final notebook = Notebook(
        id: notebookData['id'] as String,
        userId: notebookData['user_id'] as String,
        title: notebookData['title'] as String,
        description: notebookData['description'] as String? ?? '',
        coverImage: notebookData['cover_image'] as String?,
        sourceCount: 0,
        createdAt: DateTime.parse(notebookData['created_at'] as String),
        updatedAt: DateTime.parse(notebookData['updated_at'] as String),
      );

      state = [notebook, ...state];
      debugPrint('Notebook added, state updated, count=${state.length}');

      // Track gamification
      ref.read(gamificationProvider.notifier).trackNotebookCreated();

      // Refresh from API
      await Future.delayed(const Duration(milliseconds: 100));
      await loadNotebooks();
    } catch (e) {
      debugPrint('Error adding notebook: $e');
    }
  }

  Future<void> deleteNotebook(String notebookId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.deleteNotebook(notebookId);
      state = state.where((n) => n.id != notebookId).toList();
    } catch (e) {
      debugPrint('Error deleting notebook: $e');
    }
  }

  Future<void> updateNotebook(String notebookId, String newTitle) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final now = DateTime.now();

      await apiService.updateNotebook(
        notebookId,
        title: newTitle,
      );

      state = state.map((n) {
        if (n.id == notebookId) {
          return n.copyWith(
            title: newTitle,
            updatedAt: now,
          );
        }
        return n;
      }).toList();
    } catch (e) {
      debugPrint('Error updating notebook: $e');
    }
  }

  Future<void> updateNotebookCover(
      String notebookId, String? coverImage) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final now = DateTime.now();

      await apiService.updateNotebook(
        notebookId,
        coverImage: coverImage,
      );

      state = state.map((n) {
        if (n.id == notebookId) {
          return n.copyWith(
            coverImage: coverImage,
            updatedAt: now,
          );
        }
        return n;
      }).toList();

      debugPrint('Notebook cover updated: $notebookId');
    } catch (e) {
      debugPrint('Error updating notebook cover: $e');
      rethrow;
    }
  }
}

final notebookProvider =
    StateNotifierProvider<NotebookNotifier, List<Notebook>>(
  (ref) {
    // Watch auth state to trigger rebuild on login/logout
    ref.watch(customAuthStateProvider);
    return NotebookNotifier(ref);
  },
);
