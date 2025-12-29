import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/ai/deep_research_service.dart';
import '../../core/ai/ai_settings_service.dart';
import '../../core/ai/openrouter_service.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/security/global_credentials_service.dart';
import 'prediction.dart';
import 'team_logo_service.dart';

final sportsPredictorProvider =
    StateNotifierProvider<SportsPredictorNotifier, SportsPredictorState>((ref) {
  return SportsPredictorNotifier(ref);
});

class SportsPredictorState {
  final List<SportsPrediction> predictions;
  final bool isLoading;
  final String? error;
  final String? currentStatus;
  final double progress;
  final List<String> researchSources;

  SportsPredictorState({
    this.predictions = const [],
    this.isLoading = false,
    this.error,
    this.currentStatus,
    this.progress = 0,
    this.researchSources = const [],
  });

  SportsPredictorState copyWith({
    List<SportsPrediction>? predictions,
    bool? isLoading,
    String? error,
    String? currentStatus,
    double? progress,
    List<String>? researchSources,
  }) {
    return SportsPredictorState(
      predictions: predictions ?? this.predictions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentStatus: currentStatus ?? this.currentStatus,
      progress: progress ?? this.progress,
      researchSources: researchSources ?? this.researchSources,
    );
  }
}

class SportsPredictorNotifier extends StateNotifier<SportsPredictorState> {
  final Ref ref;
  final _uuid = const Uuid();

  SportsPredictorNotifier(this.ref) : super(SportsPredictorState());

  Future<void> generatePredictions({
    required SportType sport,
    String? league,
    String? specificMatch,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      currentStatus: 'Starting deep research...',
      progress: 0.1,
      researchSources: [],
    );

    try {
      final deepResearch = ref.read(deepResearchServiceProvider);

      // Build search query
      final query = _buildSearchQuery(sport, league, specificMatch);

      state = state.copyWith(
        currentStatus: 'Searching for upcoming matches and odds...',
        progress: 0.2,
      );

      // Use deep research to gather information
      final sources = <PredictionSource>[];
      String researchReport = '';

      await for (final update in deepResearch.research(
        query,
        notebookId: '',
        depth: ResearchDepth.standard,
        template: ResearchTemplate.general,
      )) {
        state = state.copyWith(
          currentStatus: update.status,
          progress: update.progress * 0.6, // 60% for research
          researchSources: update.sources?.map((s) => s.title).toList() ?? [],
        );

        if (update.result != null) {
          researchReport = update.result!;
          sources.addAll(update.sources?.map((s) => PredictionSource(
                    title: s.title,
                    url: s.url,
                    snippet: s.snippet ?? '',
                  )) ??
              []);
        }
      }

      state = state.copyWith(
        currentStatus: 'Analyzing data and generating predictions...',
        progress: 0.7,
      );

      // Generate predictions from research
      var predictions = await _generatePredictionsFromResearch(
        sport: sport,
        league: league,
        researchReport: researchReport,
        sources: sources,
      );

      state = state.copyWith(
        currentStatus: 'Fetching team logos...',
        progress: 0.9,
      );

      // Fetch team logos
      predictions = await _fetchTeamLogos(predictions, sport.displayName);

      state = state.copyWith(
        predictions: predictions,
        isLoading: false,
        currentStatus: 'Predictions ready!',
        progress: 1.0,
      );
    } catch (e) {
      debugPrint('[SportsPredictor] Error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        currentStatus: null,
      );
    }
  }

  String _buildSearchQuery(
      SportType sport, String? league, String? specificMatch) {
    final buffer = StringBuffer();
    buffer.write('${sport.displayName} predictions odds betting analysis ');

    if (specificMatch != null && specificMatch.isNotEmpty) {
      buffer.write('$specificMatch match prediction ');
    } else if (league != null && league.isNotEmpty) {
      buffer.write('$league upcoming matches predictions ');
    } else {
      buffer.write('upcoming matches this week predictions ');
    }

    buffer.write('team form statistics head to head recent results');
    return buffer.toString();
  }

