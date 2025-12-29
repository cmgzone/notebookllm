import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sports_models.dart';
import '../prediction.dart';
import '../../../core/api/api_service.dart';

// ============ PREDICTION HISTORY PROVIDER ============
class PredictionHistoryState {
  final List<PredictionRecord> records;
  final bool isLoading;
  final String? error;

  PredictionHistoryState({
    this.records = const [],
    this.isLoading = false,
    this.error,
  });

  // Stats
  int get totalPredictions => records.length;
  int get wins => records.where((r) => r.result == PredictionResult.won).length;
  int get losses =>
      records.where((r) => r.result == PredictionResult.lost).length;
  int get pending =>
      records.where((r) => r.result == PredictionResult.pending).length;
  double get winRate =>
      totalPredictions > 0 ? (wins / (wins + losses)) * 100 : 0;
  double get totalProfit => records.fold(0.0, (sum, r) => sum + r.profit);
  double get totalStaked => records.fold(0.0, (sum, r) => sum + r.stake);
  double get roi => totalStaked > 0 ? (totalProfit / totalStaked) * 100 : 0;

  // By sport
  Map<String, List<PredictionRecord>> get bySport {
    final map = <String, List<PredictionRecord>>{};
    for (final r in records) {
      map.putIfAbsent(r.sport, () => []).add(r);
    }
    return map;
  }

  // By league
  Map<String, List<PredictionRecord>> get byLeague {
    final map = <String, List<PredictionRecord>>{};
    for (final r in records) {
      map.putIfAbsent(r.league, () => []).add(r);
    }
    return map;
  }

  // By bet type
  Map<String, List<PredictionRecord>> get byBetType {
    final map = <String, List<PredictionRecord>>{};
    for (final r in records) {
      map.putIfAbsent(r.betType, () => []).add(r);
    }
    return map;
  }

