import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_service.dart';
import 'openrouter_service.dart';
import 'context_engineering_service.dart';
import 'ai_models_provider.dart';
import '../search/serper_service.dart';
import '../api/api_service.dart';
import '../security/global_credentials_service.dart';
import '../services/overlay_bubble_service.dart';
import '../../features/gamification/gamification_provider.dart';
import '../../features/research/research_session_provider.dart';

final deepResearchServiceProvider = Provider<DeepResearchService>((ref) {
  final geminiService = GeminiService();
  final openRouterService = OpenRouterService();
  final serperService = SerperService(ref);
  return DeepResearchService(
      ref, geminiService, openRouterService, serperService);
});

/// Research depth levels
enum ResearchDepth {
  quick, // 3 sources, fast
  standard, // 7 sources, balanced
  deep, // 15+ sources with multi-hop
}

/// Research templates for different use cases
enum ResearchTemplate {
  general,
  academic,
  productComparison,
  marketAnalysis,
  howToGuide,
  prosAndCons,
}

/// Source credibility types
enum SourceCredibility {
  academic, // .edu, research papers
  government, // .gov sites
  news, // major news outlets
  professional, // industry sites
  blog, // personal blogs
  unknown,
}

/// Research configuration
class ResearchConfig {
  final ResearchDepth depth;
  final ResearchTemplate template;
  final bool useContextEngineering;
  final String? notebookId;

  const ResearchConfig({
    this.depth = ResearchDepth.standard,
    this.template = ResearchTemplate.general,
    this.useContextEngineering = false,
    this.notebookId,
  });

  int get maxSources {
    switch (depth) {
      case ResearchDepth.quick:
        return 3;
      case ResearchDepth.standard:
        return 7;
      case ResearchDepth.deep:
        return 15;
    }
  }

  int get subQueryCount {
    switch (depth) {
      case ResearchDepth.quick:
        return 3;
      case ResearchDepth.standard:
        return 5;
      case ResearchDepth.deep:
        return 8;
    }
  }

  int get sourcesPerQuery {
    switch (depth) {
      case ResearchDepth.quick:
        return 2;
      case ResearchDepth.standard:
        return 3;
      case ResearchDepth.deep:
        return 5;
    }
  }
}

class DeepResearchService {
  final Ref ref;
  final GeminiService _geminiService;
  final OpenRouterService _openRouterService;
  final SerperService _serperService;
  final ContextEngineeringService _contextEngineeringService;

  // Domain credibility mappings
  static const _academicDomains = [
    '.edu',
    '.ac.uk',
    '.ac.',
    'scholar.google',
    'researchgate',
    'academia.edu',
    'arxiv.org',
    'pubmed',
    'jstor'
  ];
  static const _governmentDomains = ['.gov', '.gov.uk', '.gov.au', '.mil'];
  static const _newsDomains = [
    'reuters.com',
    'apnews.com',
    'bbc.com',
    'nytimes.com',
    'wsj.com',
    'theguardian.com',
    'washingtonpost.com',
    'bloomberg.com',
    'forbes.com',
    'techcrunch.com',
    'wired.com',
    'arstechnica.com'
  ];
  static const _professionalDomains = [
    'microsoft.com',
    'google.com',
    'aws.amazon.com',
    'developer.',
    'docs.',
    'documentation',
    'stackoverflow.com',
    'github.com',
    'medium.com'
  ];

  DeepResearchService(this.ref, this._geminiService, this._openRouterService,
      this._serperService)
      : _contextEngineeringService =
            ref.read(contextEngineeringServiceProvider);

  /// Determine source credibility based on domain
  SourceCredibility getSourceCredibility(String url) {
    final lowerUrl = url.toLowerCase();

    for (final domain in _academicDomains) {
      if (lowerUrl.contains(domain)) return SourceCredibility.academic;
    }
    for (final domain in _governmentDomains) {
      if (lowerUrl.contains(domain)) return SourceCredibility.government;
    }
    for (final domain in _newsDomains) {
      if (lowerUrl.contains(domain)) return SourceCredibility.news;
    }
    for (final domain in _professionalDomains) {
      if (lowerUrl.contains(domain)) return SourceCredibility.professional;
    }

    // Check for blog indicators
    if (lowerUrl.contains('blog') ||
        lowerUrl.contains('wordpress') ||
        lowerUrl.contains('blogspot') ||
        lowerUrl.contains('substack')) {
      return SourceCredibility.blog;
    }

    return SourceCredibility.unknown;
  }

