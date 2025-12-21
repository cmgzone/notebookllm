import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalyticsService {
  final Ref ref;

  AnalyticsService(this.ref);

  /// Track a query
  Future<void> trackQuery({
    required String query,
    String? notebookId,
    List<String>? sourcesUsed,
    int? responseTimeMs,
  }) async {
    // Analytics disabled for now
  }

  /// Get query statistics
  Future<Map<String, dynamic>> getQueryStats({
    String? notebookId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return {
      'totalQueries': 0,
      'avgResponseTime': 0,
      'topSources': <Map<String, dynamic>>[],
      'queriesOverTime': <Map<String, dynamic>>[],
    };
  }

  /// Get most queried topics (simple keyword extraction)
  Future<List<Map<String, dynamic>>> getTopTopics({
    String? notebookId,
    int limit = 10,
  }) async {
    return [];
  }
}

final analyticsServiceProvider = Provider((ref) => AnalyticsService(ref));