  PredictionHistoryState copyWith({
    List<PredictionRecord>? records,
    bool? isLoading,
    String? error,
  }) =>
      PredictionHistoryState(
        records: records ?? this.records,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class PredictionHistoryNotifier extends StateNotifier<PredictionHistoryState> {
  PredictionHistoryNotifier() : super(PredictionHistoryState()) {
    _loadHistory();
  }

  static const _storageKey = 'prediction_history';

  Future<void> _loadHistory() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final list = jsonDecode(data) as List;
        final records = list.map((e) => PredictionRecord.fromJson(e)).toList();
        records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = state.copyWith(records: records, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(state.records.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  Future<void> addPrediction(
    SportsPrediction prediction, {
    required String betType,
    required String selection,
    required double stake,
  }) async {
    final record = PredictionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      matchId:
          '${prediction.homeTeam}_${prediction.awayTeam}_${prediction.matchDate.millisecondsSinceEpoch}',
      homeTeam: prediction.homeTeam,
      awayTeam: prediction.awayTeam,
      league: prediction.league,
      sport: prediction.sport,
      matchDate: prediction.matchDate,
      betType: betType,
      selection: selection,
      odds: _getOddsForSelection(prediction.odds, selection),
      stake: stake,
      confidence: prediction.confidence,
      result: PredictionResult.pending,
      createdAt: DateTime.now(),
      homeTeamLogo: prediction.homeTeamLogo,
      awayTeamLogo: prediction.awayTeamLogo,
    );

    state = state.copyWith(records: [record, ...state.records]);
    await _saveHistory();
  }

  double _getOddsForSelection(PredictionOdds odds, String selection) {
    switch (selection.toLowerCase()) {
      case 'home':
      case '1':
        return odds.homeWin;
      case 'draw':
      case 'x':
        return odds.draw;
      case 'away':
      case '2':
        return odds.awayWin;
      case 'over 2.5':
        return odds.over25 ?? 1.9;
      case 'under 2.5':
        return odds.under25 ?? 1.9;
      case 'btts':
        return odds.btts ?? 1.8;
      default:
        return 2.0;
    }
  }

  Future<void> updateResult(
      String id, PredictionResult result, String? actualScore) async {
    final records = state.records.map((r) {
      if (r.id == id) {
        return PredictionRecord(
          id: r.id,
          matchId: r.matchId,
          homeTeam: r.homeTeam,
          awayTeam: r.awayTeam,
          league: r.league,
          sport: r.sport,
          matchDate: r.matchDate,
          betType: r.betType,
          selection: r.selection,
          odds: r.odds,
          stake: r.stake,
          confidence: r.confidence,
          result: result,
          actualScore: actualScore,
          createdAt: r.createdAt,
          homeTeamLogo: r.homeTeamLogo,
          awayTeamLogo: r.awayTeamLogo,
        );
      }
      return r;
    }).toList();

    state = state.copyWith(records: records);
    await _saveHistory();
  }

  Future<void> deletePrediction(String id) async {
    final records = state.records.where((r) => r.id != id).toList();
    state = state.copyWith(records: records);
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    state = state.copyWith(records: []);
    await _saveHistory();
  }
}

final predictionHistoryProvider =
    StateNotifierProvider<PredictionHistoryNotifier, PredictionHistoryState>(
  (ref) => PredictionHistoryNotifier(),
);

// ============ BANKROLL PROVIDER ============
class BankrollState {
  final double balance;
  final double initialBalance;
  final List<BankrollEntry> entries;
  final bool isLoading;

  BankrollState({
    this.balance = 1000.0,
    this.initialBalance = 1000.0,
    this.entries = const [],
    this.isLoading = false,
  });

  double get profit => balance - initialBalance;
  double get profitPercent =>
      initialBalance > 0 ? (profit / initialBalance) * 100 : 0;

  BankrollState copyWith({
    double? balance,
    double? initialBalance,
    List<BankrollEntry>? entries,
    bool? isLoading,
  }) =>
      BankrollState(
        balance: balance ?? this.balance,
        initialBalance: initialBalance ?? this.initialBalance,
        entries: entries ?? this.entries,
        isLoading: isLoading ?? this.isLoading,
      );
}

class BankrollNotifier extends StateNotifier<BankrollState> {
  BankrollNotifier() : super(BankrollState()) {
    _loadBankroll();
  }

  static const _storageKey = 'bankroll_data';

  Future<void> _loadBankroll() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final json = jsonDecode(data);
        final entries = (json['entries'] as List)
            .map((e) => BankrollEntry.fromJson(e))
            .toList();
        state = BankrollState(
          balance: (json['balance'] as num).toDouble(),
          initialBalance: (json['initialBalance'] as num).toDouble(),
          entries: entries,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveBankroll() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'balance': state.balance,
      'initialBalance': state.initialBalance,
      'entries': state.entries.map((e) => e.toJson()).toList(),
    });
    await prefs.setString(_storageKey, data);
  }

  Future<void> setInitialBalance(double amount) async {
    final entry = BankrollEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      type: 'deposit',
      description: 'Initial bankroll',
      timestamp: DateTime.now(),
      balanceAfter: amount,
    );
    state = BankrollState(
      balance: amount,
      initialBalance: amount,
      entries: [entry],
    );
    await _saveBankroll();
  }

  Future<void> deposit(double amount, String description) async {
    final newBalance = state.balance + amount;
    final entry = BankrollEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      type: 'deposit',
      description: description,
      timestamp: DateTime.now(),
      balanceAfter: newBalance,
    );
    state = state.copyWith(
      balance: newBalance,
      entries: [entry, ...state.entries],
    );
    await _saveBankroll();
  }

  Future<void> withdraw(double amount, String description) async {
    if (amount > state.balance) return;
    final newBalance = state.balance - amount;
    final entry = BankrollEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: -amount,
      type: 'withdrawal',
      description: description,
      timestamp: DateTime.now(),
      balanceAfter: newBalance,
    );
    state = state.copyWith(
      balance: newBalance,
      entries: [entry, ...state.entries],
    );
    await _saveBankroll();
  }

  Future<void> placeBet(
      double stake, String description, String? predictionId) async {
    if (stake > state.balance) return;
    final newBalance = state.balance - stake;
    final entry = BankrollEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: -stake,
      type: 'bet',
      predictionId: predictionId,
      description: description,
      timestamp: DateTime.now(),
      balanceAfter: newBalance,
    );
    state = state.copyWith(
      balance: newBalance,
      entries: [entry, ...state.entries],
    );
    await _saveBankroll();
  }

  Future<void> recordWin(
      double amount, String description, String? predictionId) async {
    final newBalance = state.balance + amount;
    final entry = BankrollEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      type: 'win',
      predictionId: predictionId,
      description: description,
      timestamp: DateTime.now(),
      balanceAfter: newBalance,
    );
    state = state.copyWith(
      balance: newBalance,
      entries: [entry, ...state.entries],
    );
    await _saveBankroll();
  }

  Future<void> resetBankroll() async {
    state = BankrollState();
    await _saveBankroll();
  }
}

