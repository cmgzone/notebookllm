import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sports_models.dart';
import '../../../core/api/api_service.dart';
import '../../../core/search/serper_service.dart';
import '../../../core/ai/ai_settings_service.dart';
import '../../../core/ai/openrouter_service.dart';
import '../../../core/ai/gemini_service.dart';
import '../../../core/security/global_credentials_service.dart';

// ============ LIVE SCORES PROVIDER ============
class LiveScoresState {
  final List<LiveMatch> matches;
  final bool isLoading;
  final String? error;
  final String? selectedSport;
  final String? selectedLeague;
  final DateTime lastUpdated;

  LiveScoresState({
    this.matches = const [],
    this.isLoading = false,
    this.error,
    this.selectedSport,
    this.selectedLeague,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  List<LiveMatch> get liveMatches => matches.where((m) => m.isLive).toList();
  List<LiveMatch> get upcomingMatches =>
      matches.where((m) => m.status == MatchStatus.scheduled).toList();
  List<LiveMatch> get finishedMatches =>
      matches.where((m) => m.status == MatchStatus.finished).toList();

  LiveScoresState copyWith({
    List<LiveMatch>? matches,
    bool? isLoading,
    String? error,
    String? selectedSport,
    String? selectedLeague,
    DateTime? lastUpdated,
  }) =>
      LiveScoresState(
        matches: matches ?? this.matches,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        selectedSport: selectedSport ?? this.selectedSport,
        selectedLeague: selectedLeague ?? this.selectedLeague,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

class LiveScoresNotifier extends StateNotifier<LiveScoresState> {
  final Ref _ref;
  final ApiService _api;
  Timer? _refreshTimer;

  LiveScoresNotifier(this._ref, this._api) : super(LiveScoresState());

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (state.matches.any((m) => m.isLive)) {
        fetchLiveScores();
      }
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> fetchLiveScores({String? sport, String? league}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final sportFilter = sport ?? state.selectedSport ?? 'Football';

      // First try backend API
      try {
        final data = await _api.getLiveMatches();
        if (data.isNotEmpty) {
          final matches = data
              .map((m) => LiveMatch(
                    id: m['id'] ?? '',
                    homeTeam: m['homeTeam'] ?? '',
                    awayTeam: m['awayTeam'] ?? '',
                    league: m['league'] ?? '',
                    sport: m['sport'] ?? sportFilter,
                    homeScore: m['homeScore'] ?? 0,
                    awayScore: m['awayScore'] ?? 0,
                    status: _mapStatus(m['status']),
                    minute: m['minute'],
                    kickoff: m['kickoff'] != null
                        ? DateTime.tryParse(m['kickoff'].toString()) ??
                            DateTime.now()
                        : DateTime.now(),
                    events: (m['events'] as List?)
                            ?.map((e) => MatchEvent(
                                  type: e['type'] ?? '',
                                  team: e['team'] ?? '',
                                  player: e['player'] ?? '',
                                  minute: e['minute'] ?? '',
                                ))
                            .toList() ??
                        const [],
                    currentOdds: m['odds'] != null
                        ? LiveOdds(
                            homeWin: (m['odds']['homeWin'] ?? 2.0).toDouble(),
                            draw: (m['odds']['draw'] ?? 3.5).toDouble(),
                            awayWin: (m['odds']['awayWin'] ?? 3.0).toDouble(),
                            updatedAt: DateTime.now(),
                          )
                        : null,
                  ))
              .toList();

          state = state.copyWith(
            matches: matches,
            isLoading: false,
            selectedSport: sportFilter,
            selectedLeague: league,
            lastUpdated: DateTime.now(),
          );
          return;
        }
      } catch (e) {
        debugPrint('[LiveScores] Backend API failed: $e');
      }

      // Fallback: Search for live scores using web search
      final matches = await _fetchLiveScoresFromWeb(sportFilter);

      state = state.copyWith(
        matches: matches,
        isLoading: false,
        selectedSport: sportFilter,
        selectedLeague: league,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[LiveScores] Error: $e');
      state = state.copyWith(
        matches: [],
        isLoading: false,
        error: 'Failed to load live scores',
        lastUpdated: DateTime.now(),
      );
    }
  }

  Future<List<LiveMatch>> _fetchLiveScoresFromWeb(String sport) async {
    try {
      final serper = _ref.read(serperServiceProvider);
      final today = DateTime.now();

      // Search for live scores
      final query =
          '$sport live scores today ${today.day}/${today.month}/${today.year}';
      debugPrint('[LiveScores] Searching: $query');

      final results = await serper.search(query, type: 'search', num: 10);

      if (results.isEmpty) {
        debugPrint('[LiveScores] No search results');
        return [];
      }

      // Build context from search results
      final searchContext =
          results.map((r) => '${r.title}: ${r.snippet}').join('\n');

      // Use AI to extract match data
      final settings = await AISettingsService.getSettings();
      final provider = settings.provider;
      final model = settings.getEffectiveModel();

      final creds = _ref.read(globalCredentialsServiceProvider);
      String? apiKey;

      if (provider == 'openrouter') {
        apiKey = await creds.getApiKey('openrouter');
      } else {
        apiKey = await creds.getApiKey('gemini');
      }

      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('[LiveScores] No API key available');
        return [];
      }

      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final prompt = '''
Extract live and today's $sport match scores from this data.

SEARCH RESULTS:
$searchContext

TODAY'S DATE: $todayStr

Return a JSON array of matches. Each match:
{
  "id": "unique_id",
  "homeTeam": "Team Name",
  "awayTeam": "Team Name", 
  "league": "League Name",
  "homeScore": 0,
  "awayScore": 0,
  "status": "live" | "scheduled" | "finished",
  "minute": "45'" (if live),
  "kickoff": "$todayStr T15:00:00" (ISO format)
}

Rules:
- Only include REAL matches from the data
- Status "live" for ongoing matches
- Status "scheduled" for upcoming today
- Status "finished" for completed matches
- Return empty array [] if no matches found

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

      // Parse JSON
      String jsonStr = response;
      final jsonMatch = RegExp(r'\[[\s\S]*?\]').firstMatch(response);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }

      final List<dynamic> parsed = jsonDecode(jsonStr);

      return parsed.map((m) {
        final map = m as Map<String, dynamic>;
        return LiveMatch(
          id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          homeTeam: map['homeTeam'] ?? 'Unknown',
          awayTeam: map['awayTeam'] ?? 'Unknown',
          league: map['league'] ?? sport,
          sport: sport,
          homeScore: map['homeScore'] ?? 0,
          awayScore: map['awayScore'] ?? 0,
          status: _mapStatus(map['status']),
          minute: map['minute'],
          kickoff: DateTime.tryParse(map['kickoff'] ?? '') ?? DateTime.now(),
          events: const [],
          currentOdds: null,
        );
      }).toList();
    } catch (e) {
      debugPrint('[LiveScores] Web fetch error: $e');
      return [];
    }
  }

  MatchStatus _mapStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'live':
        return MatchStatus.live;
      case 'finished':
        return MatchStatus.finished;
      case 'postponed':
        return MatchStatus.postponed;
      case 'cancelled':
        return MatchStatus.cancelled;
      default:
        return MatchStatus.scheduled;
    }
  }

  void setSport(String sport) {
    state = state.copyWith(selectedSport: sport);
    fetchLiveScores(sport: sport);
  }

  void setLeague(String? league) {
    state = state.copyWith(selectedLeague: league);
    fetchLiveScores(league: league);
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}

final liveScoresProvider =
    StateNotifierProvider<LiveScoresNotifier, LiveScoresState>((ref) {
  return LiveScoresNotifier(ref, ref.watch(apiServiceProvider));
});

// ============ LEADERBOARD PROVIDER ============
class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final bool isLoading;
  final String timeframe;
  final String? error;

  LeaderboardState({
    this.entries = const [],
    this.isLoading = false,
    this.timeframe = 'weekly',
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    bool? isLoading,
    String? timeframe,
    String? error,
  }) =>
      LeaderboardState(
        entries: entries ?? this.entries,
        isLoading: isLoading ?? this.isLoading,
        timeframe: timeframe ?? this.timeframe,
        error: error,
      );
}

class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final ApiService _api;

  LeaderboardNotifier(this._api) : super(LeaderboardState()) {
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _api.getSportsLeaderboard(
        timeframe: state.timeframe,
        limit: 50,
      );

      if (data.isNotEmpty) {
        final entries = data
            .map((e) => LeaderboardEntry(
                  oderId: e['user_id'] ?? e['id'] ?? '',
                  username: e['display_name'] ?? e['username'] ?? 'Anonymous',
                  avatarUrl: e['avatar_url'],
                  totalPredictions: e['total_predictions'] ?? 0,
                  wins: e['wins'] ?? 0,
                  losses: e['losses'] ?? 0,
                  winRate: (e['win_rate'] ?? 0).toDouble(),
                  profit: (e['total_profit'] ?? 0).toDouble(),
                  roi: (e['roi'] ?? 0).toDouble(),
                  rank: e['rank'] ?? 0,
                  streak: e['current_streak'] ?? 0,
                  badges: List<String>.from(e['badges'] ?? []),
                ))
            .toList();

        state = state.copyWith(entries: entries, isLoading: false);
      } else {
        // No data available - show empty state
        state = state.copyWith(
          entries: [],
          isLoading: false,
          error: 'No leaderboard data yet. Start making predictions!',
        );
      }
    } catch (e) {
      state = state.copyWith(
        entries: [],
        isLoading: false,
        error: 'Be the first to join the leaderboard!',
      );
    }
  }

  void setTimeframe(String timeframe) {
    state = state.copyWith(timeframe: timeframe);
    _loadLeaderboard();
  }

  Future<void> refresh() async {
    await _loadLeaderboard();
  }
}

final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>(
  (ref) => LeaderboardNotifier(ref.watch(apiServiceProvider)),
);

// ============ BETTING SLIP PROVIDER ============
class BettingSlipState {
  final List<SlipSelection> selections;
  final double stake;
  final String slipType;

  BettingSlipState({
    this.selections = const [],
    this.stake = 10.0,
    this.slipType = 'accumulator',
  });

  double get totalOdds =>
      selections.isEmpty ? 0 : selections.fold(1.0, (prod, s) => prod * s.odds);
  double get potentialWin => stake * totalOdds;
  int get selectionCount => selections.length;

  BettingSlipState copyWith({
    List<SlipSelection>? selections,
    double? stake,
    String? slipType,
  }) =>
      BettingSlipState(
        selections: selections ?? this.selections,
        stake: stake ?? this.stake,
        slipType: slipType ?? this.slipType,
      );
}

class BettingSlipNotifier extends StateNotifier<BettingSlipState> {
  BettingSlipNotifier() : super(BettingSlipState());

  void addSelection(SlipSelection selection) {
    if (state.selections.any((s) => s.matchId == selection.matchId)) {
      final updated = state.selections.map((s) {
        if (s.matchId == selection.matchId) return selection;
        return s;
      }).toList();
      state = state.copyWith(selections: updated);
    } else {
      state = state.copyWith(selections: [...state.selections, selection]);
    }
  }

  void removeSelection(String matchId) {
    state = state.copyWith(
      selections: state.selections.where((s) => s.matchId != matchId).toList(),
    );
  }

  void setStake(double stake) {
    state = state.copyWith(stake: stake);
  }

  void setSlipType(String type) {
    state = state.copyWith(slipType: type);
  }

  void clearSlip() {
    state = BettingSlipState();
  }

  BettingSlip buildSlip() {
    return BettingSlip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      selections: state.selections,
      totalStake: state.stake,
      totalOdds: state.totalOdds,
      potentialWin: state.potentialWin,
      type: state.slipType,
      createdAt: DateTime.now(),
    );
  }
}

final bettingSlipProvider =
    StateNotifierProvider<BettingSlipNotifier, BettingSlipState>(
  (ref) => BettingSlipNotifier(),
);
