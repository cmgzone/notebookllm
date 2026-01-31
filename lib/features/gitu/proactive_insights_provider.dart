import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import 'models/proactive_insights_model.dart';

/// State for proactive insights
class ProactiveInsightsState {
  final ProactiveInsights? insights;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetched;

  const ProactiveInsightsState({
    this.insights,
    this.isLoading = false,
    this.error,
    this.lastFetched,
  });

  ProactiveInsightsState copyWith({
    ProactiveInsights? insights,
    bool? isLoading,
    String? error,
    DateTime? lastFetched,
  }) {
    return ProactiveInsightsState(
      insights: insights ?? this.insights,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }

  bool get hasData => insights != null;

  /// Check if cache is stale (older than 1 minute)
  bool get isStale {
    if (lastFetched == null) return true;
    return DateTime.now().difference(lastFetched!).inSeconds > 60;
  }
}

/// Notifier for managing proactive insights state
class ProactiveInsightsNotifier extends StateNotifier<ProactiveInsightsState> {
  final ApiService _api;
  Timer? _refreshTimer;
  bool _isDisposed = false;

  ProactiveInsightsNotifier(this._api) : super(const ProactiveInsightsState()) {
    // Initial fetch
    fetchInsights();
    // Background refresh every 60 seconds
    _startBackgroundRefresh();
  }

  void _startBackgroundRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!_isDisposed) {
        fetchInsights(silent: true);
      }
    });
  }

  /// Fetch proactive insights from the backend
  Future<void> fetchInsights(
      {bool refresh = false, bool silent = false}) async {
    if (_isDisposed) return;

    // Don't show loading state for silent refreshes
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/gitu/proactive-insights${refresh ? '?refresh=true' : ''}',
      );

      if (_isDisposed) return;

      if (response['success'] == true && response['insights'] != null) {
        final insights = ProactiveInsights.fromJson(response['insights']);
        state = state.copyWith(
          insights: insights,
          isLoading: false,
          lastFetched: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response['error'] ?? 'Failed to load insights',
        );
      }
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isLoading: false,
        error: silent ? null : e.toString(),
      );
    }
  }

  /// Force refresh insights
  Future<void> refresh() async {
    await fetchInsights(refresh: true);
  }

  /// Record user activity for pattern analysis
  Future<void> recordActivity(String activityType,
      {Map<String, dynamic>? metadata}) async {
    try {
      await _api.post('/gitu/proactive-insights/activity', {
        'activityType': activityType,
        'metadata': metadata,
      });
    } catch (e) {
      // Silently fail - activity recording is non-critical
    }
  }

  /// Dismiss a suggestion (mark as expired locally)
  void dismissSuggestion(String suggestionId) {
    if (state.insights == null) return;

    final updatedSuggestions =
        state.insights!.suggestions.where((s) => s.id != suggestionId).toList();

    state = state.copyWith(
      insights: state.insights!.copyWith(suggestions: updatedSuggestions),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// Main provider for proactive insights
final proactiveInsightsProvider =
    StateNotifierProvider<ProactiveInsightsNotifier, ProactiveInsightsState>(
  (ref) => ProactiveInsightsNotifier(ref.watch(apiServiceProvider)),
);

/// Convenience providers for specific data

/// Gmail summary only
final gmailSummaryProvider = Provider<GmailSummary?>((ref) {
  return ref.watch(proactiveInsightsProvider).insights?.gmailSummary;
});

/// WhatsApp summary only
final whatsappSummaryProvider = Provider<WhatsAppSummary?>((ref) {
  return ref.watch(proactiveInsightsProvider).insights?.whatsappSummary;
});

/// Tasks summary only
final tasksSummaryProvider = Provider<TasksSummary?>((ref) {
  return ref.watch(proactiveInsightsProvider).insights?.tasksSummary;
});

/// Active suggestions only (non-expired)
final activeSuggestionsProvider = Provider<List<Suggestion>>((ref) {
  return ref.watch(proactiveInsightsProvider).insights?.activeSuggestions ?? [];
});

/// High priority suggestions
final highPrioritySuggestionsProvider = Provider<List<Suggestion>>((ref) {
  return ref
          .watch(proactiveInsightsProvider)
          .insights
          ?.highPrioritySuggestions ??
      [];
});

/// Pattern insights
final patternInsightsProvider = Provider<List<PatternInsight>>((ref) {
  return ref.watch(proactiveInsightsProvider).insights?.patterns ?? [];
});

/// Total notification badge count
final proactiveNotificationCountProvider = Provider<int>((ref) {
  return ref
          .watch(proactiveInsightsProvider)
          .insights
          ?.totalNotificationCount ??
      0;
});

/// Whether Gitu needs user attention
final gituNeedsAttentionProvider = Provider<bool>((ref) {
  return ref.watch(proactiveInsightsProvider).insights?.needsAttention ?? false;
});