  /// Get credibility score (0-100)
  int getCredibilityScore(SourceCredibility credibility) {
    switch (credibility) {
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

  /// Get template-specific prompt additions
  String _getTemplatePrompt(ResearchTemplate template) {
    switch (template) {
      case ResearchTemplate.academic:
        return '''
## ACADEMIC RESEARCH FORMAT
Structure your report as an academic paper:
1. Abstract (150-200 words)
2. Introduction with research questions
3. Literature Review
4. Methodology (how sources were gathered)
5. Findings & Analysis
6. Discussion
7. Conclusion
8. References (in APA format)

Use formal academic language. Cite all claims with sources.
''';
      case ResearchTemplate.productComparison:
        return '''
## PRODUCT COMPARISON FORMAT
Structure your report as a comparison analysis:
1. Executive Summary
2. Products/Options Overview
3. Feature-by-Feature Comparison Table
4. Pricing Analysis
5. Pros and Cons for Each Option
6. Use Case Recommendations
7. Final Verdict & Recommendations
8. Sources

Be objective and data-driven. Include specific features, prices, and specifications.
''';
      case ResearchTemplate.marketAnalysis:
        return '''
## MARKET ANALYSIS FORMAT
Structure your report as a market analysis:
1. Executive Summary
2. Market Overview & Size
3. Key Players & Market Share
4. Trends & Growth Drivers
5. Challenges & Barriers
6. Competitive Landscape
7. Future Outlook & Predictions
8. Investment Considerations
9. Sources

Include statistics, market data, and growth projections where available.
''';
      case ResearchTemplate.howToGuide:
        return '''
## HOW-TO GUIDE FORMAT
Structure your report as a practical guide:
1. Overview & Prerequisites
2. Step-by-Step Instructions (numbered)
3. Tips & Best Practices
4. Common Mistakes to Avoid
5. Troubleshooting Guide
6. Advanced Tips (optional)
7. Resources & Further Reading

Be clear, actionable, and beginner-friendly. Include examples.
''';
      case ResearchTemplate.prosAndCons:
        return '''
## PROS AND CONS ANALYSIS FORMAT
Structure your report as a balanced analysis:
1. Topic Overview
2. Key Advantages (Pros)
   - List each with explanation
3. Key Disadvantages (Cons)
   - List each with explanation
4. Who Should Consider This
5. Who Should Avoid This
6. Alternatives to Consider
7. Final Assessment
8. Sources

Be balanced and objective. Support each point with evidence.
''';
      case ResearchTemplate.general:
        return '';
    }
  }

  /// Get user's selected AI provider from settings
  Future<String> _getSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ai_provider') ?? 'gemini';
  }

  /// Get user's selected AI model from settings
  Future<String> _getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ai_model') ?? 'gemini-1.5-flash';
  }

  /// Get context window for the selected model
  Future<int> _getModelContextWindow(String modelId) async {
    try {
      final modelsAsync = await ref.read(availableModelsProvider.future);

      // Search in all providers
      for (final models in modelsAsync.values) {
        final model = models.where((m) => m.id == modelId).firstOrNull;
        if (model != null) {
          return model.contextWindow;
        }
      }
    } catch (e) {
      debugPrint('[DeepResearch] Failed to get model context window: $e');
    }

    // Default fallback
    return 8192;
  }

  Future<String?> _getGeminiKey() async {
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      return await creds.getApiKey('gemini');
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getOpenRouterKey() async {
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      return await creds.getApiKey('openrouter');
    } catch (e) {
      return null;
    }
  }

  Future<String> _generateContent(String prompt) async {
    final provider = await _getSelectedProvider();
    final model = await _getSelectedModel();

    if (provider == 'openrouter') {
      final apiKey = await _getOpenRouterKey();
      return await _openRouterService.generateContent(prompt,
          model: model, apiKey: apiKey);
    } else {
      final apiKey = await _getGeminiKey();
      return await _geminiService.generateContent(prompt,
          model: model, apiKey: apiKey);
    }
  }

  /// Main research method with configurable options
  Stream<DeepResearchUpdate> research(String query,
      {required String notebookId,
      bool useContextEngineering = false,
      ResearchDepth depth = ResearchDepth.standard,
      ResearchTemplate template = ResearchTemplate.general}) async* {
    final config = ResearchConfig(
      depth: depth,
      template: template,
      useContextEngineering: useContextEngineering,
      notebookId: notebookId,
    );

    yield* _performResearch(query, config);
  }

