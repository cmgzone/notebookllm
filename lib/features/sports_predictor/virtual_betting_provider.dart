import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'virtual_betting.dart';
import 'prediction.dart';

final virtualBettingProvider =
    StateNotifierProvider<VirtualBettingNotifier, VirtualBettingState>((ref) {
  return VirtualBettingNotifier();
});

class VirtualBettingState {
  final VirtualWallet wallet;
  final List<BetSlipItem> betSlip;
  final List<VirtualBet> activeBets;
  final List<VirtualBet> betHistory;
  final bool isLoading;

  VirtualBettingState({
    VirtualWallet? wallet,
    this.betSlip = const [],
    this.activeBets = const [],
    this.betHistory = const [],
    this.isLoading = false,
  }) : wallet = wallet ?? VirtualWallet();

  VirtualBettingState copyWith({
    VirtualWallet? wallet,
    List<BetSlipItem>? betSlip,
    List<VirtualBet>? activeBets,
    List<VirtualBet>? betHistory,
    bool? isLoading,
  }) {
    return VirtualBettingState(
      wallet: wallet ?? this.wallet,
      betSlip: betSlip ?? this.betSlip,
      activeBets: activeBets ?? this.activeBets,
      betHistory: betHistory ?? this.betHistory,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  double get totalStake => betSlip.fold(0, (sum, item) => sum + item.stake);
  double get totalPotentialWin =>
      betSlip.fold(0, (sum, item) => sum + item.potentialWin);

  // Accumulator odds (multiply all odds)
  double get accumulatorOdds =>
      betSlip.fold(1.0, (product, item) => product * item.odds);
  double get accumulatorPotentialWin => totalStake * accumulatorOdds;
}

class VirtualBettingNotifier extends StateNotifier<VirtualBettingState> {
  VirtualBettingNotifier() : super(VirtualBettingState()) {
    _loadData();
  }

  static const _walletKey = 'virtual_wallet';
  static const _betsKey = 'virtual_bets';
  static const _historyKey = 'bet_history';

  Future<void> _loadData() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load wallet
      final walletJson = prefs.getString(_walletKey);
      VirtualWallet wallet = VirtualWallet();
      if (walletJson != null) {
        wallet = VirtualWallet.fromJson(jsonDecode(walletJson));
      }

      // Load active bets
      final betsJson = prefs.getString(_betsKey);
      List<VirtualBet> activeBets = [];
      if (betsJson != null) {
        final List<dynamic> parsed = jsonDecode(betsJson);
        activeBets = parsed.map((b) => VirtualBet.fromJson(b)).toList();
      }

      // Load history
      final historyJson = prefs.getString(_historyKey);
      List<VirtualBet> history = [];
      if (historyJson != null) {
        final List<dynamic> parsed = jsonDecode(historyJson);
        history = parsed.map((b) => VirtualBet.fromJson(b)).toList();
      }

      state = state.copyWith(
        wallet: wallet,
        activeBets: activeBets,
        betHistory: history,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_walletKey, jsonEncode(state.wallet.toJson()));
    await prefs.setString(
        _betsKey, jsonEncode(state.activeBets.map((b) => b.toJson()).toList()));
    await prefs.setString(_historyKey,
        jsonEncode(state.betHistory.map((b) => b.toJson()).toList()));
  }

  /// Add bet to slip
  void addToBetSlip(SportsPrediction prediction, String betType, double odds) {
    // Check if already in slip
    if (state.betSlip
        .any((b) => b.predictionId == prediction.id && b.betType == betType)) {
      return;
    }

    final item = BetSlipItem(
      predictionId: prediction.id,
      matchTitle: '${prediction.homeTeam} vs ${prediction.awayTeam}',
      homeTeam: prediction.homeTeam,
      awayTeam: prediction.awayTeam,
      betType: betType,
      betLabel: _getBetLabel(betType, prediction),
      odds: odds,
    );

    state = state.copyWith(betSlip: [...state.betSlip, item]);
  }

  String _getBetLabel(String betType, SportsPrediction prediction) {
    switch (betType) {
      case 'home':
        return '${prediction.homeTeam} Win';
      case 'away':
        return '${prediction.awayTeam} Win';
      case 'draw':
        return 'Draw';
      case 'over25':
        return 'Over 2.5 Goals';
      case 'under25':
        return 'Under 2.5 Goals';
      case 'btts':
        return 'Both Teams to Score';
      default:
        return betType;
    }
  }

  /// Remove from bet slip
  void removeFromBetSlip(String predictionId, String betType) {
    state = state.copyWith(
      betSlip: state.betSlip
          .where(
              (b) => !(b.predictionId == predictionId && b.betType == betType))
          .toList(),
    );
  }

  /// Update stake for a bet
  void updateStake(String predictionId, String betType, double stake) {
    state = state.copyWith(
      betSlip: state.betSlip.map((b) {
        if (b.predictionId == predictionId && b.betType == betType) {
          b.stake = stake;
        }
        return b;
      }).toList(),
    );
  }

  /// Clear bet slip
  void clearBetSlip() {
    state = state.copyWith(betSlip: []);
  }

  /// Place all bets in slip
  Future<bool> placeBets() async {
    if (state.betSlip.isEmpty) return false;
    if (state.totalStake > state.wallet.balance) return false;

    final newBets = <VirtualBet>[];
    final transactions = <WalletTransaction>[];

    for (final item in state.betSlip) {
      final bet = VirtualBet(
        id: DateTime.now().millisecondsSinceEpoch.toString() +
            item.predictionId,
        predictionId: item.predictionId,
        matchTitle: item.matchTitle,
        betType: item.betType,
        odds: item.odds,
        stake: item.stake,
        placedAt: DateTime.now(),
      );
      newBets.add(bet);

      transactions.add(WalletTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: TransactionType.betPlaced,
        amount: -item.stake,
        description: '${item.displayBetType} @ ${item.odds.toStringAsFixed(2)}',
        timestamp: DateTime.now(),
      ));
    }

    final newWallet = state.wallet.copyWith(
      balance: state.wallet.balance - state.totalStake,
      transactions: [...state.wallet.transactions, ...transactions],
    );

    state = state.copyWith(
      wallet: newWallet,
      activeBets: [...state.activeBets, ...newBets],
      betSlip: [],
    );

    await _saveData();
    return true;
  }

