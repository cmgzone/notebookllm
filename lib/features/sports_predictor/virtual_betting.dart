/// Virtual betting model for sports predictions
class VirtualBet {
  final String id;
  final String predictionId;
  final String matchTitle;
  final String betType; // 'home', 'draw', 'away', 'over25', 'under25', 'btts'
  final double odds;
  final double stake;
  final DateTime placedAt;
  final BetStatus status;
  final double? payout;

  VirtualBet({
    required this.id,
    required this.predictionId,
    required this.matchTitle,
    required this.betType,
    required this.odds,
    required this.stake,
    required this.placedAt,
    this.status = BetStatus.pending,
    this.payout,
  });

  double get potentialWin => stake * odds;

  VirtualBet copyWith({
    BetStatus? status,
    double? payout,
  }) {
    return VirtualBet(
      id: id,
      predictionId: predictionId,
      matchTitle: matchTitle,
      betType: betType,
      odds: odds,
      stake: stake,
      placedAt: placedAt,
      status: status ?? this.status,
      payout: payout ?? this.payout,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'predictionId': predictionId,
        'matchTitle': matchTitle,
        'betType': betType,
        'odds': odds,
        'stake': stake,
        'placedAt': placedAt.toIso8601String(),
        'status': status.name,
        'payout': payout,
      };

  factory VirtualBet.fromJson(Map<String, dynamic> json) {
    return VirtualBet(
      id: json['id'] ?? '',
      predictionId: json['predictionId'] ?? '',
      matchTitle: json['matchTitle'] ?? '',
      betType: json['betType'] ?? '',
      odds: (json['odds'] ?? 1.0).toDouble(),
      stake: (json['stake'] ?? 0.0).toDouble(),
      placedAt: DateTime.tryParse(json['placedAt'] ?? '') ?? DateTime.now(),
      status: BetStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => BetStatus.pending,
      ),
      payout: json['payout']?.toDouble(),
    );
  }
}

enum BetStatus {
  pending,
  won,
  lost,
  void_,
}

/// Betting slip item
class BetSlipItem {
  final String predictionId;
  final String matchTitle;
  final String homeTeam;
  final String awayTeam;
  final String betType;
  final String betLabel;
  final double odds;
  double stake;

  BetSlipItem({
    required this.predictionId,
    required this.matchTitle,
    required this.homeTeam,
    required this.awayTeam,
    required this.betType,
    required this.betLabel,
    required this.odds,
    this.stake = 10.0,
  });

  double get potentialWin => stake * odds;

  String get displayBetType {
    switch (betType) {
      case 'home':
        return '$homeTeam Win';
      case 'away':
        return '$awayTeam Win';
      case 'draw':
        return 'Draw';
      case 'over25':
        return 'Over 2.5 Goals';
      case 'under25':
        return 'Under 2.5 Goals';
      case 'btts':
        return 'Both Teams to Score';
      default:
        return betLabel;
    }
  }
}

/// Virtual wallet for betting
class VirtualWallet {
  final double balance;
  final double totalDeposited;
  final double totalWon;
  final double totalLost;
  final List<WalletTransaction> transactions;

  VirtualWallet({
    this.balance = 1000.0, // Start with 1000 virtual coins
    this.totalDeposited = 1000.0,
    this.totalWon = 0.0,
    this.totalLost = 0.0,
    this.transactions = const [],
  });

  VirtualWallet copyWith({
    double? balance,
    double? totalDeposited,
    double? totalWon,
    double? totalLost,
    List<WalletTransaction>? transactions,
  }) {
    return VirtualWallet(
      balance: balance ?? this.balance,
      totalDeposited: totalDeposited ?? this.totalDeposited,
      totalWon: totalWon ?? this.totalWon,
      totalLost: totalLost ?? this.totalLost,
      transactions: transactions ?? this.transactions,
    );
  }

  double get profitLoss => totalWon - totalLost;
  double get roi => totalLost > 0 ? (profitLoss / totalLost) * 100 : 0;

  Map<String, dynamic> toJson() => {
        'balance': balance,
        'totalDeposited': totalDeposited,
        'totalWon': totalWon,
        'totalLost': totalLost,
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };

  factory VirtualWallet.fromJson(Map<String, dynamic> json) {
    return VirtualWallet(
      balance: (json['balance'] ?? 1000.0).toDouble(),
      totalDeposited: (json['totalDeposited'] ?? 1000.0).toDouble(),
      totalWon: (json['totalWon'] ?? 0.0).toDouble(),
      totalLost: (json['totalLost'] ?? 0.0).toDouble(),
      transactions: (json['transactions'] as List?)
              ?.map((t) => WalletTransaction.fromJson(t))
              .toList() ??
          [],
    );
  }
}

class WalletTransaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime timestamp;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
      };

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.deposit,
      ),
      amount: (json['amount'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

enum TransactionType {
  deposit,
  withdrawal,
  betPlaced,
  betWon,
  betLost,
  bonus,
}