  Future<List<SportsPrediction>> _generatePredictionsFromResearch({
    required SportType sport,
    String? league,
    required String researchReport,
    required List<PredictionSource> sources,
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
You are a sports analyst AI. Based on the following research about ${sport.displayName}${league != null ? ' ($league)' : ''}, extract and analyze upcoming matches to generate predictions.

## RESEARCH DATA
$researchReport

## TASK
Extract upcoming matches from the research and generate predictions with odds for each match.

## OUTPUT FORMAT
Return a valid JSON array of predictions. Each prediction should have:
- homeTeam: string
- awayTeam: string  
- league: string
- matchDate: ISO date string (estimate if not exact)
- odds: { homeWin: number, draw: number, awayWin: number, over25?: number, under25?: number, btts?: number }
- analysis: string (2-3 sentences explaining the prediction)
- keyFactors: string[] (3-5 key factors)
- confidence: number (0.0 to 1.0)

## IMPORTANT
- Odds should be in decimal format (e.g., 1.85, 2.10, 3.50)
- Lower odds = more likely outcome
- Be realistic with confidence scores
- If no specific matches found, create predictions based on top teams mentioned

Return ONLY the JSON array, no other text:
''';

    String response;
    if (provider == 'openrouter') {
      final service = OpenRouterService(apiKey: apiKey);
      response = await service.generateContent(prompt, model: model);
    } else {
      final service = GeminiService(apiKey: apiKey);
      response = await service.generateContent(prompt, model: model);
    }

    // Parse JSON response
    try {
      // Extract JSON from response
      String jsonStr = response;
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }

      final List<dynamic> parsed = jsonDecode(jsonStr);
      return parsed.map((p) {
        final map = p as Map<String, dynamic>;
        return SportsPrediction(
          id: _uuid.v4(),
          sport: sport.displayName,
          league: map['league'] ?? league ?? 'Unknown',
          homeTeam: map['homeTeam'] ?? 'Team A',
          awayTeam: map['awayTeam'] ?? 'Team B',
          matchDate: DateTime.tryParse(map['matchDate'] ?? '') ??
              DateTime.now().add(const Duration(days: 1)),
          odds: PredictionOdds.fromJson(map['odds'] ?? {}),
          analysis: map['analysis'] ?? 'Analysis pending',
          keyFactors: List<String>.from(map['keyFactors'] ?? []),
          confidence: (map['confidence'] ?? 0.5).toDouble(),
          sources: sources,
        );
      }).toList();
    } catch (e) {
      debugPrint('[SportsPredictor] JSON parse error: $e');
      debugPrint('[SportsPredictor] Response was: $response');

      // Return a placeholder prediction if parsing fails
      return [
        SportsPrediction(
          id: _uuid.v4(),
          sport: sport.displayName,
          league: league ?? 'General',
          homeTeam: 'Research Complete',
          awayTeam: 'See Analysis',
          matchDate: DateTime.now(),
          odds: PredictionOdds(homeWin: 2.0, draw: 3.0, awayWin: 2.5),
          analysis: researchReport.length > 500
              ? '${researchReport.substring(0, 500)}...'
              : researchReport,
          keyFactors: ['Research completed', 'Manual analysis recommended'],
          confidence: 0.5,
          sources: sources,
        ),
      ];
    }
  }

  void clearPredictions() {
    state = SportsPredictorState();
  }

  Future<List<SportsPrediction>> _fetchTeamLogos(
    List<SportsPrediction> predictions,
    String sport,
  ) async {
    final updatedPredictions = <SportsPrediction>[];

    for (final prediction in predictions) {
      try {
        // Fetch logos in parallel
        final results = await Future.wait([
          TeamLogoService.getTeamLogo(prediction.homeTeam, sport),
          TeamLogoService.getTeamLogo(prediction.awayTeam, sport),
        ]);

        updatedPredictions.add(prediction.copyWith(
          homeTeamLogo: results[0],
          awayTeamLogo: results[1],
        ));
      } catch (e) {
        debugPrint('[SportsPredictor] Failed to fetch logos: $e');
        updatedPredictions.add(prediction);
      }
    }

    return updatedPredictions;
  }
}