  /// Perform research with full configuration
  Stream<DeepResearchUpdate> _performResearch(
      String query, ResearchConfig config) async* {
    try {
      final depthName = config.depth.name.toUpperCase();
      yield DeepResearchUpdate('[$depthName] Analyzing query...', 0.1);
      await overlayBubbleService.show(
          status: '[$depthName] Analyzing query...');

      // 0. Context Engineering Analysis (if enabled)
      TopicContextAnalysis? contextAnalysis;
      if (config.useContextEngineering) {
        yield DeepResearchUpdate(
            'Context Agent: Analyzing topic depth...', 0.15);
        await overlayBubbleService.updateStatus('Analyzing context...',
            progress: 15);
        try {
          contextAnalysis = await _contextEngineeringService
              .analyzeResearchTopic(query)
              .timeout(const Duration(seconds: 90), onTimeout: () {
            debugPrint('[DeepResearch] Context analysis timed out after 90s');
            return TopicContextAnalysis.empty();
          });
          debugPrint(
              '[DeepResearch] Context analysis complete: ${contextAnalysis.coreConcepts.length} concepts');
        } catch (e) {
          debugPrint('[DeepResearch] Context analysis failed: $e');
          contextAnalysis = null;
        }
      }

      // 1. Generate sub-queries based on depth and template
      List<String> subQueries;
      try {
        subQueries = await _generateSubQueries(
          query,
          contextAnalysis: contextAnalysis,
          template: config.template,
          count: config.subQueryCount,
        );
        debugPrint(
            '[DeepResearch] Generated ${subQueries.length} sub-queries: $subQueries');

        if (subQueries.isEmpty) {
          throw Exception(
              'Failed to generate research angles. Please check your AI API keys.');
        }

        yield DeepResearchUpdate(
            'Generated ${subQueries.length} research angles...', 0.2);
        await overlayBubbleService.updateStatus('Planning research...',
            progress: 20);
      } catch (e) {
        debugPrint('[DeepResearch] Error generating sub-queries: $e');
        throw Exception('Failed to generate research angles: $e');
      }

      // 2. Search and scrape with depth-based limits
      final results = <ResearchSource>[];
      final allImages = <String>[];
      final allVideos = <String>[];
      int completed = 0;

      // Initial image search for the main query
      try {
        final images = await _searchImages(query);
        allImages.addAll(images);
        debugPrint(
            '[DeepResearch] Found ${images.length} images for main query');
      } catch (e) {
        debugPrint('[DeepResearch] Image search error (ignored): $e');
      }

      // Initial video search for the main query
      try {
        final videos = await _searchVideos(query);
        allVideos.addAll(videos);
        debugPrint(
            '[DeepResearch] Found ${videos.length} videos for main query');
      } catch (e) {
        debugPrint('[DeepResearch] Video search error (ignored): $e');
      }

      for (final subQuery in subQueries) {
        // Stop if we've reached max sources
        if (results.length >= config.maxSources) break;

        final progress = 0.2 + (0.5 * (completed / subQueries.length));
        yield DeepResearchUpdate('Searching: "$subQuery"...', progress,
            sources: List.from(results));

        await overlayBubbleService.updateStatus(
          'Searching: "$subQuery"',
          progress: (progress * 100).toInt(),
        );

        try {
          // Search web with depth-based limit
          final items = await _serperService.search(subQuery,
              num: config.sourcesPerQuery);
          debugPrint(
              '[DeepResearch] Found ${items.length} results for "$subQuery"');

          // Search images for sub-query
          try {
            final subImages = await _searchImages(subQuery);
            allImages.addAll(subImages);
          } catch (e) {
            debugPrint(
                '[DeepResearch] Sub-query image search error (ignored): $e');
          }

          // Search videos for sub-query
          try {
            final subVideos = await _searchVideos(subQuery);
            allVideos.addAll(subVideos);
          } catch (e) {
            debugPrint(
                '[DeepResearch] Sub-query video search error (ignored): $e');
          }

          int contentFetched = 0;
          for (final item in items) {
            // Stop if we've reached max sources
            if (results.length >= config.maxSources) break;

            try {
              final content = await _serperService.fetchPageContent(item.link);
              final actualContent = content.length > 200
                  ? content
                  : '${item.snippet}\n\nNote: Full page content unavailable (likely CORS restriction in browser)';

              if (item.snippet.isNotEmpty) {
                // Add credibility scoring
                final credibility = getSourceCredibility(item.link);
                final credibilityScore = getCredibilityScore(credibility);

                results.add(ResearchSource(
                  title: item.title,
                  url: item.link,
                  content: actualContent,
                  snippet: item.snippet,
                  credibility: credibility,
                  credibilityScore: credibilityScore,
                ));
                contentFetched++;
              }
            } catch (e) {
              debugPrint(
                  '[DeepResearch] Failed to fetch content from ${item.link}: $e');
              if (item.snippet.isNotEmpty) {
                final credibility = getSourceCredibility(item.link);
                results.add(ResearchSource(
                  title: item.title,
                  url: item.link,
                  content: item.snippet,
                  snippet: item.snippet,
                  credibility: credibility,
                  credibilityScore: getCredibilityScore(credibility),
                ));
                contentFetched++;
              }
            }
          }
          debugPrint(
              '[DeepResearch] Fetched content from $contentFetched/${items.length} pages');

          // For deep research, do multi-hop searching
          if (config.depth == ResearchDepth.deep &&
              results.length < config.maxSources) {
            yield DeepResearchUpdate(
              'Multi-hop: Exploring related topics...',
              progress + 0.05,
              sources: List.from(results),
            );

            // Generate follow-up queries based on initial results
            final followUpQueries =
                await _generateFollowUpQueries(query, results.take(5).toList());
            for (final followUp in followUpQueries.take(2)) {
              if (results.length >= config.maxSources) break;

              try {
                final followUpItems =
                    await _serperService.search(followUp, num: 3);
                for (final item in followUpItems) {
                  if (results.length >= config.maxSources) break;
                  if (results.any((r) => r.url == item.link)) {
                    continue; // Skip duplicates
                  }

                  final credibility = getSourceCredibility(item.link);
                  results.add(ResearchSource(
                    title: item.title,
                    url: item.link,
                    content: item.snippet,
                    snippet: item.snippet,
                    credibility: credibility,
                    credibilityScore: getCredibilityScore(credibility),
                  ));
                }
              } catch (e) {
                debugPrint('[DeepResearch] Multi-hop search error: $e');
              }
            }
          }

          yield DeepResearchUpdate(
            'Analyzed ${items.length} sources for "$subQuery"',
            progress + 0.1,
            sources: List.from(results),
            images: List.from(allImages),
            videos: List.from(allVideos),
          );
        } catch (e) {
          debugPrint('[DeepResearch] Search error for "$subQuery": $e');
          continue;
        }

        completed++;
      }

      debugPrint('[DeepResearch] Total sources collected: ${results.length}');

      if (results.isEmpty) {
        throw Exception(
            'Failed to find any relevant information. This might be due to:\n'
            '• Network connectivity issues\n'
            '• Serper API key not configured\n'
            '• All web pages failed to load\n'
            'Please check your internet connection and API keys.');
      }

      // Sort by credibility score
      results.sort((a, b) => b.credibilityScore.compareTo(a.credibilityScore));

      // Deduplicate images
      final uniqueImages = allImages.toSet().toList();
      final uniqueVideos = allVideos.toSet().toList();
      debugPrint('[DeepResearch] Total unique images: ${uniqueImages.length}');
      debugPrint('[DeepResearch] Total unique videos: ${uniqueVideos.length}');

      yield DeepResearchUpdate('Synthesizing comprehensive report...', 0.8,
          images: uniqueImages,
          videos: uniqueVideos,
          sources: List.from(results));
      await overlayBubbleService.updateStatus('Writing report...',
          progress: 80);

      // 3. Synthesize report with streaming
      final reportBuffer = StringBuffer();
      try {
        await for (final chunk in _synthesizeReportStream(
            query, results, uniqueImages, uniqueVideos,
            contextAnalysis: contextAnalysis, template: config.template)) {
          reportBuffer.write(chunk);

          yield DeepResearchUpdate(
            'Writing report...',
            0.8 + (0.15 * (reportBuffer.length / 10000).clamp(0, 1)),
            result: reportBuffer.toString(),
            sources: List.from(results),
            images: uniqueImages,
            videos: uniqueVideos,
            isStreaming: true,
          );
        }

        final report = reportBuffer.toString();
        debugPrint(
            '[DeepResearch] Report generated successfully (${report.length} chars)');

        if (report.isEmpty) {
          throw Exception(
              'AI generated an empty report. Please check your AI API keys.');
        }

        // Check if report needs continuation
        final hasConclusion = report.toLowerCase().contains('## conclusion') ||
            report.toLowerCase().contains('### conclusion');
        final hasReferences = report.toLowerCase().contains('## sources') ||
            report.toLowerCase().contains('## references') ||
            report.toLowerCase().contains('### sources');

        String finalReport = report;
        if (!hasConclusion || !hasReferences) {
          debugPrint(
              '[DeepResearch] Report appears truncated, generating continuation...');
          yield DeepResearchUpdate('Completing report...', 0.95,
              result: report,
              sources: List.from(results),
              images: uniqueImages,
              videos: uniqueVideos);

          try {
            final continuation = await _generateContinuation(
                report, results, hasConclusion, hasReferences);
            finalReport = '$report\n\n$continuation';
          } catch (e) {
            debugPrint('[DeepResearch] Continuation failed: $e');
            if (!hasReferences) {
              final refs = results
                  .take(12)
                  .map(
                      (s) => '- [${s.title}](${s.url}) (${s.credibility.name})')
                  .join('\n');
              finalReport = '$report\n\n## Sources & References\n$refs';
            }
          }
        }

        yield DeepResearchUpdate('Research complete!', 1.0,
            result: finalReport,
            sources: results,
            images: uniqueImages,
            videos: uniqueVideos);

        // 4. Save to backend
        try {
          final api = ref.read(apiServiceProvider);
          await api.saveResearchSession(
            notebookId: config.notebookId ?? '',
            query: query,
            report: finalReport,
            sources: results
                .map((s) => {
                      'title': s.title,
                      'url': s.url,
                      'content': s.content,
                      'snippet': s.snippet,
                      'credibility': s.credibility.name,
                      'credibilityScore': s.credibilityScore,
                    })
                .toList(),
          );
          ref.invalidate(researchSessionProvider);
        } catch (e) {
          debugPrint('[DeepResearch] Failed to save research session: $e');
        }
      } catch (e) {
        debugPrint('[DeepResearch] Error synthesizing report: $e');
        throw Exception('Failed to generate report: $e\n'
            'Please check your AI API keys (Gemini or OpenRouter).');
      }

      // Track gamification
      ref.read(gamificationProvider.notifier).trackDeepResearch();
      ref.read(gamificationProvider.notifier).trackFeatureUsed('deep_research');

      await overlayBubbleService.updateStatus('Research Complete! ✓',
          progress: 100);
      await Future.delayed(const Duration(seconds: 2));
      await overlayBubbleService.hide();
    } catch (e) {
      debugPrint('[DeepResearch] Fatal error: $e');
      await overlayBubbleService.updateStatus('Error: Research Failed');
      await Future.delayed(const Duration(seconds: 3));
      await overlayBubbleService.hide();
      rethrow;
    }
  }

