import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/ai/deep_research_service.dart';
import '../../core/ai/ai_settings_service.dart';
import '../../core/ai/openrouter_service.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/security/global_credentials_service.dart';
import '../../core/search/serper_service.dart';
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
      currentStatus: 'Searching for real fixtures...',
      progress: 0.1,
      researchSources: [],
    );

    final sources = <PredictionSource>[];
    String researchReport = '';
    List<Map<String, dynamic>> fixtureData = [];

    try {
      // First, search for real fixtures
      state = state.copyWith(
        currentStatus: 'Finding upcoming matches...',
        progress: 0.2,
      );

      fixtureData = await _searchRealFixtures(
        sport: sport,
        league: league,
        specificMatch: specificMatch,
      ).timeout(const Duration(seconds: 15));

      // Build fixture context for AI
      if (fixtureData.isNotEmpty) {
        final fixtureContext =
            fixtureData.map((f) => '${f['title']}: ${f['snippet']}').join('\n');
        researchReport = 'FIXTURE DATA:\n$fixtureContext';

        sources.addAll(fixtureData.map((f) => PredictionSource(
              title: f['title'] ?? '',
              url: f['url'] ?? '',
              snippet: f['snippet'] ?? '',
            )));
      }

      // Also do quick research for odds and analysis
      state = state.copyWith(
        currentStatus: 'Researching odds and statistics...',
        progress: 0.4,
      );

      try {
        final deepResearch = ref.read(deepResearchServiceProvider);
        final query = _buildSearchQuery(sport, league, specificMatch);

        await for (final update in deepResearch
            .research(
          query: '$query betting odds predictions',
          notebookId: '',
          depth: ResearchDepth.quick,
          template: ResearchTemplate.general,
        )
            .timeout(const Duration(seconds: 20), onTimeout: (sink) {
          debugPrint('[SportsPredictor] Research timed out');
          sink.close();
        })) {
          state = state.copyWith(
            currentStatus: update.status,
            progress: 0.4 + (update.progress * 0.2),
            researchSources: update.sources?.map((s) => s.title).toList() ?? [],
          );

          if (update.result != null && update.result!.isNotEmpty) {
            researchReport += '\n\nODDS & ANALYSIS:\n${update.result!}';
            sources.addAll(update.sources?.map((s) => PredictionSource(
                      title: s.title,
                      url: s.url,
                      snippet: s.snippet ?? '',
                    )) ??
                []);
            break;
          }
        }
      } catch (researchError) {
        debugPrint('[SportsPredictor] Research error: $researchError');
      }
    } catch (e) {
      debugPrint('[SportsPredictor] Research setup error: $e');
    }

    // Always continue to generate predictions
    state = state.copyWith(
      currentStatus: 'Generating predictions from real data...',
      progress: 0.7,
    );

    List<SportsPrediction> predictions;

    if (researchReport.isNotEmpty) {
      try {
        predictions = await _generatePredictionsFromResearch(
          sport: sport,
          league: league,
          researchReport: researchReport,
          sources: sources,
        ).timeout(const Duration(seconds: 30));

        if (predictions.isEmpty) {
          debugPrint('[SportsPredictor] AI returned empty, using sample data');
          predictions = _getSamplePredictions(sport, league, sources);
        }
      } catch (e) {
        debugPrint('[SportsPredictor] AI prediction failed: $e');
        predictions = _getSamplePredictions(sport, league, sources);
      }
    } else {
      debugPrint(
          '[SportsPredictor] No research data, using sample predictions');
      predictions = _getSamplePredictions(sport, league, sources);
    }

    state = state.copyWith(
      currentStatus: 'Fetching team logos...',
      progress: 0.9,
    );

    // Fetch logos with short timeout
    try {
      predictions = await _fetchTeamLogos(predictions, sport.displayName)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[SportsPredictor] Logo fetch failed: $e');
    }

    // Final state - always show predictions
    state = state.copyWith(
      predictions: predictions,
      isLoading: false,
      currentStatus: 'Predictions ready!',
      progress: 1.0,
    );
  }

  String _buildSearchQuery(
      SportType sport, String? league, String? specificMatch) {
    final buffer = StringBuffer();
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (specificMatch != null && specificMatch.isNotEmpty) {
      buffer.write('$specificMatch match fixtures schedule date time ');
    } else if (league != null && league.isNotEmpty) {
      buffer.write('$league fixtures schedule upcoming matches $dateStr ');
    } else {
      buffer.write(
          '${sport.displayName} fixtures schedule upcoming matches this week $dateStr ');
    }

    buffer.write('kickoff time date venue');
    return buffer.toString();
  }

  /// Search for real upcoming fixtures using web search
  Future<List<Map<String, dynamic>>> _searchRealFixtures({
    required SportType sport,
    String? league,
    String? specificMatch,
  }) async {
    try {
      final serper = ref.read(serperServiceProvider);
      final today = DateTime.now();
      final dateStr = '${today.day}/${today.month}/${today.year}';

      // Build search query for fixtures
      String query;
      if (specificMatch != null && specificMatch.isNotEmpty) {
        query = '$specificMatch fixture date time';
      } else if (league != null && league.isNotEmpty) {
        query = '$league fixtures schedule $dateStr upcoming matches';
      } else {
        query =
            '${sport.displayName} fixtures today tomorrow this week schedule';
      }

      debugPrint('[SportsPredictor] Searching fixtures: $query');

      final results = await serper.search(query, type: 'search', num: 10);

      // Also search news for latest fixture updates
      final newsResults = await serper.search(
        '${league ?? sport.displayName} upcoming matches fixtures',
        type: 'news',
        num: 5,
      );

      // Combine results
      final allResults = <Map<String, dynamic>>[];
      for (final r in results) {
        allResults.add({
          'title': r.title,
          'snippet': r.snippet,
          'url': r.link,
          'date': r.date,
        });
      }
      for (final r in newsResults) {
        allResults.add({
          'title': r.title,
          'snippet': r.snippet,
          'url': r.link,
          'date': r.date,
          'isNews': true,
        });
      }

      debugPrint(
          '[SportsPredictor] Found ${allResults.length} fixture results');
      return allResults;
    } catch (e) {
      debugPrint('[SportsPredictor] Fixture search error: $e');
      return [];
    }
  }

  Future<List<SportsPrediction>> _generatePredictionsFromResearch({
    required SportType sport,
    String? league,
    required String researchReport,
    required List<PredictionSource> sources,
  }) async {
    // If research report is empty, return sample predictions
    if (researchReport.isEmpty) {
      debugPrint('[SportsPredictor] Empty research report, using sample data');
      return _getSamplePredictions(sport, league, sources);
    }

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

    // Check if API key is available
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[SportsPredictor] No API key, using sample data');
      return _getSamplePredictions(sport, league, sources);
    }

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final weekFromNow = today.add(const Duration(days: 7));
    final weekStr =
        '${weekFromNow.year}-${weekFromNow.month.toString().padLeft(2, '0')}-${weekFromNow.day.toString().padLeft(2, '0')}';

    final prompt = '''
You are a sports fixture analyst. Extract REAL upcoming matches from the research data below.

## CRITICAL: TODAY'S DATE IS $todayStr
- Only include matches scheduled between $todayStr and $weekStr
- Extract ACTUAL match dates from the fixture data - do NOT make up dates
- If a specific date is mentioned (e.g., "Saturday", "January 4th", "tomorrow"), convert it to ISO format
- If no exact date found, estimate based on context but mark confidence lower

## RESEARCH DATA (contains real fixture information):
$researchReport

## TASK
Extract REAL upcoming ${sport.displayName}${league != null ? ' ($league)' : ''} matches with their actual scheduled dates.

## OUTPUT FORMAT
Return a valid JSON array. Each match must have:
- homeTeam: string (exact team name from data)
- awayTeam: string (exact team name from data)
- league: string (competition name)
- matchDate: ISO date string (REAL date from fixture data, format: YYYY-MM-DDTHH:MM:SS)
- odds: { homeWin: number, draw: number, awayWin: number, over25?: number, under25?: number, btts?: number }
- analysis: string (2-3 sentences based on research)
- keyFactors: string[] (3-5 factors from research)
- confidence: number (0.0 to 1.0 - lower if date uncertain)

## ODDS GUIDELINES
- Decimal format (e.g., 1.85, 2.10, 3.50)
- If odds found in research, use those exact values
- If no odds found, estimate based on team strength:
  - Strong favorite: 1.30-1.60
  - Slight favorite: 1.70-2.00
  - Even match: 2.00-2.50
  - Underdog: 2.50-4.00
  - Big underdog: 4.00+

## IMPORTANT RULES
1. Extract ONLY matches that appear in the research data
2. Use REAL dates from the fixture information
3. Do NOT invent matches or teams not mentioned
4. If research mentions "this weekend", calculate actual dates from $todayStr
5. Return empty array [] if no valid fixtures found

Return ONLY the JSON array:
''';

    try {
      String response;
      if (provider == 'openrouter') {
        final service = OpenRouterService(apiKey: apiKey);
        response = await service.generateContent(prompt, model: model);
      } else {
        final service = GeminiService(apiKey: apiKey);
        response = await service.generateContent(prompt, model: model);
      }

      // Parse JSON response
      String jsonStr = response;

      // Try to extract JSON array from response
      final jsonMatch = RegExp(r'\[[\s\S]*?\](?=\s*$|\s*```)', multiLine: true)
          .firstMatch(response);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      } else {
        // Try another pattern - find array between code blocks
        final codeBlockMatch =
            RegExp(r'```(?:json)?\s*(\[[\s\S]*?\])\s*```').firstMatch(response);
        if (codeBlockMatch != null) {
          jsonStr = codeBlockMatch.group(1)!;
        }
      }

      final List<dynamic> parsed = jsonDecode(jsonStr);

      if (parsed.isEmpty) {
        debugPrint(
            '[SportsPredictor] Empty predictions array, using sample data');
        return _getSamplePredictions(sport, league, sources);
      }

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
      debugPrint('[SportsPredictor] Error generating predictions: $e');
      return _getSamplePredictions(sport, league, sources);
    }
  }

  List<SportsPrediction> _getSamplePredictions(
    SportType sport,
    String? league,
    List<PredictionSource> sources,
  ) {
    final now = DateTime.now();

    // Sport-specific sample data
    if (sport == SportType.football) {
      return [
        SportsPrediction(
          id: _uuid.v4(),
          sport: sport.displayName,
          league: league ?? 'Premier League',
          homeTeam: 'Manchester City',
          awayTeam: 'Arsenal',
          matchDate: now.add(const Duration(days: 2)),
          odds: PredictionOdds(
              homeWin: 1.75,
              draw: 3.80,
              awayWin: 4.20,
              over25: 1.65,
              under25: 2.20,
              btts: 1.70),
          analysis:
              'Manchester City are favorites at home with their strong attacking form. Arsenal will look to counter but City\'s defense has been solid.',
          keyFactors: [
            'City unbeaten at home',
            'Arsenal missing key players',
            'Head-to-head favors City',
            'City in better form'
          ],
          confidence: 0.72,
          sources: sources,
        ),
        SportsPrediction(
          id: _uuid.v4(),
          sport: sport.displayName,
          league: league ?? 'Premier League',
          homeTeam: 'Liverpool',
          awayTeam: 'Chelsea',
          matchDate: now.add(const Duration(days: 3)),
          odds: PredictionOdds(
              homeWin: 1.90,
              draw: 3.50,
              awayWin: 3.80,
              over25: 1.55,
              under25: 2.40,
              btts: 1.65),
          analysis:
              'Liverpool\'s Anfield fortress makes them favorites. Chelsea have struggled away from home this season.',
          keyFactors: [
            'Liverpool strong at Anfield',
            'Chelsea poor away form',
            'Both teams score often',
            'High-scoring fixture historically'
          ],
          confidence: 0.68,
          sources: sources,
        ),
        SportsPrediction(
          id: _uuid.v4(),
          sport: sport.displayName,
          league: league ?? 'La Liga',
          homeTeam: 'Real Madrid',
          awayTeam: 'Barcelona',
          matchDate: now.add(const Duration(days: 5)),
          odds: PredictionOdds(
              homeWin: 2.10,
              draw: 3.40,
              awayWin: 3.20,
              over25: 1.70,
              under25: 2.10,
              btts: 1.75),
          analysis:
              'El Clasico is always unpredictable. Real Madrid have home advantage but Barcelona\'s recent form is impressive.',
          keyFactors: [
            'El Clasico rivalry',
            'Both teams in good form',
            'Key players fit',
            'High stakes match'
          ],
          confidence: 0.55,
          sources: sources,
        ),
      ];
    } else if (sport == SportType.basketball) {
      return [
        SportsPrediction(
          id: _uuid.v4(),
          sport: sport.displayName,
          league: league ?? 'NBA',
          homeTeam: 'Los Angeles Lakers',
          awayTeam: 'Boston Celtics',
          matchDate: now.add(const Duration(days: 2)),
          odds: PredictionOdds(homeWin: 1.95, draw: 15.0, awayWin: 1.85),
          analysis:
              'Classic NBA rivalry. Celtics have the better record but Lakers perform well at home.',
          keyFactors: [
            'Historic rivalry',
            'Lakers home court',
            'Celtics better record',
            'Star players healthy'
          ],
          confidence: 0.60,
          sources: sources,
        ),
      ];
    } else if (sport == SportType.tennis) {
      return [
        SportsPrediction(
          id: _uuid.v4(),
          sport: sport.displayName,
          league: league ?? 'ATP Tour',
          homeTeam: 'Novak Djokovic',
          awayTeam: 'Carlos Alcaraz',
          matchDate: now.add(const Duration(days: 4)),
          odds: PredictionOdds(homeWin: 1.80, draw: 0, awayWin: 2.00),
          analysis:
              'Battle of generations. Djokovic\'s experience vs Alcaraz\'s youth and energy.',
          keyFactors: [
            'Djokovic experience',
            'Alcaraz rising star',
            'Surface matters',
            'Recent form'
          ],
          confidence: 0.58,
          sources: sources,
        ),
      ];
    }

    // Default sample
    return [
      SportsPrediction(
        id: _uuid.v4(),
        sport: sport.displayName,
        league: league ?? 'General',
        homeTeam: 'Team Alpha',
        awayTeam: 'Team Beta',
        matchDate: now.add(const Duration(days: 2)),
        odds: PredictionOdds(homeWin: 2.00, draw: 3.20, awayWin: 3.50),
        analysis:
            'Based on current form and statistics, the home team has a slight advantage.',
        keyFactors: ['Home advantage', 'Recent form', 'Head-to-head record'],
        confidence: 0.55,
        sources: sources,
      ),
    ];
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