  /// Settle a bet (for demo/simulation)
  Future<void> settleBet(String betId, bool won) async {
    final betIndex = state.activeBets.indexWhere((b) => b.id == betId);
    if (betIndex == -1) return;

    final bet = state.activeBets[betIndex];
    final payout = won ? bet.potentialWin : 0.0;

    final settledBet = bet.copyWith(
      status: won ? BetStatus.won : BetStatus.lost,
      payout: payout,
    );

    final transaction = WalletTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: won ? TransactionType.betWon : TransactionType.betLost,
      amount: won ? payout : 0,
      description: '${bet.matchTitle} - ${won ? "Won" : "Lost"} ${bet.betType}',
      timestamp: DateTime.now(),
    );

    final newWallet = state.wallet.copyWith(
      balance: state.wallet.balance + payout,
      totalWon: state.wallet.totalWon + (won ? payout : 0),
      totalLost: state.wallet.totalLost + (won ? 0 : bet.stake),
      transactions: [...state.wallet.transactions, transaction],
    );

    final newActiveBets = List<VirtualBet>.from(state.activeBets);
    newActiveBets.removeAt(betIndex);

    state = state.copyWith(
      wallet: newWallet,
      activeBets: newActiveBets,
      betHistory: [settledBet, ...state.betHistory],
    );

    await _saveData();
  }

  /// Add bonus coins
  Future<void> addBonus(double amount, String reason) async {
    final transaction = WalletTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: TransactionType.bonus,
      amount: amount,
      description: reason,
      timestamp: DateTime.now(),
    );

    final newWallet = state.wallet.copyWith(
      balance: state.wallet.balance + amount,
      totalDeposited: state.wallet.totalDeposited + amount,
      transactions: [...state.wallet.transactions, transaction],
    );

    state = state.copyWith(wallet: newWallet);
    await _saveData();
  }

  /// Reset wallet (for demo)
  Future<void> resetWallet() async {
    state = state.copyWith(
      wallet: VirtualWallet(),
      activeBets: [],
      betHistory: [],
      betSlip: [],
    );
    await _saveData();
  }
}
