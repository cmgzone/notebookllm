import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import '../../core/auth/custom_auth_service.dart';

/// Model for a saved research session
class ResearchSession {
  final String id;
  final String? notebookId;
  final String query;
  final String? report;
  final DateTime createdAt;
  final int sourceCount;

  ResearchSession({
    required this.id,
    this.notebookId,
    required this.query,
    this.report,
    required this.createdAt,
    this.sourceCount = 0,
  });

  factory ResearchSession.fromJson(Map<String, dynamic> json) {
    // Handle source_count which may come as string from PostgreSQL COUNT
    int sourceCount = 0;
    final rawCount = json['source_count'];
    if (rawCount is int) {
      sourceCount = rawCount;
    } else if (rawCount is String) {
      sourceCount = int.tryParse(rawCount) ?? 0;
    }

    return ResearchSession(
      id: json['id'] as String,
      notebookId: json['notebook_id'] as String?,
      query: json['query'] as String? ?? '',
      report: json['report'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      sourceCount: sourceCount,
    );
  }
}

/// Provider for managing research sessions
final researchSessionProvider = StateNotifierProvider<ResearchSessionNotifier,
    AsyncValue<List<ResearchSession>>>((ref) {
  return ResearchSessionNotifier(ref);
});

class ResearchSessionNotifier
    extends StateNotifier<AsyncValue<List<ResearchSession>>> {
  final Ref ref;

  ResearchSessionNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // Listen to auth state and load sessions when user is logged in
    ref.listen<AuthState>(customAuthStateProvider, (previous, next) {
      if (next.isAuthenticated) {
        loadSessions();
      } else {
        state = const AsyncValue.data([]);
      }
    }, fireImmediately: true);
  }

  Future<void> loadSessions() async {
    state = const AsyncValue.loading();
    try {
      final api = ref.read(apiServiceProvider);
      final sessionsData = await api.getResearchSessions();
      final sessions =
          sessionsData.map((s) => ResearchSession.fromJson(s)).toList();
      state = AsyncValue.data(sessions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.delete('/research/sessions/$id');

      // Remove from local state
      state.whenData((sessions) {
        state = AsyncValue.data(sessions.where((s) => s.id != id).toList());
      });
    } catch (e) {
      // Reload to ensure consistency
      await loadSessions();
      rethrow;
    }
  }
}
