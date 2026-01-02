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
  bool _isLoading = false;

  Future<void> _init() async {
    // Listen to auth state changes and reload notebooks
    ref.listen(customAuthStateProvider, (previous, next) {
      if (next.isAuthenticated && !_isLoading) {
        debugPrint('🔄 Auth state changed, reloading notebooks...');
        loadNotebooks();
      }
    });

    // Initial load
    await loadNotebooks();
  }

  Future<void> loadNotebooks() async {
    if (_isLoading) {
      debugPrint('⏳ Already loading notebooks, skipping...');
      return;
    }

    _isLoading = true;

    try {
      final authState = ref.read(customAuthStateProvider);
      final user = authState.user;
      debugPrint('🔍 Auth state: isAuthenticated=${authState.isAuthenticated}, user=${user?.uid}');
      
      if (user == null) {
        debugPrint('⚠️ NotebookNotifier loadNotebooks: No user logged in');
        state = [];
        _isLoading = false;
        return;
      }

      final apiService = ref.read(apiServiceProvider);
      debugPrint('📚 Loading notebooks for user=${user.uid}');

      final notebooks = await apiService.getNotebooks();
      debugPrint('📚 API returned ${notebooks.length} notebooks');
      
      if (notebooks.isEmpty) {
        debugPrint('⚠️ No notebooks returned from API - check if user has notebooks in database');
        state = [];
        _isLoading = false;
        return;
      }
      
      // Log first notebook for debugging
      if (notebooks.isNotEmpty) {
        debugPrint('📖 First notebook data: ${notebooks.first}');
      }

      final loadedNotebooks = notebooks.map((notebook) {
        debugPrint('📖 Parsing: ${notebook['id']} - ${notebook['title']}');
        return Notebook(
          id: notebook['id'] as String,
          userId: notebook['user_id'] as String,
          title: notebook['title'] as String,
          description: notebook['description'] as String? ?? '',
          coverImage: notebook['cover_image'] as String?,
          sourceCount: (notebook['source_count'] as num?)?.toInt() ?? 0,
          createdAt: DateTime.parse(notebook['created_at'] as String),
          updatedAt: DateTime.parse(notebook['updated_at'] as String),
          // Agent notebook fields (Requirements 1.4, 4.1)
          isAgentNotebook: notebook['is_agent_notebook'] as bool? ?? false,
          agentSessionId: notebook['agent_session_id'] as String?,
          agentName: notebook['agent_name'] as String?,
          agentIdentifier: notebook['agent_identifier'] as String?,
          agentStatus: notebook['agent_status'] as String? ?? 'active',
        );
      }).toList();

      state = loadedNotebooks;
      debugPrint('✅ Loaded ${state.length} notebooks into state');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading notebooks: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't reset state on error - keep existing notebooks
    } finally {
      _isLoading = false;
    }
  }

  /// Force refresh notebooks from the backend
  Future<void> refresh() async {
    debugPrint('🔄 Force refreshing notebooks...');
    await loadNotebooks();
  }

  Future<String?> addNotebook(String title) async {
    try {
      final authState = ref.read(customAuthStateProvider);
      final user = authState.user;
      if (user == null) {
        debugPrint('❌ NotebookNotifier addNotebook: No user logged in');
        return null;
      }

      final apiService = ref.read(apiServiceProvider);

      debugPrint(
          '📝 NotebookNotifier addNotebook: title=$title, user=${user.uid}');

      final notebookData = await apiService.createNotebook(
        title: title,
        description: '',
      );

      debugPrint('📝 API response: $notebookData');

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

      // Update state immediately with the new notebook
      final currentState = [...state];
      state = [notebook, ...currentState];
      debugPrint('✅ Notebook added to state, count=${state.length}');

      // Track gamification (don't await to avoid blocking)
      ref.read(gamificationProvider.notifier).trackNotebookCreated();

      return notebook.id;
    } catch (e, stackTrace) {
      debugPrint('❌ Error adding notebook: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow; // Rethrow so the dialog can show the error
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