  /// Follow-up questions on existing research
  Stream<DeepResearchUpdate> askFollowUp(
    String followUpQuestion,
    String originalQuery,
    String existingReport,
    List<ResearchSource> existingSources,
  ) async* {
    try {
      yield DeepResearchUpdate('Processing follow-up question...', 0.1);

      // Search for additional information
      yield DeepResearchUpdate('Searching for additional information...', 0.3);

      final newSources = <ResearchSource>[];
      try {
        final items = await _serperService
            .search('$originalQuery $followUpQuestion', num: 5);
        for (final item in items) {
          if (existingSources.any((s) => s.url == item.link)) continue;

          final credibility = getSourceCredibility(item.link);
          newSources.add(ResearchSource(
            title: item.title,
            url: item.link,
            content: item.snippet,
            snippet: item.snippet,
            credibility: credibility,
            credibilityScore: getCredibilityScore(credibility),
          ));
        }
      } catch (e) {
        debugPrint('[DeepResearch] Follow-up search error: $e');
      }

      yield DeepResearchUpdate('Generating answer...', 0.6,
          sources: newSources);

      // Generate follow-up answer
      final prompt = '''
You are a research assistant. The user has asked a follow-up question about a research topic.

## ORIGINAL RESEARCH QUERY
"$originalQuery"

## EXISTING REPORT SUMMARY
${existingReport.length > 3000 ? existingReport.substring(0, 3000) : existingReport}

## FOLLOW-UP QUESTION
"$followUpQuestion"

## ADDITIONAL SOURCES FOUND
${newSources.map((s) => '- ${s.title}: ${s.snippet}').join('\n')}

## EXISTING SOURCES
${existingSources.take(5).map((s) => '- ${s.title} (${s.credibility.name})').join('\n')}

---
Provide a detailed answer to the follow-up question, incorporating both the existing research and any new information found. Use markdown formatting.
''';

      final answer = await _generateContent(prompt);

      yield DeepResearchUpdate(
        'Follow-up complete!',
        1.0,
        result: answer,
        sources: [...existingSources, ...newSources],
      );
    } catch (e) {
      debugPrint('[DeepResearch] Follow-up error: $e');
      rethrow;
    }
  }

