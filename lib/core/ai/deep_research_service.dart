import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gemini_service.dart';
import 'openrouter_service.dart';
import 'ai_settings_service.dart';
import '../search/serper_service.dart';
import '../api/api_service.dart';
import '../security/global_credentials_service.dart';
import '../../features/gamification/gamification_provider.dart';

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

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'content': content,
        'snippet': snippet,
        'imageUrl': imageUrl,
        'credibility': credibility.name,
        'credibilityScore': credibilityScore,
      };
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

/// Clean, simple deep research service
class DeepResearchService {
  final Ref ref;
  final GeminiService _gemini = GeminiService();
  final OpenRouterService _openRouter = OpenRouterService();

  DeepResearchService(this.ref);

  // Credibility domains
  static const _academicDomains = [
    '.edu',
    '.ac.uk',
    'scholar.google',
    'arxiv.org',
    'pubmed'
  ];
  static const _govDomains = ['.gov', '.gov.uk', '.mil'];
  static const _newsDomains = [
    'reuters.com',
    'bbc.com',
    'nytimes.com',
    'wsj.com',
    'bloomberg.com'
  ];
  static const _proDomains = [
    'microsoft.com',
    'google.com',
    'stackoverflow.com',
    'github.com'
  ];

  /// Get source credibility
  SourceCredibility _getCredibility(String url) {
    final lower = url.toLowerCase();
    for (final d in _academicDomains) {
      if (lower.contains(d)) return SourceCredibility.academic;
    }
    for (final d in _govDomains) {
      if (lower.contains(d)) return SourceCredibility.government;
    }
    for (final d in _newsDomains) {
      if (lower.contains(d)) return SourceCredibility.news;
    }
    for (final d in _proDomains) {
      if (lower.contains(d)) return SourceCredibility.professional;
    }
    if (lower.contains('blog') || lower.contains('wordpress')) {
      return SourceCredibility.blog;
    }
    return SourceCredibility.unknown;
  }

  int _getCredibilityScore(SourceCredibility c) {
    switch (c) {
      case SourceCredibility.academic:
        return 95;
      case SourceCredibility.government:
        return 90;
      case SourceCredibility.news:
        return 80;
      case SourceCredibility.professional:
        return 75;
      case SourceCredibility.blog:
        return 50;
      case SourceCredibility.unknown:
        return 60;
    }
  }

  /// Get depth config
  ({int maxSources, int queryCount}) _getDepthConfig(ResearchDepth depth) {
    switch (depth) {
      case ResearchDepth.quick:
        return (maxSources: 3, queryCount: 3);
      case ResearchDepth.standard:
        return (maxSources: 7, queryCount: 5);
      case ResearchDepth.deep:
        return (maxSources: 15, queryCount: 8);
    }
  }

