import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gemini_service.dart';
import 'openrouter_service.dart';
import 'context_engineering_service.dart';
import '../search/serper_service.dart';
import '../api/api_service.dart';
import '../security/global_credentials_service.dart';
import '../services/overlay_bubble_service.dart';
import '../../features/gamification/gamification_provider.dart';

final deepResearchServiceProvider = Provider<DeepResearchService>((ref) {
  final geminiService = GeminiService();
  final openRouterService = OpenRouterService();
  final serperService = SerperService(ref);
  return DeepResearchService(
      ref, geminiService, openRouterService, serperService);
});

class DeepResearchService {
  final Ref ref;
  final GeminiService _geminiService;
  final OpenRouterService _openRouterService;
  final SerperService _serperService;
  final ContextEngineeringService _contextEngineeringService;

  DeepResearchService(this.ref, this._geminiService, this._openRouterService,
      this._serperService)
      : _contextEngineeringService =
            ref.read(contextEngineeringServiceProvider);

  Future<String> _getSelectedProvider() async {
    // These should ideally come from a settings provider, but for now we'll keep it simple
    // or hardcode to Gemini since we are aiming for Gemini-first
    return 'gemini';
  }

  Future<String> _getSelectedModel() async {
    return 'gemini-1.5-flash';
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

  Stream<DeepResearchUpdate> research(String query,
      {required String notebookId, bool useContextEngineering = false}) async* {
    try {
      yield DeepResearchUpdate('Analyzing query...', 0.1);
      await overlayBubbleService.show(status: 'Analyzing query...');

      // 0. Context Engineering Analysis (if enabled)
      TopicContextAnalysis? contextAnalysis;
      if (useContextEngineering) {
        yield DeepResearchUpdate(
            'Context Agent: Analyzing topic depth...', 0.15);
        await overlayBubbleService.updateStatus('Analyzing context...',
            progress: 15);
        try {
          // Add 90 second timeout to prevent infinite loops
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

      // 1. Generate sub-queries
      List<String> subQueries;
      try {
        subQueries =
            await _generateSubQueries(query, contextAnalysis: contextAnalysis);
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

      // 2. Search and scrape
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
        final progress = 0.2 + (0.5 * (completed / subQueries.length));
        yield DeepResearchUpdate('Searching: "$subQuery"...', progress,
            sources: List.from(results));

        await overlayBubbleService.updateStatus(
          'Searching: "$subQuery"',
          progress: (progress * 100).toInt(),
        );

        try {
          // Search web
          final items = await _serperService.search(subQuery, num: 5);
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
            try {
              final content = await _serperService.fetchPageContent(item.link);
              // Use snippet as minimum viable content if fetch fails or returns too little
              final actualContent = content.length > 200
                  ? content
                  : '${item.snippet}\n\nNote: Full page content unavailable (likely CORS restriction in browser)';

              // Always add the source if we have at least a snippet
              if (item.snippet.isNotEmpty) {
                results.add(ResearchSource(
                  title: item.title,
                  url: item.link,
                  content: actualContent,
                  snippet: item.snippet,
                ));
                contentFetched++;
              }
            } catch (e) {
              debugPrint(
                  '[DeepResearch] Failed to fetch content from ${item.link}: $e');
              // Still add using snippet as fallback
              if (item.snippet.isNotEmpty) {
                results.add(ResearchSource(
                  title: item.title,
                  url: item.link,
                  content: item.snippet,
                  snippet: item.snippet,
                ));
                contentFetched++;
              }
            }
          }
          debugPrint(
              '[DeepResearch] Fetched content from $contentFetched/${items.length} pages');

          // Yield update with newly found sources from this sub-query
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

      // Deduplicate images
      final uniqueImages = allImages.toSet().toList();
      final uniqueVideos = allVideos.toSet().toList();
      debugPrint('[DeepResearch] Total unique images: ${uniqueImages.length}');
      debugPrint('[DeepResearch] Total unique videos: ${uniqueVideos.length}');

      yield DeepResearchUpdate('Synthesizing comprehensive report...', 0.8,
          images: uniqueImages, videos: uniqueVideos);
      await overlayBubbleService.updateStatus('Writing report...',
          progress: 80);

      // 3. Synthesize report
      String report;
      try {
        report = await _synthesizeReport(
            query, results, uniqueImages, uniqueVideos,
            contextAnalysis: contextAnalysis);
        debugPrint(
            '[DeepResearch] Report generated successfully (${report.length} chars)');

        if (report.isEmpty) {
          throw Exception(
              'AI generated an empty report. Please check your AI API keys.');
        }
      } catch (e) {
        debugPrint('[DeepResearch] Error synthesizing report: $e');
        throw Exception('Failed to generate report: $e\n'
            'Please check your AI API keys (Gemini or OpenRouter).');
      }

      yield DeepResearchUpdate('Research complete!', 1.0,
          result: report,
          sources: results,
          images: uniqueImages,
          videos: uniqueVideos);

      // 4. Save to backend
      try {
        final api = ref.read(apiServiceProvider);
        await api.saveResearchSession(
          notebookId: notebookId,
          query: query,
          report: report,
          sources: results
              .map((s) => {
                    'title': s.title,
                    'url': s.url,
                    'content': s.content,
                    'snippet': s.snippet,
                  })
              .toList(),
        );
      } catch (e) {
        debugPrint('[DeepResearch] Failed to save research session: $e');
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

  Future<List<String>> _generateSubQueries(String query,
      {TopicContextAnalysis? contextAnalysis}) async {
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

    final prompt = '''
You are an expert research strategist. Your task is to break down a research query into 5-7 distinct search queries that will gather comprehensive, diverse information.

## RESEARCH QUERY
"$query"

## REQUIREMENTS
Generate search queries that cover:
1. **Definition/Overview**: What is it? Basic explanation
2. **How it works**: Mechanisms, processes, technical details
3. **Benefits/Advantages**: Why it matters, positive aspects
4. **Challenges/Limitations**: Problems, criticisms, drawbacks
5. **Real examples/Case studies**: Practical applications, success stories
6. **Latest developments**: Recent news, trends, updates (add "2024" or "latest")
7. **Expert opinions**: What experts say, research findings

$contextPrompt

## OUTPUT FORMAT
Return ONLY the search queries, one per line. No numbering, bullets, or explanations.
Make queries specific and searchable (like you would type into Google).

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
          .take(7)
          .toList();

      // Ensure we have at least some queries
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

  Future<String> _synthesizeReport(String query, List<ResearchSource> sources,
      List<String> images, List<String> videos,
      {TopicContextAnalysis? contextAnalysis}) async {
    // Limit sources to top 12 for comprehensive coverage
    final limitedSources = sources.take(12).toList();

    // Increase content size per source for better context (2500 chars)
    final sourcesText = limitedSources.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final s = entry.value;
      final contentPreview = s.content.length > 2500
          ? "${s.content.substring(0, 2500)}..."
          : s.content;
      return '''
### Source $idx: ${s.title}
**URL**: ${s.url}
**Summary**: ${s.snippet ?? 'No summary available'}
**Full Content**:
$contentPreview
''';
    }).join('\n---\n');

    // Include more images for visual richness
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
The following context has been engineered for this topic:

**Core Concepts**: ${contextAnalysis.coreConcepts.join(', ')}
**Prerequisites**: ${contextAnalysis.prerequisites.join(', ')}
**Complexity Level**: ${contextAnalysis.complexityLevel}

**Learning Path**:
${contextAnalysis.learningPath.map((p) => "- $p").join('\n')}

**Common Pitfalls**:
${contextAnalysis.commonPitfalls.map((p) => "- $p").join('\n')}

**Industry Standards**:
${contextAnalysis.industryStandards.map((p) => "- $p").join('\n')}

**Key Thought Leaders**:
${contextAnalysis.keyThoughtLeaders.map((p) => "- $p").join('\n')}

**Seminal Works**:
${contextAnalysis.seminalWorks.map((p) => "- $p").join('\n')}

**Practical Applications**:
${contextAnalysis.practicalApplications.map((p) => "- $p").join('\n')}

**Controversies & Debates**:
${contextAnalysis.controversies.map((p) => "- $p").join('\n')}

**Tools & Ecosystem**:
${contextAnalysis.toolsAndEcosystem.map((p) => "- $p").join('\n')}

${contextAnalysis.mindmap != null ? '## Mindmap\n```mermaid\n${contextAnalysis.mindmap}\n```' : ''}

Please integrate these insights into the final report structure, ensuring the report addresses the learning path, prerequisites, and practical applications.
''';
    }

    final prompt = '''
You are an expert research analyst creating a comprehensive, publication-quality research report. Your report should be thorough, well-organized, and provide genuine value to the reader.

## RESEARCH QUERY
"$query"

## YOUR TASK
Create a detailed, in-depth research report that thoroughly answers the query. The report should be at least 2000-3000 words and cover all aspects of the topic.

## REQUIRED STRUCTURE

### 1. Executive Summary (2-3 paragraphs)
- Provide a high-level overview of the key findings
- Highlight the most important insights
- State the main conclusions

### 2. Introduction & Background
- Define key terms and concepts
- Provide historical context if relevant
- Explain why this topic matters

### 3. Main Analysis (Multiple Sections)
Create 3-5 detailed sections covering different aspects of the topic:
- Each section should have a clear heading
- Include specific facts, statistics, and examples
- Explain mechanisms, processes, or relationships
- Compare different perspectives or approaches

### 4. Key Findings & Insights
- Summarize the most important discoveries
- Highlight patterns or trends
- Note any surprising or counterintuitive findings

### 5. Practical Applications / Implications
- How can this information be applied?
- What are the real-world implications?
- Include actionable recommendations if applicable

### 6. Conclusion
- Synthesize the main points
- Provide final thoughts
- Suggest areas for further research

### 7. Sources & References
- List all sources used with links

## FORMATTING REQUIREMENTS
1. **Rich Markdown**: Use headers (##, ###), bullet points, numbered lists, bold, and italics
2. **Images**: Embed 2-4 relevant images using: ![Descriptive caption](URL)
3. **Videos**: Embed 1-2 relevant videos using: ![VIDEO: Description](URL)
4. **Citations**: Cite sources inline using [Source Title](URL) format
5. **Tables**: Use markdown tables where data comparison is helpful
6. **Code blocks**: Use code blocks for any technical content if applicable

## QUALITY STANDARDS
- Be comprehensive and thorough - don't be superficial
- Provide specific details, not vague generalities
- Include real examples and case studies from the sources
- Explain complex concepts clearly
- Maintain objectivity and present multiple viewpoints
- Ensure logical flow between sections

$contextSection

## AVAILABLE MEDIA

### Images (embed 2-4 of these):
$imagesText

### Videos (embed 1-2 of these):
$videosText

## SOURCE MATERIAL
Use the following sources to create your report. Cite them appropriately:

$sourcesText

---
Now write the comprehensive research report:
''';

    debugPrint(
        '[DeepResearch] Generating report with ${limitedSources.length} sources and ${limitedImages.length} images');

    // Use maximum token limits for comprehensive reports - with timeout
    final provider = await _getSelectedProvider();
    final model = await _getSelectedModel();

    try {
      if (provider == 'openrouter') {
        final apiKey = await _getOpenRouterKey();
        return await _openRouterService
            .generateContent(prompt,
                model: model, apiKey: apiKey, maxTokens: 16384)
            .timeout(const Duration(minutes: 3));
      } else {
        final apiKey = await _getGeminiKey();
        return await _geminiService
            .generateContent(prompt,
                model: model, apiKey: apiKey, maxTokens: 32768)
            .timeout(const Duration(minutes: 3));
      }
    } catch (e) {
      debugPrint('[DeepResearch] Report synthesis timed out: $e');
      // Return a basic report if synthesis times out
      return '''
# Research Summary: $query

## Sources Found
${limitedSources.take(5).map((s) => '- [${s.title}](${s.url})').join('\n')}

## Key Information
${limitedSources.take(3).map((s) => '### ${s.title}\n${s.snippet ?? s.content.substring(0, 500.clamp(0, s.content.length))}').join('\n\n')}

*Note: Full report generation timed out. Above is a summary of found sources.*
''';
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

  DeepResearchUpdate(this.status, this.progress,
      {this.result, this.sources, this.images, this.videos});
}

class ResearchSource {
  final String title;
  final String url;
  final String content;
  final String? snippet;
  final List<String>? imageUrls;

  ResearchSource(
      {required this.title,
      required this.url,
      required this.content,
      this.snippet,
      this.imageUrls});
}
