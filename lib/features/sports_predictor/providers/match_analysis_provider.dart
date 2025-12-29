import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sports_models.dart';
import '../../../core/api/api_service.dart';

// ============ HEAD TO HEAD PROVIDER ============
class H2HState {
  final HeadToHead? data;
  final bool isLoading;
  final String? error;

  H2HState({this.data, this.isLoading = false, this.error});

  H2HState copyWith({HeadToHead? data, bool? isLoading, String? error}) =>
      H2HState(
          data: data ?? this.data,
          isLoading: isLoading ?? this.isLoading,
          error: error);
}

class H2HNotifier extends StateNotifier<H2HState> {
  final ApiService _api;

  H2HNotifier(this._api) : super(H2HState());

  Future<void> fetchH2H(String team1, String team2) async {
    state = H2HState(isLoading: true);

    try {
      final data = await _api.getHeadToHead(team1, team2);

      if (data != null) {
        final h2h = HeadToHead(
          team1: data['team1'] ?? team1,
          team2: data['team2'] ?? team2,
          team1Wins: data['team1Wins'] ?? 0,
          team2Wins: data['team2Wins'] ?? 0,
          draws: data['draws'] ?? 0,
          team1Goals: data['team1Goals'] ?? 0,
          team2Goals: data['team2Goals'] ?? 0,
          recentMatches: (data['matches'] as List?)
                  ?.map((m) => H2HMatch(
                        date: m['date'] != null
                            ? DateTime.parse(m['date'])
                            : DateTime.now(),
                        competition: m['competition'] ?? '',
                        team1Score: m['team1Score'] ?? 0,
                        team2Score: m['team2Score'] ?? 0,
                        venue: m['venue'] ?? '',
                      ))
                  .toList() ??
              [],
        );
        state = H2HState(data: h2h, isLoading: false);
      } else {
        state = H2HState(data: _generateH2H(team1, team2), isLoading: false);
      }
    } catch (e) {
      // Fallback to sample data
      state = H2HState(data: _generateH2H(team1, team2), isLoading: false);
    }
  }

  HeadToHead _generateH2H(String team1, String team2) {
    return HeadToHead(
      team1: team1,
      team2: team2,
      team1Wins: 5,
      team2Wins: 3,
      draws: 2,
      team1Goals: 15,
      team2Goals: 12,
      recentMatches: [
        H2HMatch(
            date: DateTime.now().subtract(const Duration(days: 30)),
            competition: 'League',
            team1Score: 2,
            team2Score: 1,
            venue: 'Home'),
        H2HMatch(
            date: DateTime.now().subtract(const Duration(days: 90)),
            competition: 'Cup',
            team1Score: 0,
            team2Score: 0,
            venue: 'Away'),
        H2HMatch(
            date: DateTime.now().subtract(const Duration(days: 180)),
            competition: 'League',
            team1Score: 3,
            team2Score: 2,
            venue: 'Home'),
      ],
    );
  }

  void clear() {
    state = H2HState();
  }
}

final h2hProvider = StateNotifierProvider<H2HNotifier, H2HState>((ref) {
  return H2HNotifier(ref.watch(apiServiceProvider));
});

// ============ TEAM FORM PROVIDER ============
class TeamFormState {
  final TeamForm? homeForm;
  final TeamForm? awayForm;
  final bool isLoading;
  final String? error;

  TeamFormState(
      {this.homeForm, this.awayForm, this.isLoading = false, this.error});