  /// Generate follow-up queries for multi-hop research
  Future<List<String>> _generateFollowUpQueries(
      String query, List<ResearchSource> sources) async {
    final sourceSummary =
        sources.map((s) => '- ${s.title}: ${s.snippet ?? ""}').join('\n');

    final prompt = '''
Based on this research query and initial findings, generate 3 follow-up search queries to explore deeper aspects.

Query: "$query"

Initial findings:
$sourceSummary

Generate 3 specific follow-up search queries (one per line, no bullets or numbers):
''';

    try {
      final response =
          await _generateContent(prompt).timeout(const Duration(seconds: 30));
      return response
          .split('\n')
          .map((l) => l.trim())
          .where(
              (l) => l.isNotEmpty && !l.startsWith('-') && !l.startsWith('*'))
          .take(3)
          .toList();
    } catch (e) {
      debugPrint('[DeepResearch] Follow-up query generation failed: $e');
      return [];
    }
  }

  /// Perform research in the cloud (backend) using background jobs
  /// Research continues on server even if app is closed
  /// Returns a stream of updates, polls for completion
  Stream<DeepResearchUpdate> researchInCloud(
    String query, {
    required String notebookId,
    ResearchDepth depth = ResearchDepth.standard,
    ResearchTemplate template = ResearchTemplate.general,
  }) async* {
    try {
      yield DeepResearchUpdate('[CLOUD] Starting background research...', 0.1);
      await overlayBubbleService.show(
          status: '[CLOUD] Starting background research...');

      final api = ref.read(apiServiceProvider);

      // Start background job (returns immediately)
      final jobId = await api.startBackgroundResearch(
        query: query,
        depth: depth.name,
        template: template.name,
        notebookId: notebookId.isNotEmpty ? notebookId : null,
      );

      debugPrint('[DeepResearch] Background job started: $jobId');

      yield DeepResearchUpdate(
          '[CLOUD] Research running on server (Job: ${jobId.substring(0, 8)}...)',
          0.2);
      await overlayBubbleService.updateStatus(
          'Research running on server...\nYou can close the app - check history later',
          progress: 20);

      // Poll for completion
      int pollCount = 0;
      const maxPolls = 120; // 10 minutes max (5 second intervals)
      const pollInterval = Duration(seconds: 5);

      while (pollCount < maxPolls) {
        await Future.delayed(pollInterval);
        pollCount++;

        try {
          final jobStatus = await api.getResearchJobStatus(jobId);

          if (jobStatus == null) {
            throw Exception('Job not found');
          }

          final status = jobStatus['status'] as String? ?? 'unknown';
          final progress = (jobStatus['progress'] as num?)?.toDouble() ?? 0.0;
          final statusMessage =
              jobStatus['status_message'] as String? ?? 'Processing...';

          debugPrint(
              '[DeepResearch] Job status: $status, progress: $progress, message: $statusMessage');

          if (status == 'completed') {
            // Job completed - fetch the session
            final sessionId = jobStatus['session_id'] as String?;
            if (sessionId != null) {
              final sessionData = await api.get('/research/sessions/$sessionId');
              final session = sessionData['session'] as Map<String, dynamic>?;
              final sourcesData = sessionData['sources'] as List<dynamic>? ?? [];

              final report = session?['report'] as String? ?? '';
              final sources = sourcesData
                  .map((s) => ResearchSource(
                        title: s['title'] ?? '',
                        url: s['url'] ?? '',
                        content: s['content'] ?? '',
                        snippet: s['snippet'],
                        credibility: _parseCredibility(s['credibility']),
                        credibilityScore: s['credibility_score'] ?? 60,
                      ))
                  .toList();

              yield DeepResearchUpdate(
                'Cloud research complete!',
                1.0,
                result: report,
                sources: sources,
              );

              // Refresh sessions
              ref.invalidate(researchSessionProvider);

              // Track gamification
              ref.read(gamificationProvider.notifier).trackDeepResearch();
              ref
                  .read(gamificationProvider.notifier)
                  .trackFeatureUsed('cloud_research');

              await overlayBubbleService.updateStatus('Research Complete! ✓',
                  progress: 100);
              await Future.delayed(const Duration(seconds: 2));
              await overlayBubbleService.hide();

              debugPrint(
                  '[DeepResearch] Cloud research complete, sessionId: $sessionId');
              return;
            }
          } else if (status == 'failed') {
            final error = jobStatus['error'] as String? ?? 'Unknown error';
            throw Exception('Research failed: $error');
          } else {
            // Still running - update progress
            final displayProgress = 0.2 + (progress * 0.7);
            yield DeepResearchUpdate(
              '[CLOUD] $statusMessage',
              displayProgress,
            );
            await overlayBubbleService.updateStatus(
              statusMessage,
              progress: (displayProgress * 100).toInt(),
            );
          }
        } catch (e) {
          debugPrint('[DeepResearch] Poll error: $e');
          // Continue polling on transient errors
          if (pollCount > 3) {
            // After a few retries, show error but keep polling
            yield DeepResearchUpdate(
              '[CLOUD] Checking status... (retry)',
              0.3,
            );
          }
        }
      }

      // Timeout - but research may still complete on server
      yield DeepResearchUpdate(
        'Research is taking longer than expected.\nCheck Research History later for results.',
        0.9,
      );
      await overlayBubbleService.updateStatus(
          'Research still running on server.\nCheck history later.',
          progress: 90);
      await Future.delayed(const Duration(seconds: 3));
      await overlayBubbleService.hide();
    } catch (e) {
      debugPrint('[DeepResearch] Cloud research error: $e');
      await overlayBubbleService.updateStatus('Error: $e');
      await Future.delayed(const Duration(seconds: 3));
      await overlayBubbleService.hide();
      rethrow;
    }
  }

