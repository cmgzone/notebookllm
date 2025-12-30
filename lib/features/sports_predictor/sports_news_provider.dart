import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ai/deep_research_service.dart';
import '../../core/ai/ai_settings_service.dart';
import '../../core/ai/openrouter_service.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/security/global_credentials_service.dart';
import 'sports_news.dart';

final sportsNewsProvider =
    StateNotifierProvider<SportsNewsNotifier, SportsNewsState>((ref) {
  return SportsNewsNotifier(ref);
});

class SportsNewsState {
  final List<SportsNews> news;
  final bool isLoading;
  final String? error;
  final String? currentStatus;
  final double progress;
  final NewsCategory selectedCategory;

  SportsNewsState({
    this.news = const [],
    this.isLoading = false,
    this.error,
    this.currentStatus,
    this.progress = 0,
    this.selectedCategory = NewsCategory.all,
  });

  SportsNewsState copyWith({
    List<SportsNews>? news,
    bool? isLoading,
    String? error,
    String? currentStatus,
    double? progress,
    NewsCategory? selectedCategory,
  }) {
    return SportsNewsState(
      news: news ?? this.news,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentStatus: currentStatus ?? this.currentStatus,
      progress: progress ?? this.progress,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  List<SportsNews> get filteredNews {
    if (selectedCategory == NewsCategory.all) return news;
    return news
        .where((n) =>
            n.category.toLowerCase() ==
                selectedCategory.displayName.toLowerCase() ||
            n.tags.any((t) => t
                .toLowerCase()
                .contains(selectedCategory.displayName.toLowerCase())))
        .toList();
  }
}

class SportsNewsNotifier extends StateNotifier<SportsNewsState> {
  final Ref ref;

  SportsNewsNotifier(this.ref) : super(SportsNewsState());

  void setCategory(NewsCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  Future<void> fetchNews({NewsCategory? category}) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      currentStatus: 'Searching for latest sports news...',
      progress: 0.1,
    );

    try {
      final deepResearch = ref.read(deepResearchServiceProvider);
      final cat = category ?? state.selectedCategory;

      // Build search query based on category
      final query = _buildNewsQuery(cat);

      state = state.copyWith(
        currentStatus: 'Gathering news from multiple sources...',
        progress: 0.2,
      );

      // Use deep research to gather news
      String researchReport = '';
      final sources = <Map<String, String>>[];
      final images = <String>[];
      final videos = <String>[];

      await for (final update in deepResearch.research(
        query: query,
        notebookId: '',
        depth: ResearchDepth.standard, // Use standard for more images/videos
        template: ResearchTemplate.general,
      )) {
        state = state.copyWith(
          currentStatus: update.status,
          progress: update.progress * 0.6,
        );

        if (update.result != null) {
          researchReport = update.result!;
        }

        // Collect sources
        for (final source in update.sources ?? []) {
          sources.add({
            'title': source.title,
            'url': source.url,
            'snippet': source.snippet ?? '',
          });
        }

        // Collect images
        if (update.images != null) {
          for (final img in update.images!) {
            if (!images.contains(img)) images.add(img);
          }
        }

        // Collect videos
        if (update.videos != null) {
          for (final vid in update.videos!) {
            if (!videos.contains(vid)) videos.add(vid);
          }
        }
      }

      state = state.copyWith(
        currentStatus: 'AI is generating news articles...',
        progress: 0.7,
      );

      // Generate structured news from research
      final newsArticles = await _generateNewsFromResearch(
        researchReport: researchReport,
        sources: sources,
        category: cat,
        images: images,
        videos: videos,
      );

      state = state.copyWith(
        news: newsArticles,
        isLoading: false,
        currentStatus: 'News loaded!',
        progress: 1.0,
        selectedCategory: cat,
      );
    } catch (e) {
      debugPrint('[SportsNews] Error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        currentStatus: null,
      );
    }
  }

  String _buildNewsQuery(NewsCategory category) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    switch (category) {
      case NewsCategory.football:
        return 'latest football soccer news today $dateStr Premier League La Liga Champions League transfers injuries';
      case NewsCategory.basketball:
        return 'latest NBA basketball news today $dateStr scores trades injuries highlights';
      case NewsCategory.tennis:
        return 'latest tennis news today $dateStr ATP WTA Grand Slam rankings';
      case NewsCategory.formula1:
        return 'latest Formula 1 F1 news today $dateStr race results standings drivers';
      case NewsCategory.mma:
        return 'latest UFC MMA news today $dateStr fights results rankings';
      case NewsCategory.transfers:
        return 'latest sports transfer news today $dateStr football basketball signings rumors';
      case NewsCategory.injuries:
        return 'latest sports injury news today $dateStr football basketball tennis updates';
      case NewsCategory.results:
        return 'latest sports results scores today $dateStr football basketball tennis';
      case NewsCategory.all:
        return 'latest breaking sports news today $dateStr football basketball tennis F1 UFC';
    }
  }

