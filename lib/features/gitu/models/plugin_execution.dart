class PluginExecution {
  final String id;
  final bool success;
  final int durationMs;
  final dynamic result;
  final String? error;
  final List<String> logs;
  final DateTime executedAt;

  PluginExecution({
    required this.id,
    required this.success,
    required this.durationMs,
    required this.result,
    required this.error,
    required this.logs,
    required this.executedAt,
  });

  factory PluginExecution.fromJson(Map<String, dynamic> json) {
    final rawLogs = json['logs'];
    return PluginExecution(
      id: json['id'],
      success: json['success'] == true,
      durationMs: json['duration_ms'] ?? json['durationMs'] ?? 0,
      result: json['result'],
      error: json['error'],
      logs: (rawLogs is List ? rawLogs : const []).map((e) => '$e').toList(),
      executedAt: DateTime.parse(json['executed_at'] ?? json['executedAt']),
    );
  }
}