  /// Start background research (returns immediately with job ID)
  Future<String> startBackgroundResearch(
    String query, {
    required String notebookId,
    ResearchDepth depth = ResearchDepth.standard,
    ResearchTemplate template = ResearchTemplate.general,
  }) async {
    final api = ref.read(apiServiceProvider);
    return await api.startBackgroundResearch(
      query: query,
      depth: depth.name,
      template: template.name,
      notebookId: notebookId.isNotEmpty ? notebookId : null,
    );
  }

  /// Check background research job status
  Future<Map<String, dynamic>?> checkBackgroundJob(String jobId) async {
    final api = ref.read(apiServiceProvider);
    return await api.getResearchJobStatus(jobId);
  }

  /// Get all pending background jobs
  Future<List<Map<String, dynamic>>> getPendingJobs() async {
    final api = ref.read(apiServiceProvider);
    return await api.getResearchJobs();
  }

  SourceCredibility _parseCredibility(String? value) {
    switch (value?.toLowerCase()) {
      case 'academic':
        return SourceCredibility.academic;
      case 'government':
        return SourceCredibility.government;
      case 'news':
        return SourceCredibility.news;
      case 'professional':
        return SourceCredibility.professional;
      case 'blog':
        return SourceCredibility.blog;
      default:
        return SourceCredibility.unknown;
    }
  }

  Future<List<String>> _generateSubQueries(String query,
      {TopicContextAnalysis? contextAnalysis,
      ResearchTemplate template = ResearchTemplate.general,
      int count = 5}) async {
    String contextPrompt = '';
    if (contextAnalysis != null) {
      contextPrompt = '''
Context Engineering Insights:
- Core Concepts: ${contextAnalysis.coreConcepts.join(', ')}
- Prerequisites: ${contextAnalysis.prerequisites.join(', ')}
- Complexity: ${contextAnalysis.complexityLevel}
- Related Tech: ${contextAnalysis.relatedTechnologies.join(', ')}

Use these insights to generate more targeted and technical search queries.
''';
    }

    String templateGuidance = '';
    switch (template) {
      case ResearchTemplate.academic:
        templateGuidance = '''
Focus on academic and scholarly aspects:
- Peer-reviewed research and studies
- Academic definitions and theories
- Research methodology
- Statistical data and findings
''';
        break;
      case ResearchTemplate.productComparison:
        templateGuidance = '''
Focus on comparison aspects:
- Feature comparisons
- Pricing information
- User reviews and ratings
- Alternatives and competitors
''';
        break;
      case ResearchTemplate.marketAnalysis:
        templateGuidance = '''
Focus on market aspects:
- Market size and growth
- Key players and competitors
- Industry trends
- Investment and funding news
''';
        break;
      case ResearchTemplate.howToGuide:
        templateGuidance = '''
Focus on practical guidance:
- Step-by-step tutorials
- Best practices
- Common mistakes
- Tips and tricks
''';
        break;
      case ResearchTemplate.prosAndCons:
        templateGuidance = '''
Focus on balanced analysis:
- Advantages and benefits
- Disadvantages and drawbacks
- User experiences
- Expert opinions
''';
        break;
      default:
        break;
    }

    final prompt = '''
You are an expert research strategist. Your task is to break down a research query into $count distinct search queries that will gather comprehensive, diverse information.

## RESEARCH QUERY
"$query"

$templateGuidance

## REQUIREMENTS
Generate search queries that cover different angles of the topic.
Make queries specific and searchable (like you would type into Google).

$contextPrompt

## OUTPUT FORMAT
Return ONLY the search queries, one per line. No numbering, bullets, or explanations.

Example output format:
what is machine learning and how does it work
machine learning real world applications examples
machine learning challenges and limitations 2024
''';

    try {
      final response =
          await _generateContent(prompt).timeout(const Duration(seconds: 60));
      final queries = response
          .split('\n')
          .map((line) => line.trim())
          .where((line) =>
              line.isNotEmpty &&
              !line.startsWith('#') &&
              !line.startsWith('-') &&
              !line.startsWith('*'))
          .take(count)
          .toList();

      if (queries.isEmpty) {
        return _getFallbackQueries(query);
      }
      return queries;
    } catch (e) {
      debugPrint('[DeepResearch] Sub-query generation timed out: $e');
      return _getFallbackQueries(query);
    }
  }

  List<String> _getFallbackQueries(String query) {
    return [
      query,
      '$query explained',
      '$query examples',
      '$query benefits and advantages',
      '$query challenges problems',
      '$query latest news 2024',
    ];
  }

  Future<List<String>> _searchImages(String query) async {
    try {
      final results = await _serperService
          .search(query, type: 'images', num: 5)
          .timeout(const Duration(seconds: 15));
      return results
          .where((r) => r.imageUrl != null)
          .map((r) => r.imageUrl!)
          .toList();
    } catch (e) {
      debugPrint('[DeepResearch] Image search timed out: $e');
      return [];
    }
  }