  Future<List<SportsNews>> _generateNewsFromResearch({
    required String researchReport,
    required List<Map<String, String>> sources,
    required NewsCategory category,
    List<String>? images,
    List<String>? videos,
  }) async {
    final settings = await AISettingsService.getSettings();
    final provider = settings.provider;
    final model = settings.getEffectiveModel();

    final creds = ref.read(globalCredentialsServiceProvider);
    String? apiKey;

    if (provider == 'openrouter') {
      apiKey = await creds.getApiKey('openrouter');
    } else {
      apiKey = await creds.getApiKey('gemini');
    }

    final prompt = '''
You are a sports news editor. Based on the following research data, create engaging news articles.

## RESEARCH DATA
$researchReport

## SOURCES
${sources.map((s) => '- ${s['title']}: ${s['snippet']}').join('\n')}

## AVAILABLE IMAGES
${images?.take(10).join('\n') ?? 'None'}

## AVAILABLE VIDEOS
${videos?.take(5).join('\n') ?? 'None'}

## TASK
Generate 6-8 sports news articles from the research. Each article should be unique and engaging.
Assign relevant images and videos to articles where appropriate.

## OUTPUT FORMAT
Return a valid JSON array. Each article should have:
- title: string (catchy headline, max 80 chars)
- summary: string (2-3 sentences, engaging summary)
- content: string (full article, 3-4 paragraphs)
- category: string (Football, Basketball, Tennis, Formula 1, MMA, Transfers, Injuries, Results)
- imageUrl: string or null (main image from available images)
- images: string[] (additional images, max 3)
- videoUrl: string or null (YouTube/video URL if relevant)
- videoThumbnail: string or null
- source: string (news source name)
- sourceUrl: string (URL)
- publishedAt: ISO date string
- tags: string[] (3-5 relevant tags)
- importance: string (breaking, high, normal, low)

## GUIDELINES
- Make headlines catchy and engaging
- Include specific names, teams, scores where available
- Vary the importance levels
- Use current date for publishedAt
- Be factual based on the research
- Assign images that match the article topic
- Include video URLs for highlight/match related articles

Return ONLY the JSON array:
''';

    String response;
    if (provider == 'openrouter') {
      final service = OpenRouterService(apiKey: apiKey);
      response = await service.generateContent(prompt, model: model);
    } else {
      final service = GeminiService(apiKey: apiKey);
      response = await service.generateContent(prompt, model: model);
    }

    try {
      String jsonStr = response;
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }

      final List<dynamic> parsed = jsonDecode(jsonStr);
      return parsed
          .map((p) => SportsNews.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SportsNews] JSON parse error: $e');
      // Return placeholder news
      return [
        SportsNews(
          id: '1',
          title: 'Latest Sports Updates',
          summary: researchReport.length > 200
              ? researchReport.substring(0, 200)
              : researchReport,
          content: researchReport,
          category: category.displayName,
          source: 'AI Research',
          sourceUrl: '',
          publishedAt: DateTime.now(),
          importance: NewsImportance.normal,
          images: images?.take(3).toList() ?? [],
          videoUrl: videos?.isNotEmpty == true ? videos!.first : null,
        ),
      ];
    }
  }

  void clearNews() {
    state = SportsNewsState();
  }
}