  /// Get API keys
  Future<String?> _getGeminiKey() async {
    try {
      return await ref
          .read(globalCredentialsServiceProvider)
          .getApiKey('gemini');
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getOpenRouterKey() async {
    try {
      return await ref
          .read(globalCredentialsServiceProvider)
          .getApiKey('openrouter');
    } catch (_) {
      return null;
    }
  }

  /// Get selected provider and model
  Future<(String provider, String model)> _getProviderAndModel() async {
    final model = await AISettingsService.getModel() ?? 'gemini-2.0-flash';
    final provider = await AISettingsService.getProviderForModel(model, ref);
    return (provider, model);
  }

  /// Generate AI content with timeout
  Future<String> _generateAI(String prompt) async {
    final (provider, model) = await _getProviderAndModel();
    debugPrint('[Research] Using $provider with model $model');

    // Get dynamic max_tokens based on model's context window
    final maxTokens = await AISettingsService.getMaxTokensForModel(model, ref);
    debugPrint('[Research] Using maxTokens: $maxTokens');

    try {
      if (provider == 'openrouter') {
        final key = await _getOpenRouterKey();
        return await _openRouter
            .generateContent(prompt,
                model: model, apiKey: key, maxTokens: maxTokens)
            .timeout(const Duration(seconds: 120));
      } else {
        final key = await _getGeminiKey();
        return await _gemini
            .generateContent(prompt,
                model: model, apiKey: key, maxTokens: maxTokens)
            .timeout(const Duration(seconds: 120));
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      debugPrint('[Research] AI generation error: $e');

      // Check for credit/quota errors and provide helpful message
      if (errorStr.contains('credit') ||
          errorStr.contains('quota') ||
          errorStr.contains('afford')) {
        throw Exception(
            'Out of API credits. Please add credits at openrouter.ai/settings/credits or switch to Gemini in AI Settings.');
      }

      // Check for context length errors
      if (errorStr.contains('max_tokens') ||
          errorStr.contains('context length') ||
          errorStr.contains('context_length')) {
        throw Exception(
            'Context limit exceeded. The research gathered too much information for this model. Try reducing "Depth", switching to a model with a larger context window (like Gemini 1.5 Pro or Claude 3 Opus), or try again.');
      }
      rethrow;
    }
  }

  /// Generate search queries
  Future<List<String>> _generateQueries(String query, int count) async {
    final prompt =
        '''Generate $count specific Google search queries to research: "$query"
Return only the queries, one per line, no bullets or numbers.''';

    try {
      final response =
          await _generateAI(prompt).timeout(const Duration(seconds: 30));
      final queries = response
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .take(count)
          .toList();
      return queries.isNotEmpty
          ? queries
          : [query, '$query explained', '$query examples'];
    } catch (e) {
      debugPrint('[Research] Query generation failed: $e');
      return [query, '$query explained', '$query examples'];
    }
  }

  /// Build report prompt
  String _buildReportPrompt(
      String query, List<ResearchSource> sources, ResearchTemplate template,
      {List<String>? images}) {
    final sourcesText = sources.take(10).map((s) => '''
Source: ${s.title} [${s.credibility.name.toUpperCase()}]
URL: ${s.url}
Content: ${s.content.length > 2000 ? s.content.substring(0, 2000) : s.content}
''').join('\n---\n');

    final templateGuide = switch (template) {
      ResearchTemplate.academic =>
        'Structure as academic paper: Abstract, Introduction, Literature Review, Findings, Conclusion, References.',
      ResearchTemplate.productComparison =>
        'Structure as comparison: Overview, Feature Comparison, Pricing, Pros/Cons, Recommendation.',
      ResearchTemplate.marketAnalysis =>
        'Structure as market analysis: Overview, Key Players, Trends, Challenges, Outlook.',
      ResearchTemplate.howToGuide =>
        'Structure as guide: Overview, Prerequisites, Step-by-Step, Tips, Troubleshooting.',
      ResearchTemplate.prosAndCons =>
        'Structure as analysis: Overview, Advantages, Disadvantages, Verdict.',
      ResearchTemplate.shopping =>
        'Structure as buying guide: Top Picks, Detailed Reviews, Price Comparison, Recommendation.',
      ResearchTemplate.general =>
        'Structure: Executive Summary, Introduction, Analysis, Key Findings, Conclusion, Sources.',
    };

    // Build image references for the AI to use
    String imageInstructions = '';
    if (images != null && images.isNotEmpty) {
      final validImages = images
          .where((url) =>
              url.startsWith('http') &&
              (url.contains('.jpg') ||
                  url.contains('.jpeg') ||
                  url.contains('.png') ||
                  url.contains('.gif') ||
                  url.contains('.webp') ||
                  url.contains('image')))
          .take(5)
          .toList();

      if (validImages.isNotEmpty) {
        imageInstructions = '''

IMPORTANT: Include relevant images in your report using markdown image syntax.
Available images (use these URLs directly in your report where appropriate):
${validImages.asMap().entries.map((e) => '- Image ${e.key + 1}: ${e.value}').join('\n')}

Insert images at relevant sections using: ![Description](URL)
Place at least 2-3 images throughout the report to make it visually engaging.''';
      }
    }

    return '''Create a comprehensive research report on: "$query"

$templateGuide

Use markdown formatting. Cite sources with [Title](URL). Be thorough and informative.$imageInstructions

SOURCES:
$sourcesText

Write the complete report:''';
  }

  /// Enhance report with images if AI didn't include them
  String _enhanceReportWithImages(String report, List<String> images) {
    if (images.isEmpty) return report;

    // Check if report already has images
    if (report.contains('![')) return report;

    // Filter valid image URLs
    final validImages = images
        .where((url) =>
            url.startsWith('http') &&
            (url.contains('.jpg') ||
                url.contains('.jpeg') ||
                url.contains('.png') ||
                url.contains('.gif') ||
                url.contains('.webp') ||
                url.contains('image')))
        .take(4)
        .toList();

    if (validImages.isEmpty) return report;

    // Find good insertion points (after headers or paragraphs)
    final lines = report.split('\n');
    final result = <String>[];
    int imageIndex = 0;
    int lineCount = 0;

    for (int i = 0; i < lines.length; i++) {
      result.add(lines[i]);
      lineCount++;

      // Insert image after major sections (## headers) or every ~15 lines
      final isHeader = lines[i].startsWith('## ');
      final isGoodBreak = lineCount >= 15 && lines[i].isEmpty;

      if (imageIndex < validImages.length && (isHeader || isGoodBreak)) {
        // Add image after the next non-empty line following a header
        if (isHeader && i + 1 < lines.length) {
          continue; // Wait for content after header
        }
        result.add('');
        result.add(
            '![Research Image ${imageIndex + 1}](${validImages[imageIndex]})');
        result.add('');
        imageIndex++;
        lineCount = 0;
      }
    }

    // If we still have images and didn't insert any, add them at the end before sources
    if (imageIndex == 0 && validImages.isNotEmpty) {
      // Find "Sources" or "References" section
      int insertIndex = result.length;
      for (int i = result.length - 1; i >= 0; i--) {
        if (result[i].toLowerCase().contains('## source') ||
            result[i].toLowerCase().contains('## reference')) {
          insertIndex = i;
          break;
        }
      }

      // Insert images before sources section
      final imagesToAdd = <String>['', '## Visual References', ''];
      for (int j = 0; j < validImages.length && j < 3; j++) {
        imagesToAdd.add('![Research Image ${j + 1}](${validImages[j]})');
        imagesToAdd.add('');
      }
      result.insertAll(insertIndex, imagesToAdd);
    }

    return result.join('\n');
  }

  /// Main research method - simple and reliable
  Stream<ResearchUpdate> research({
    required String query,
    required String notebookId,
    ResearchDepth depth = ResearchDepth.standard,
    ResearchTemplate template = ResearchTemplate.general,
  }) async* {
    final config = _getDepthConfig(depth);
    final sources = <ResearchSource>[];
    final images = <String>[];
    final videos = <String>[];

    try {
      // Step 1: Generate search queries
      yield ResearchUpdate(
          status: 'Generating research angles...', progress: 0.1);

      final queries = await _generateQueries(query, config.queryCount);
      debugPrint('[Research] Generated ${queries.length} queries');

      // Step 2: Search and collect sources
      final serper = SerperService(ref);
      int completed = 0;

      for (final q in queries) {
        if (sources.length >= config.maxSources) break;

        final progress = 0.15 + (0.4 * completed / queries.length);
        yield ResearchUpdate(
            status: 'Searching: "$q"...',
            progress: progress,
            sources: List.from(sources),
            images: List.from(images));

        try {
          final results = await serper
              .search(q, num: 3)
              .timeout(const Duration(seconds: 15));

          for (final item in results) {
            if (sources.length >= config.maxSources) break;
            if (sources.any((s) => s.url == item.link)) continue;

            // Notify UI of the specific website found
            try {
              final host = Uri.parse(item.link).host.replaceFirst('www.', '');
              yield ResearchUpdate(
                  status: 'Found info from $host...',
                  progress: progress,
                  sources: List.from(sources),
                  images: List.from(images));
            } catch (_) {}

            final cred = _getCredibility(item.link);
            sources.add(ResearchSource(
              title: item.title,
              url: item.link,
              content: item.snippet,
              snippet: item.snippet,
              imageUrl: item.imageUrl,
              credibility: cred,
              credibilityScore: _getCredibilityScore(cred),
            ));

            // Collect image if available
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
              images.add(item.imageUrl!);
            }

            // Brief pause to let the UI breathe and show the update
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          debugPrint('[Research] Search error for "$q": $e');
        }

        completed++;
      }

      // Step 2.5: Search for images specifically
      yield ResearchUpdate(
          status: 'Finding relevant images...',
          progress: 0.55,
          sources: List.from(sources),
          images: List.from(images));

      try {
        final imageResults = await serper
            .search('$query images', type: 'images', num: 6)
            .timeout(const Duration(seconds: 10));

        for (final img in imageResults) {
          if (img.imageUrl != null && !images.contains(img.imageUrl)) {
            images.add(img.imageUrl!);
          }
          if (img.link.isNotEmpty && !images.contains(img.link)) {
            images.add(img.link);
          }
        }
      } catch (e) {
        debugPrint('[Research] Image search error: $e');
      }

      // Step 2.6: Search for videos
      yield ResearchUpdate(
          status: 'Finding relevant videos...',
          progress: 0.6,
          sources: List.from(sources),
          images: List.from(images));

      try {
        final videoResults = await serper
            .search(query, type: 'videos', num: 4)
            .timeout(const Duration(seconds: 10));

        for (final vid in videoResults) {
          if (vid.link.isNotEmpty && !videos.contains(vid.link)) {
            videos.add(vid.link);
          }
        }
      } catch (e) {
        debugPrint('[Research] Video search error: $e');
      }

      debugPrint(
          '[Research] Collected ${sources.length} sources, ${images.length} images, ${videos.length} videos');

      if (sources.isEmpty) {
        yield ResearchUpdate(
          status: 'No sources found',
          progress: 1.0,
          isComplete: true,
          error: 'Could not find any sources. Check your Serper API key.',
        );
        return;
      }

      // Sort by credibility
      sources.sort((a, b) => b.credibilityScore.compareTo(a.credibilityScore));

      // Step 3: Generate report
      yield ResearchUpdate(
          status: 'Writing report with images...',
          progress: 0.75,
          sources: sources,
          images: images,
          videos: videos);

      final prompt =
          _buildReportPrompt(query, sources, template, images: images);
      var report = await _generateAI(prompt);

      // Enhance report with images if AI didn't include them
      report = _enhanceReportWithImages(report, images);

      if (report.isEmpty) {
        yield ResearchUpdate(
          status: 'Failed to generate report',
          progress: 1.0,
          sources: sources,
          images: images,
          videos: videos,
          isComplete: true,
          error: 'AI returned empty response',
        );
        return;
      }

      debugPrint('[Research] Report generated: ${report.length} chars');

      // Step 4: Save to backend
      try {
        final api = ref.read(apiServiceProvider);
        await api.saveResearchSession(
          notebookId: notebookId,
          query: query,
          report: report,
          sources: sources.map((s) => s.toJson()).toList(),
        );
      } catch (e) {
        debugPrint('[Research] Failed to save: $e');
      }

      // Track gamification
      try {
        ref.read(gamificationProvider.notifier).trackDeepResearch();
      } catch (_) {}

      // Done!
      yield ResearchUpdate(
        status: 'Research complete!',
        progress: 1.0,
        result: report,
        sources: sources,
        images: images,
        videos: videos,
        isComplete: true,
      );
    } catch (e) {
      debugPrint('[Research] Fatal error: $e');
      yield ResearchUpdate(
        status: 'Error: $e',
        progress: 1.0,
        sources: sources.isNotEmpty ? sources : null,
        images: images.isNotEmpty ? images : null,
        videos: videos.isNotEmpty ? videos : null,
        isComplete: true,
        error: e.toString(),
      );
    }
  }
}