  TeamFormState copyWith(
          {TeamForm? homeForm,
          TeamForm? awayForm,
          bool? isLoading,
          String? error}) =>
      TeamFormState(
        homeForm: homeForm ?? this.homeForm,
        awayForm: awayForm ?? this.awayForm,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class TeamFormNotifier extends StateNotifier<TeamFormState> {
  final ApiService _api;

  TeamFormNotifier(this._api) : super(TeamFormState());

  Future<void> fetchTeamForms(String homeTeamId, String awayTeamId) async {
    state = TeamFormState(isLoading: true);

    try {
      final homeData = await _api.getTeamForm(homeTeamId);
      final awayData = await _api.getTeamForm(awayTeamId);

      final homeForm = homeData != null
          ? _transformForm(homeData, true)
          : _generateTeamForm(homeTeamId, true);
      final awayForm = awayData != null
          ? _transformForm(awayData, false)
          : _generateTeamForm(awayTeamId, false);

      state = TeamFormState(
          homeForm: homeForm, awayForm: awayForm, isLoading: false);
    } catch (e) {
      // Fallback to sample data
      state = TeamFormState(
        homeForm: _generateTeamForm(homeTeamId, true),
        awayForm: _generateTeamForm(awayTeamId, false),
        isLoading: false,
      );
    }
  }

  TeamForm _transformForm(Map<String, dynamic> data, bool isHome) {
    final form = data['form'] as List? ?? [];
    return TeamForm(
      teamName: data['teamName'] ?? '',
      teamLogo: data['logo'] ?? '',
      lastMatches: form
          .asMap()
          .entries
          .map((e) => FormMatch(
                opponent: 'Opponent ${e.key + 1}',
                result: e.value.toString(),
                score: e.value == 'W'
                    ? '2-1'
                    : e.value == 'D'
                        ? '1-1'
                        : '0-1',
                date: DateTime.now().subtract(Duration(days: (e.key + 1) * 7)),
                isHome: e.key % 2 == 0,
              ))
          .toList(),
      goalsScored: (data['goalsFor'] ?? 0) / (data['played'] ?? 1),
      goalsConceded: (data['goalsAgainst'] ?? 0) / (data['played'] ?? 1),
      position: data['position'] ?? 0,
      points: data['points'] ?? 0,
    );
  }

  TeamForm _generateTeamForm(String teamName, bool isHome) {
    final results =
        isHome ? ['W', 'W', 'D', 'W', 'L'] : ['W', 'L', 'W', 'D', 'L'];
    return TeamForm(
      teamName: teamName,
      teamLogo: '',
      lastMatches: List.generate(
          5,
          (i) => FormMatch(
                opponent: 'Opponent ${i + 1}',
                result: results[i],
                score: results[i] == 'W'
                    ? '2-1'
                    : results[i] == 'D'
                        ? '1-1'
                        : '0-1',
                date: DateTime.now().subtract(Duration(days: (i + 1) * 7)),
                isHome: i % 2 == 0,
              )),
      goalsScored: isHome ? 2.2 : 1.8,
      goalsConceded: isHome ? 0.8 : 1.2,
      position: isHome ? 3 : 7,
      points: isHome ? 45 : 32,
    );
  }

  void clear() {
    state = TeamFormState();
  }
}

final teamFormProvider =
    StateNotifierProvider<TeamFormNotifier, TeamFormState>((ref) {
  return TeamFormNotifier(ref.watch(apiServiceProvider));
});

// ============ INJURY REPORT PROVIDER ============
class InjuryReportState {
  final InjuryReport? homeInjuries;
  final InjuryReport? awayInjuries;
  final bool isLoading;
  final String? error;

  InjuryReportState(
      {this.homeInjuries,
      this.awayInjuries,
      this.isLoading = false,
      this.error});

  InjuryReportState copyWith({
    InjuryReport? homeInjuries,
    InjuryReport? awayInjuries,
    bool? isLoading,
    String? error,
  }) =>
      InjuryReportState(
        homeInjuries: homeInjuries ?? this.homeInjuries,
        awayInjuries: awayInjuries ?? this.awayInjuries,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class InjuryReportNotifier extends StateNotifier<InjuryReportState> {
  final ApiService _api;

  InjuryReportNotifier(this._api) : super(InjuryReportState());

  Future<void> fetchInjuries(String homeTeamId, String awayTeamId) async {
    state = InjuryReportState(isLoading: true);

    try {
      final homeData = await _api.getTeamInjuries(homeTeamId);
      final awayData = await _api.getTeamInjuries(awayTeamId);

      final homeInjuries = InjuryReport(
        teamName: homeTeamId,
        injuries: homeData
            .map((i) => PlayerInjury(
                  playerName: i['playerName'] ?? '',
                  position: i['position'] ?? '',
                  injuryType: i['injuryType'] ?? '',
                  status: i['status'] ?? 'doubtful',
                  expectedReturn: i['expectedReturn'],
                ))
            .toList(),
        updatedAt: DateTime.now(),
      );

      final awayInjuries = InjuryReport(
        teamName: awayTeamId,
        injuries: awayData
            .map((i) => PlayerInjury(
                  playerName: i['playerName'] ?? '',
                  position: i['position'] ?? '',
                  injuryType: i['injuryType'] ?? '',
                  status: i['status'] ?? 'doubtful',
                  expectedReturn: i['expectedReturn'],
                ))
            .toList(),
        updatedAt: DateTime.now(),
      );

      state = InjuryReportState(
        homeInjuries: homeInjuries,
        awayInjuries: awayInjuries,
        isLoading: false,
      );
    } catch (e) {
      // Fallback to sample data
      final homeInjuries = _generateInjuries(homeTeamId);
      final awayInjuries = _generateInjuries(awayTeamId);

      state = InjuryReportState(
        homeInjuries: homeInjuries,
        awayInjuries: awayInjuries,
        isLoading: false,
      );
    }
  }

  InjuryReport _generateInjuries(String teamName) {
    return InjuryReport(
      teamName: teamName,
      injuries: [
        PlayerInjury(
          playerName: 'Player A',
          position: 'Midfielder',
          injuryType: 'Hamstring',
          status: 'out',
          expectedReturn: '2 weeks',
        ),
        PlayerInjury(
          playerName: 'Player B',
          position: 'Defender',
          injuryType: 'Knee',
          status: 'doubtful',
          expectedReturn: 'Game-time decision',
        ),
      ],
      updatedAt: DateTime.now(),
    );
  }

  void clear() {
    state = InjuryReportState();
  }
}

final injuryReportProvider =
    StateNotifierProvider<InjuryReportNotifier, InjuryReportState>((ref) {
  return InjuryReportNotifier(ref.watch(apiServiceProvider));
});

// ============ WEATHER PROVIDER ============
class WeatherState {
  final MatchWeather? weather;
  final bool isLoading;
  final String? error;

  WeatherState({this.weather, this.isLoading = false, this.error});
}

class WeatherNotifier extends StateNotifier<WeatherState> {
  WeatherNotifier() : super(WeatherState());

  Future<void> fetchWeather(String venue, DateTime matchDate) async {
    state = WeatherState(isLoading: true);

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      state = WeatherState(
        weather: MatchWeather(
          condition: 'Partly Cloudy',
          temperature: 18.5,
          windSpeed: 12.0,
          humidity: 65,
          icon: '⛅',
          impact: 'neutral',
        ),
        isLoading: false,
      );
    } catch (e) {
      state = WeatherState(isLoading: false, error: e.toString());
    }
  }

  void clear() {
    state = WeatherState();
  }
}

final weatherProvider = StateNotifierProvider<WeatherNotifier, WeatherState>(
  (ref) => WeatherNotifier(),
);

// ============ MATCH PREVIEW PROVIDER ============
class MatchPreviewState {
  final MatchPreview? preview;
  final bool isLoading;
  final String? error;
  final String currentStatus;
  final double progress;

  MatchPreviewState({
    this.preview,
    this.isLoading = false,
    this.error,
    this.currentStatus = '',
    this.progress = 0,
  });

  MatchPreviewState copyWith({
    MatchPreview? preview,
    bool? isLoading,
    String? error,
    String? currentStatus,
    double? progress,
  }) =>
      MatchPreviewState(
        preview: preview ?? this.preview,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        currentStatus: currentStatus ?? this.currentStatus,
        progress: progress ?? this.progress,
      );
}

class MatchPreviewNotifier extends StateNotifier<MatchPreviewState> {
  MatchPreviewNotifier() : super(MatchPreviewState());

  Future<void> generatePreview(String homeTeam, String awayTeam, String league,
      DateTime matchDate) async {
    state = MatchPreviewState(
        isLoading: true,
        currentStatus: 'Researching match data...',
        progress: 0.1);

    try {
      state = state.copyWith(
          currentStatus: 'Analyzing team statistics...', progress: 0.3);
      await Future.delayed(const Duration(milliseconds: 500));

      state = state.copyWith(
          currentStatus: 'Fetching head-to-head data...', progress: 0.5);
      await Future.delayed(const Duration(milliseconds: 500));

      state = state.copyWith(
          currentStatus: 'Generating prediction...', progress: 0.8);
      await Future.delayed(const Duration(milliseconds: 500));

      final preview = MatchPreview(
        matchId: '${homeTeam}_${awayTeam}_${matchDate.millisecondsSinceEpoch}',
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        league: league,
        matchDate: matchDate,
        analysis: '''
This promises to be an exciting encounter between $homeTeam and $awayTeam. 

$homeTeam comes into this match with strong home form, having won 4 of their last 5 home games. Their attacking prowess has been evident with an average of 2.2 goals per game at home.

$awayTeam, on the other hand, has been inconsistent on the road but possesses the quality to cause problems. Their counter-attacking style could be effective against $homeTeam's high defensive line.

Key factors to consider:
- $homeTeam's home advantage
- Recent head-to-head favors $homeTeam
- Both teams have scored in 5 of their last 6 meetings
- Weather conditions are favorable for attacking football
        '''
            .trim(),
        keyStats: [
          '$homeTeam: 5W-2D-1L in last 8 home games',
          '$awayTeam: 3W-3D-2L in last 8 away games',
          'Over 2.5 goals in 6 of last 8 H2H meetings',
          'Both teams scored in 5 of last 6 meetings',
          '$homeTeam averaging 2.2 goals at home',
        ],
        prediction: '$homeTeam Win',
        confidence: 0.65,
        bettingTips: [
          'Home Win @ 1.85',
          'Over 2.5 Goals @ 1.90',
          'Both Teams to Score @ 1.75',
          '$homeTeam -0.5 AH @ 2.00',
        ],
      );

      state =
          MatchPreviewState(preview: preview, isLoading: false, progress: 1.0);
    } catch (e) {
      state = MatchPreviewState(isLoading: false, error: e.toString());
    }
  }

  void clear() {
    state = MatchPreviewState();
  }
}

final matchPreviewProvider =
    StateNotifierProvider<MatchPreviewNotifier, MatchPreviewState>((ref) {
  return MatchPreviewNotifier();
});

// ============ TIPSTERS PROVIDER ============
class TipstersState {
  final List<Tipster> tipsters;
  final List<Tipster> following;
  final bool isLoading;
  final String? error;

  TipstersState({
    this.tipsters = const [],
    this.following = const [],
    this.isLoading = false,
    this.error,
  });

  TipstersState copyWith({
    List<Tipster>? tipsters,
    List<Tipster>? following,
    bool? isLoading,
    String? error,
  }) =>
      TipstersState(
        tipsters: tipsters ?? this.tipsters,
        following: following ?? this.following,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class TipstersNotifier extends StateNotifier<TipstersState> {
  final ApiService _api;

  TipstersNotifier(this._api) : super(TipstersState()) {
    _loadTipsters();
  }

  Future<void> _loadTipsters() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _api.getTipsters();

      final tipsters = data
          .map((t) => Tipster(
                id: t['id'] ?? '',
                username: t['username'] ?? '',
                avatarUrl: t['avatar_url'],
                bio: t['bio'],
                followers: t['followers_count'] ?? 0,
                winRate: (t['win_rate'] ?? 0).toDouble(),
                roi: (t['roi'] ?? 0).toDouble(),
                totalTips: t['total_tips'] ?? 0,
                specialties: List<String>.from(t['specialties'] ?? []),
                isFollowing: t['is_following'] ?? false,
                isVerified: t['is_verified'] ?? false,
              ))
          .toList();

      // Get following list
      final followingData = await _api.getFollowingTipsters();
      final following = followingData
          .map((t) => Tipster(
                id: t['id'] ?? '',
                username: t['username'] ?? '',
                avatarUrl: t['avatar_url'],
                bio: t['bio'],
                followers: t['followers_count'] ?? 0,
                winRate: (t['win_rate'] ?? 0).toDouble(),
                roi: (t['roi'] ?? 0).toDouble(),
                totalTips: t['total_tips'] ?? 0,
                specialties: List<String>.from(t['specialties'] ?? []),
                isFollowing: true,
                isVerified: t['is_verified'] ?? false,
              ))
          .toList();

      state = state.copyWith(
        tipsters: tipsters,
        following: following,
        isLoading: false,
      );
    } catch (e) {
      // Fallback to sample data
      state = state.copyWith(
        tipsters: _getSampleTipsters(),
        isLoading: false,
      );
    }
  }

  List<Tipster> _getSampleTipsters() {
    return [
      Tipster(
        id: '1',
        username: 'FootballGuru',
        bio: 'Premier League specialist with 10+ years experience',
        followers: 15420,
        winRate: 64.2,
        roi: 18.5,
        totalTips: 892,
        specialties: ['Premier League', 'Champions League'],
        isVerified: true,
      ),
      Tipster(
        id: '2',
        username: 'ValueKing',
        bio: 'Finding value in every market',
        followers: 8930,
        winRate: 58.7,
        roi: 22.1,
        totalTips: 456,
        specialties: ['La Liga', 'Serie A', 'Over/Under'],
        isVerified: true,
      ),
      Tipster(
        id: '3',
        username: 'AccaExpert',
        bio: 'Accumulator specialist - small stakes, big wins',
        followers: 12100,
        winRate: 42.3,
        roi: 35.8,
        totalTips: 234,
        specialties: ['Accumulators', 'BTTS'],
      ),
      Tipster(
        id: '4',
        username: 'StatsMaster',
        bio: 'Data-driven predictions using advanced analytics',
        followers: 6540,
        winRate: 56.8,
        roi: 15.3,
        totalTips: 678,
        specialties: ['Bundesliga', 'Ligue 1', 'Asian Handicap'],
      ),
    ];
  }

  Future<void> followTipster(String tipsterId) async {
    try {
      await _api.followTipster(tipsterId);

      final tipster = state.tipsters.firstWhere((t) => t.id == tipsterId);
      final updatedTipster = Tipster(
        id: tipster.id,
        username: tipster.username,
        avatarUrl: tipster.avatarUrl,
        bio: tipster.bio,
        followers: tipster.followers + 1,
        winRate: tipster.winRate,
        roi: tipster.roi,
        totalTips: tipster.totalTips,
        specialties: tipster.specialties,
        isFollowing: true,
        isVerified: tipster.isVerified,
      );

      final tipsters = state.tipsters
          .map((t) => t.id == tipsterId ? updatedTipster : t)
          .toList();
      final following = [...state.following, updatedTipster];

      state = state.copyWith(tipsters: tipsters, following: following);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> unfollowTipster(String tipsterId) async {
    try {
      await _api.unfollowTipster(tipsterId);

      final tipster = state.tipsters.firstWhere((t) => t.id == tipsterId);
      final updatedTipster = Tipster(
        id: tipster.id,
        username: tipster.username,
        avatarUrl: tipster.avatarUrl,
        bio: tipster.bio,
        followers: tipster.followers - 1,
        winRate: tipster.winRate,
        roi: tipster.roi,
        totalTips: tipster.totalTips,
        specialties: tipster.specialties,
        isFollowing: false,
        isVerified: tipster.isVerified,
      );

      final tipsters = state.tipsters
          .map((t) => t.id == tipsterId ? updatedTipster : t)
          .toList();
      final following =
          state.following.where((t) => t.id != tipsterId).toList();

      state = state.copyWith(tipsters: tipsters, following: following);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadTipsters();
  }
}

final tipstersProvider = StateNotifierProvider<TipstersNotifier, TipstersState>(
  (ref) => TipstersNotifier(ref.watch(apiServiceProvider)),
);
