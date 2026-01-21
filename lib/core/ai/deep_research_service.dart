import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';
import '../../features/gamification/gamification_provider.dart';
import 'ai_settings_service.dart';

final deepResearchServiceProvider = Provider<DeepResearchService>((ref) {
  return DeepResearchService(ref);
});

/// Research depth levels
enum ResearchDepth { quick, standard, deep }

/// Research templates
enum ResearchTemplate {
  general,
  academic,
  productComparison,
  marketAnalysis,
  howToGuide,
  prosAndCons,
  shopping,
}

/// Source credibility
enum SourceCredibility {
  academic,
  government,
  news,
  professional,
  blog,
  unknown
}

/// Research source model
class ResearchSource {
  final String title;
  final String url;
  final String content;
  final String? snippet;
  final String? imageUrl;
  final SourceCredibility credibility;
  final int credibilityScore;

  ResearchSource({
    required this.title,
    required this.url,
    required this.content,
    this.snippet,
    this.imageUrl,
    this.credibility = SourceCredibility.unknown,
    this.credibilityScore = 60,
  });

  factory ResearchSource.fromJson(Map<String, dynamic> json) {
    return ResearchSource(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      content: json['content'] ?? '',
      snippet: json['snippet'],
      imageUrl: json['imageUrl'],
      credibility: _parseCredibility(json['credibility']),
      credibilityScore: json['credibilityScore'] ?? 60,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'content': content,
        'snippet': snippet,
        'imageUrl': imageUrl,
        'credibility': credibility.name,
        'credibilityScore': credibilityScore,
      };

  static SourceCredibility _parseCredibility(String? value) {
    if (value == null) return SourceCredibility.unknown;
    try {
      return SourceCredibility.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return SourceCredibility.unknown;
    }
  }
}

/// Research update for progress tracking
class ResearchUpdate {
  final String status;
  final double progress;
  final String? result;
  final List<ResearchSource>? sources;
  final List<String>? images;
  final List<String>? videos;
  final bool isComplete;
  final String? error;

  ResearchUpdate({
    required this.status,
    required this.progress,
    this.result,
    this.sources,
    this.images,
    this.videos,
    this.isComplete = false,
    this.error,
  });
}

/// Clean, simple deep research service - Backend Powered
class DeepResearchService {
  final Ref ref;

  DeepResearchService(this.ref);

  /// Main research method using backend streaming
  Stream<ResearchUpdate> research({
    required String query,
    required String notebookId,
    ResearchDepth depth = ResearchDepth.standard,
    ResearchTemplate template = ResearchTemplate.general,
  }) async* {
    try {
      final api = ref.read(apiServiceProvider);

      // Get AI settings (provider/model)
      final settings =
          await AISettingsService.getSettingsWithProviderDetection(ref);

      // Calculate max results based on depth
      int maxResults = 10;
      switch (depth) {
        case ResearchDepth.quick:
          maxResults = 5;
          break;
        case ResearchDepth.standard:
          maxResults = 10;
          break;
        case ResearchDepth.deep:
          maxResults = 20;
          break;
      }

      final stream = api.performDeepResearchStream(
        query: query,
        notebookId: notebookId,
        maxResults: maxResults,
        includeImages: true,
        provider: settings.provider,
        model: settings.model,
      );

      // Listen to the stream and yield updates
      await for (final event in stream) {
        try {
          // Safely extract fields with null checks and defaults
          final step = event['step'] as int? ?? 0;
          final message = event['message'] as String? ?? 'Processing...';
          final type = event['type'] as String? ?? 'progress';
          final data = event['data'] as Map<String, dynamic>?;

          // Calculate progress based on step/type
          // Steps: 1 (start), 2 (search), 3 (results), 4 (extract), 5 (analyzed), 6 (summary), 7 (complete)
          double progress = 0.1;
          if (step > 0) {
            progress = (step / 8.0).clamp(0.1, 0.95);
          }

          if (type == 'complete') {
            progress = 1.0;

            // Parse final results safely
            final summary = data?['summary'] as String? ?? '';
            final sourcesData =
                (data?['sources'] as List?)?.cast<Map<String, dynamic>>() ?? [];

            final sources = sourcesData
                .map((s) {
                  try {
                    return ResearchSource(
                      title: s['title'] as String? ?? 'Source',
                      url: s['url'] as String? ?? '',
                      content: s['snippet'] as String? ?? '',
                      snippet: s['snippet'] as String?,
                      credibility: SourceCredibility.unknown,
                    );
                  } catch (e) {
                    debugPrint('[DeepResearch] Error parsing source: $e');
                    return null;
                  }
                })
                .whereType<ResearchSource>()
                .toList();

            // Collect images if available in sources
            final images = <String>[]; // Backend needs to pass these through

            // Track gamification locally for now
            try {
              ref.read(gamificationProvider.notifier).trackDeepResearch();
            } catch (e) {
              debugPrint('[DeepResearch] Gamification tracking error: $e');
            }

            yield ResearchUpdate(
              status: 'Research complete!',
              progress: 1.0,
              result: summary.isNotEmpty ? summary : null,
              sources: sources,
              images: images,
              isComplete: true,
            );
          } else {
            yield ResearchUpdate(
              status: message,
              progress: progress,
              isComplete: false,
            );
          }
        } catch (e) {
          debugPrint('[DeepResearch] Error processing stream event: $e');
          // Continue processing other events instead of crashing
          yield ResearchUpdate(
            status: 'Processing...',
            progress: 0.5,
            isComplete: false,
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[DeepResearch] Error: $e');
      debugPrint('[DeepResearch] Stack trace: $stackTrace');

      // Provide a user-friendly error message
      String errorMessage = 'An error occurred during research';
      if (e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        errorMessage = 'Authentication error. Please log in again.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      }

      yield ResearchUpdate(
        status: errorMessage,
        progress: 0.0,
        isComplete: true,
        error: e.toString(),
      );
    }
  }

  // Previous helper methods for credibility can be removed as backend handles logic,
  // or kept if we want to run credibility scoring on the frontend for now.
  // I've removed them to keep the file clean.
}
