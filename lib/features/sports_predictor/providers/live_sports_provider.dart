import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sports_models.dart';
import '../../../core/api/api_service.dart';

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
  final ApiService _api;
  Timer? _refreshTimer;

  LiveScoresNotifier(this._api) : super(LiveScoresState());

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
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

      // Fetch from backend (SportRadar)
      final data = await _api.getLiveMatches();

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
                    ? DateTime.parse(m['kickoff'])
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
    } catch (e) {
      // Fallback to sample data
      final matches = _getSampleMatches(sport ?? 'Football');
      state = state.copyWith(
        matches: matches,
        isLoading: false,
        selectedSport: sport,
        lastUpdated: DateTime.now(),
      );
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

  List<LiveMatch> _getSampleMatches(String sport) {
    final now = DateTime.now();
    return [
      LiveMatch(
        id: '1',
        homeTeam: 'Manchester United',
        awayTeam: 'Liverpool',
        league: 'Premier League',
        sport: sport,
        homeScore: 2,
        awayScore: 1,
        status: MatchStatus.live,
        minute: '67\'',
        kickoff: now.subtract(const Duration(hours: 1)),
        events: [
          MatchEvent(
              type: 'goal',
              team: 'Manchester United',
              player: 'Rashford',
              minute: '23\''),
          MatchEvent(
              type: 'goal', team: 'Liverpool', player: 'Salah', minute: '45\''),
          MatchEvent(
              type: 'goal',
              team: 'Manchester United',
              player: 'Bruno',
              minute: '56\''),
        ],
        currentOdds: LiveOdds(
          homeWin: 1.45,
          draw: 4.50,
          awayWin: 6.00,
          updatedAt: now,
          homeWinChange: -0.15,
          awayWinChange: 0.50,
        ),
      ),
      LiveMatch(
        id: '2',
        homeTeam: 'Arsenal',
        awayTeam: 'Chelsea',
        league: 'Premier League',
        sport: sport,
        homeScore: 0,
        awayScore: 0,
        status: MatchStatus.scheduled,
        kickoff: now.add(const Duration(hours: 2)),
        currentOdds: LiveOdds(
          homeWin: 2.10,
          draw: 3.40,
          awayWin: 3.20,
          updatedAt: now,
        ),
      ),
      LiveMatch(
        id: '3',
        homeTeam: 'Real Madrid',
        awayTeam: 'Barcelona',
        league: 'La Liga',
        sport: sport,
        homeScore: 3,
        awayScore: 2,
        status: MatchStatus.finished,
        kickoff: now.subtract(const Duration(hours: 3)),
      ),
      LiveMatch(
        id: '4',
        homeTeam: 'Bayern Munich',
        awayTeam: 'Dortmund',
        league: 'Bundesliga',
        sport: sport,
        homeScore: 1,
        awayScore: 1,
        status: MatchStatus.live,
        minute: '34\'',
        kickoff: now.subtract(const Duration(minutes: 40)),
        currentOdds: LiveOdds(
          homeWin: 2.20,
          draw: 3.10,
          awayWin: 3.50,
          updatedAt: now,
        ),
      ),
    ];
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
  return LiveScoresNotifier(ref.watch(apiServiceProvider));
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
    } catch (e) {
      // Fallback to sample data if API fails
      state = state.copyWith(
        entries: _generateSampleLeaderboard(),
        isLoading: false,
        error: null, // Don't show error, just use sample data
      );
    }
  }

  List<LeaderboardEntry> _generateSampleLeaderboard() {
    return [
      LeaderboardEntry(
        oderId: '1',
        username: 'ProTipster99',
        totalPredictions: 156,
        wins: 98,
        losses: 58,
        winRate: 62.8,
        profit: 2450.50,
        roi: 24.5,
        rank: 1,
        streak: 7,
        badges: ['🏆', '🔥', '💎'],
      ),
      LeaderboardEntry(
        oderId: '2',
        username: 'BetMaster',
        totalPredictions: 203,
        wins: 118,
        losses: 85,
        winRate: 58.1,
        profit: 1890.00,
        roi: 18.9,
        rank: 2,
        streak: 4,
        badges: ['🥈', '⚡'],
      ),
      LeaderboardEntry(
        oderId: '3',
        username: 'OddsKing',
        totalPredictions: 89,
        wins: 52,
        losses: 37,
        winRate: 58.4,
        profit: 1650.75,
        roi: 22.1,
        rank: 3,
        streak: 3,
        badges: ['🥉'],
      ),
      LeaderboardEntry(
        oderId: '4',
        username: 'ValueHunter',
        totalPredictions: 145,
        wins: 78,
        losses: 67,
        winRate: 53.8,
        profit: 1200.00,
        roi: 15.2,
        rank: 4,
        streak: 2,
        badges: [],
      ),
      LeaderboardEntry(
        oderId: '5',
        username: 'SharpBettor',
        totalPredictions: 112,
        wins: 61,
        losses: 51,
        winRate: 54.5,
        profit: 980.25,
        roi: 12.8,
        rank: 5,
        streak: 1,
        badges: [],
      ),
    ];
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