final bankrollProvider = StateNotifierProvider<BankrollNotifier, BankrollState>(
  (ref) => BankrollNotifier(),
);

// ============ FAVORITES PROVIDER ============
class FavoritesState {
  final List<FavoriteTeam> teams;
  final bool isLoading;
  final String? error;

  FavoritesState({this.teams = const [], this.isLoading = false, this.error});

  FavoritesState copyWith(
          {List<FavoriteTeam>? teams, bool? isLoading, String? error}) =>
      FavoritesState(
        teams: teams ?? this.teams,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final ApiService _api;

  FavoritesNotifier(this._api) : super(FavoritesState()) {
    _loadFavorites();
  }

  static const _storageKey = 'favorite_teams';

  Future<void> _loadFavorites() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Try backend first
      final data = await _api.getFavoriteTeams();
      final teams = data
          .map((e) => FavoriteTeam(
                id: e['id'] ?? '',
                name: e['team_name'] ?? '',
                sport: e['sport'] ?? 'Football',
                league: e['league'] ?? '',
                logoUrl: e['team_logo'],
                notificationsEnabled: e['notifications_enabled'] ?? true,
              ))
          .toList();
      state = state.copyWith(teams: teams, isLoading: false);

      // Also save locally for offline access
      await _saveFavoritesLocally();
    } catch (e) {
      // Fallback to local storage
      await _loadFavoritesLocally();
    }
  }

  Future<void> _loadFavoritesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final list = jsonDecode(data) as List;
        final teams = list.map((e) => FavoriteTeam.fromJson(e)).toList();
        state = state.copyWith(teams: teams, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveFavoritesLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(state.teams.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  Future<void> addFavorite(FavoriteTeam team) async {
    if (state.teams.any((t) => t.id == team.id)) return;

    try {
      // Save to backend
      final result = await _api.addFavoriteTeam({
        'teamName': team.name,
        'teamLogo': team.logoUrl,
        'league': team.league,
        'sport': team.sport,
        'notificationsEnabled': team.notificationsEnabled,
      });

      final savedTeam = FavoriteTeam(
        id: result['id'] ?? team.id,
        name: team.name,
        sport: team.sport,
        league: team.league,
        logoUrl: team.logoUrl,
        notificationsEnabled: team.notificationsEnabled,
      );

      state = state.copyWith(teams: [...state.teams, savedTeam]);
      await _saveFavoritesLocally();
    } catch (e) {
      // Save locally if backend fails
      state = state.copyWith(teams: [...state.teams, team]);
      await _saveFavoritesLocally();
    }
  }

  Future<void> removeFavorite(String teamId) async {
    try {
      await _api.removeFavoriteTeam(teamId);
    } catch (_) {
      // Continue even if backend fails
    }

    state = state.copyWith(
        teams: state.teams.where((t) => t.id != teamId).toList());
    await _saveFavoritesLocally();
  }

  Future<void> toggleNotifications(String teamId) async {
    final teams = state.teams.map((t) {
      if (t.id == teamId) {
        return FavoriteTeam(
          id: t.id,
          name: t.name,
          sport: t.sport,
          league: t.league,
          logoUrl: t.logoUrl,
          notificationsEnabled: !t.notificationsEnabled,
        );
      }
      return t;
    }).toList();
    state = state.copyWith(teams: teams);
    await _saveFavoritesLocally();
  }

  bool isFavorite(String teamId) => state.teams.any((t) => t.id == teamId);

  Future<void> refresh() async {
    await _loadFavorites();
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>(
  (ref) => FavoritesNotifier(ref.watch(apiServiceProvider)),
);
