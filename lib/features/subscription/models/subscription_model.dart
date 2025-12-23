import 'dart:developer' as developer;

class SubscriptionModel {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final int currentCredits;
  final int creditsConsumedThisMonth;
  final DateTime? lastRenewalDate;
  final DateTime? nextRenewalDate;
  final String status; // active, suspended, cancelled
  final int creditsPerMonth;
  final double planPrice;
  final bool isFreePlan;

  SubscriptionModel({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.currentCredits,
    required this.creditsConsumedThisMonth,
    this.lastRenewalDate,
    this.nextRenewalDate,
    required this.status,
    required this.creditsPerMonth,
    required this.planPrice,
    required this.isFreePlan,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    developer.log('[SUB_MODEL] Parsing JSON: $json', name: 'SubscriptionModel');

    try {
      final model = SubscriptionModel(
        id: _parseString(json['id']) ?? '',
        userId: _parseString(json['user_id']) ?? '',
        planId: _parseString(json['plan_id']) ?? '',
        planName: _parseString(json['plan_name']) ?? 'Free Plan',
        currentCredits: _parseInt(json['current_credits']) ?? 0,
        creditsConsumedThisMonth:
            _parseInt(json['credits_consumed_this_month']) ?? 0,
        lastRenewalDate: _parseDate(json['last_renewal_date']),
        nextRenewalDate: _parseDate(json['next_renewal_date']),
        status: _parseString(json['status']) ?? 'active',
        creditsPerMonth: _parseInt(json['credits_per_month']) ?? 30,
        planPrice: _parseDouble(json['plan_price']) ?? 0.0,
        isFreePlan: _parseBool(json['is_free_plan']) ?? false,
      );

      developer.log(
          '[SUB_MODEL] Parsed successfully: ${model.planName}, credits: ${model.currentCredits}',
          name: 'SubscriptionModel');
      return model;
    } catch (e, stack) {
      developer.log('[SUB_MODEL] Error parsing: $e',
          name: 'SubscriptionModel', error: e, stackTrace: stack);
      rethrow;
    }
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value != 0;
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
      'plan_id': planId,
      'plan_name': planName,
      'current_credits': currentCredits,
      'credits_consumed_this_month': creditsConsumedThisMonth,
      'last_renewal_date': lastRenewalDate?.toIso8601String(),
      'next_renewal_date': nextRenewalDate?.toIso8601String(),
      'status': status,
      'credits_per_month': creditsPerMonth,
      'plan_price': planPrice,
      'is_free_plan': isFreePlan,
    };
  }

  SubscriptionModel copyWith({
    String? id,
    String? userId,
    String? planId,
    String? planName,
    int? currentCredits,
    int? creditsConsumedThisMonth,
    DateTime? lastRenewalDate,
    DateTime? nextRenewalDate,
    String? status,
    int? creditsPerMonth,
    double? planPrice,
    bool? isFreePlan,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      currentCredits: currentCredits ?? this.currentCredits,
      creditsConsumedThisMonth:
          creditsConsumedThisMonth ?? this.creditsConsumedThisMonth,
      lastRenewalDate: lastRenewalDate ?? this.lastRenewalDate,
      nextRenewalDate: nextRenewalDate ?? this.nextRenewalDate,
      status: status ?? this.status,
      creditsPerMonth: creditsPerMonth ?? this.creditsPerMonth,
      planPrice: planPrice ?? this.planPrice,
      isFreePlan: isFreePlan ?? this.isFreePlan,
    );
  }
}