  Future<List<String>> _searchVideos(String query) async {
    try {
      final results = await _serperService
          .search(query, type: 'videos', num: 3)
          .timeout(const Duration(seconds: 15));
      return results.map((r) => r.link).toList();
    } catch (e) {
      debugPrint('[DeepResearch] Video search timed out: $e');
      return [];
    }
  }

  /// Stream the report generation for real-time updates
  Stream<String> _synthesizeReportStream(String query,
      List<ResearchSource> sources, List<String> images, List<String> videos,
      {TopicContextAnalysis? contextAnalysis,
      ResearchTemplate template = ResearchTemplate.general}) async* {
    final limitedSources = sources.take(12).toList();
    final prompt = _buildReportPrompt(query, limitedSources, images, videos,
        contextAnalysis: contextAnalysis, template: template);

    final provider = await _getSelectedProvider();
    final model = await _getSelectedModel();
    final contextWindow = await _getModelContextWindow(model);
    final maxOutputTokens = (contextWindow * 0.25).clamp(4096, 8192).toInt();

    debugPrint(
        '[DeepResearch] Streaming report with model: $model, maxTokens: $maxOutputTokens');

    if (provider == 'openrouter') {
      final apiKey = await _getOpenRouterKey();
      final result = await _openRouterService
          .generateContent(prompt,
              model: model, apiKey: apiKey, maxTokens: maxOutputTokens)
          .timeout(const Duration(minutes: 4));
      yield result;
    } else {
      final apiKey = await _getGeminiKey();
      yield* _geminiService.streamContent(
        prompt,
        model: model,
        apiKey: apiKey,
        maxTokens: maxOutputTokens,
      );
    }
  }

  /// Build the report prompt (extracted for reuse)
  String _buildReportPrompt(String query, List<ResearchSource> limitedSources,
      List<String> images, List<String> videos,
      {TopicContextAnalysis? contextAnalysis,
      ResearchTemplate template = ResearchTemplate.general}) {
    final sourcesText = limitedSources.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final s = entry.value;
      final contentPreview = s.content.length > 2500
          ? "${s.content.substring(0, 2500)}..."
          : s.content;
      final credLabel = s.credibility != SourceCredibility.unknown
          ? ' [${s.credibility.name.toUpperCase()} - ${s.credibilityScore}%]'
          : '';
      return '''
### Source $idx: ${s.title}$credLabel
**URL**: ${s.url}
**Summary**: ${s.snippet ?? 'No summary available'}
**Full Content**:
$contentPreview
''';
    }).join('\n---\n');

    final limitedImages = images.take(12).toList();
    final imagesText = limitedImages.isEmpty
        ? 'No images available'
        : limitedImages
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. ${e.value}')
            .join('\n');

    final limitedVideos = videos.take(6).toList();
    final videosText = limitedVideos.isEmpty
        ? 'No videos available'
        : limitedVideos
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. ${e.value}')
            .join('\n');

    String contextSection = '';
    if (contextAnalysis != null) {
      contextSection = '''
## Context Engineering Analysis
**Core Concepts**: ${contextAnalysis.coreConcepts.join(', ')}
**Prerequisites**: ${contextAnalysis.prerequisites.join(', ')}
**Complexity Level**: ${contextAnalysis.complexityLevel}
''';
    }

    // Get template-specific formatting
    final templatePrompt = _getTemplatePrompt(template);

    return '''
You are an expert research analyst creating a comprehensive research report.

## RESEARCH QUERY
"$query"

## YOUR TASK
Create a detailed research report covering all aspects of the topic.
Prioritize information from higher credibility sources (academic, government, news).

$templatePrompt

${templatePrompt.isEmpty ? '''
## DEFAULT STRUCTURE
1. Executive Summary
2. Introduction & Background  
3. Main Analysis (3-5 sections)
4. Key Findings & Insights
5. Practical Applications
6. Conclusion
7. Sources & References
''' : ''}

## FORMATTING
- Use markdown headers, bullet points, bold, italics
- Embed images: ![caption](URL)
- Cite sources: [Title](URL)
- Write COMPLETE report including conclusion and references
- Note source credibility when citing important claims

$contextSection

## IMAGES:
$imagesText

## VIDEOS:
$videosText

## SOURCES:
$sourcesText

---
Write the comprehensive research report:
''';
  }

  /// Generate continuation for truncated reports
  Future<String> _generateContinuation(
      String report,
      List<ResearchSource> sources,
      bool hasConclusion,
      bool hasReferences) async {
    final provider = await _getSelectedProvider();
    final model = await _getSelectedModel();

    final continuationPrompt = '''
Continue and complete this research report. Add:
${!hasConclusion ? '- A Conclusion section' : ''}
${!hasReferences ? '- A Sources & References section' : ''}

## AVAILABLE SOURCES:
${sources.take(12).map((s) => '- [${s.title}](${s.url})').join('\n')}

## REPORT SO FAR:
$report

---
Complete the report:
''';

    if (provider == 'openrouter') {
      final apiKey = await _getOpenRouterKey();
      return await _openRouterService
          .generateContent(continuationPrompt,
              model: model, apiKey: apiKey, maxTokens: 4096)
          .timeout(const Duration(minutes: 2));
    } else {
      final apiKey = await _getGeminiKey();
      return await _geminiService
          .generateContent(continuationPrompt,
              model: model, apiKey: apiKey, maxTokens: 4096)
          .timeout(const Duration(minutes: 2));
    }
  }
}

