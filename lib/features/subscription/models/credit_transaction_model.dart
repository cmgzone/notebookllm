class CreditTransactionModel {
  final String id;
  final String userId;
  final int amount;
  final String
      transactionType; // purchase, monthly_renewal, consumption, admin_adjustment
  final String? description;
  final int balanceAfter;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  CreditTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.transactionType,
    this.description,
    required this.balanceAfter,
    required this.createdAt,
    this.metadata,
  });

  factory CreditTransactionModel.fromJson(Map<String, dynamic> json) {
    return CreditTransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: _parseInt(json['amount']) ?? 0,
      transactionType: json['transaction_type'] as String,
      description: json['description'] as String?,
      balanceAfter: _parseInt(json['balance_after']) ?? 0,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'transaction_type': transactionType,
      'description': description,
      'balance_after': balanceAfter,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;
}
