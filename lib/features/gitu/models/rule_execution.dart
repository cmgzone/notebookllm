class RuleExecution {
  final String id;
  final bool matched;
  final bool success;
  final dynamic result;
  final String? error;
  final DateTime executedAt;

  RuleExecution({
    required this.id,
    required this.matched,
    required this.success,
    required this.result,
    required this.error,
    required this.executedAt,
  });

  factory RuleExecution.fromJson(Map<String, dynamic> json) {
    return RuleExecution(
      id: json['id'],
      matched: json['matched'] == true,
      success: json['success'] == true,
      result: json['result'],
      error: json['error'],
      executedAt: DateTime.parse(json['executed_at']),
    );
  }
}