class DeepResearchUpdate {
  final String status;
  final double progress;
  final String? result;
  final List<ResearchSource>? sources;
  final List<String>? images;
  final List<String>? videos;
  final bool isStreaming;

  DeepResearchUpdate(this.status, this.progress,
      {this.result,
      this.sources,
      this.images,
      this.videos,
      this.isStreaming = false});
}

class ResearchSource {
  final String title;
  final String url;
  final String content;
  final String? snippet;
  final List<String>? imageUrls;
  final SourceCredibility credibility;
  final int credibilityScore;

  ResearchSource({
    required this.title,
    required this.url,
    required this.content,
    this.snippet,
    this.imageUrls,
    this.credibility = SourceCredibility.unknown,
    this.credibilityScore = 60,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'content': content,
        'snippet': snippet,
        'credibility': credibility.name,
        'credibilityScore': credibilityScore,
      };
}

/// Export service for research reports
class ResearchExportService {
  /// Generate markdown export
  static String toMarkdown(
      String query, String report, List<ResearchSource> sources) {
    final buffer = StringBuffer();
    buffer.writeln('# Research Report: $query');
    buffer.writeln('');
    buffer.writeln('*Generated on ${DateTime.now().toIso8601String()}*');
    buffer.writeln('');
    buffer.writeln(report);
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('');
    buffer.writeln('## Source Credibility Summary');
    buffer.writeln('');

    final grouped = <SourceCredibility, List<ResearchSource>>{};
    for (final source in sources) {
      grouped.putIfAbsent(source.credibility, () => []).add(source);
    }

    for (final entry in grouped.entries) {
      buffer.writeln(
          '### ${entry.key.name.toUpperCase()} Sources (${entry.value.length})');
      for (final source in entry.value) {
        buffer.writeln(
            '- [${source.title}](${source.url}) - ${source.credibilityScore}%');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Generate plain text export
  static String toPlainText(
      String query, String report, List<ResearchSource> sources) {
    final buffer = StringBuffer();
    buffer.writeln('RESEARCH REPORT: $query');
    buffer.writeln('=' * 50);
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    // Strip markdown formatting for plain text
    final plainReport = report
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'\1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'\1');

    buffer.writeln(plainReport);
    buffer.writeln('');
    buffer.writeln('-' * 50);
    buffer.writeln('SOURCES:');
    for (int i = 0; i < sources.length; i++) {
      buffer.writeln('${i + 1}. ${sources[i].title}');
      buffer.writeln('   URL: ${sources[i].url}');
      buffer.writeln(
          '   Credibility: ${sources[i].credibility.name} (${sources[i].credibilityScore}%)');
    }

    return buffer.toString();
  }

  /// Generate HTML export (for PDF conversion)
  static String toHtml(
      String query, String report, List<ResearchSource> sources) {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html><head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<title>Research Report: $query</title>');
    buffer.writeln('<style>');
    buffer.writeln(
        'body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }');
    buffer.writeln(
        'h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }');
    buffer.writeln('h2 { color: #555; }');
    buffer.writeln(
        '.source { background: #f5f5f5; padding: 10px; margin: 10px 0; border-radius: 5px; }');
    buffer.writeln(
        '.credibility { display: inline-block; padding: 2px 8px; border-radius: 3px; font-size: 12px; }');
    buffer.writeln('.academic { background: #28a745; color: white; }');
    buffer.writeln('.government { background: #007bff; color: white; }');
    buffer.writeln('.news { background: #17a2b8; color: white; }');
    buffer.writeln('.professional { background: #6c757d; color: white; }');
    buffer.writeln('.blog { background: #ffc107; color: black; }');
    buffer.writeln('.unknown { background: #e9ecef; color: black; }');
    buffer.writeln('</style>');
    buffer.writeln('</head><body>');
    buffer.writeln('<h1>Research Report: $query</h1>');
    buffer.writeln(
        '<p><em>Generated: ${DateTime.now().toIso8601String()}</em></p>');

    // Convert markdown to basic HTML
    final htmlReport = _markdownToHtml(report);
    buffer.writeln(htmlReport);

    buffer.writeln('<hr>');
    buffer.writeln('<h2>Sources</h2>');
    for (final source in sources) {
      buffer.writeln('<div class="source">');
      buffer.writeln(
          '<strong><a href="${source.url}">${source.title}</a></strong>');
      buffer.writeln(
          '<span class="credibility ${source.credibility.name}">${source.credibility.name.toUpperCase()} ${source.credibilityScore}%</span>');
      if (source.snippet != null) {
        buffer.writeln('<p>${source.snippet}</p>');
      }
      buffer.writeln('</div>');
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  static String _markdownToHtml(String markdown) {
    return markdown
        .replaceAllMapped(
            RegExp(r'^### (.+)$', multiLine: true), (m) => '<h3>${m[1]}</h3>')
        .replaceAllMapped(
            RegExp(r'^## (.+)$', multiLine: true), (m) => '<h2>${m[1]}</h2>')
        .replaceAllMapped(
            RegExp(r'^# (.+)$', multiLine: true), (m) => '<h1>${m[1]}</h1>')
        .replaceAllMapped(
            RegExp(r'\*\*([^*]+)\*\*'), (m) => '<strong>${m[1]}</strong>')
        .replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => '<em>${m[1]}</em>')
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
            (m) => '<a href="${m[2]}">${m[1]}</a>')
        .replaceAllMapped(
            RegExp(r'^- (.+)$', multiLine: true), (m) => '<li>${m[1]}</li>')
        .replaceAll('\n\n', '</p><p>')
        .replaceAll('\n', '<br>');
  }
}
