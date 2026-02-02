class ScheduledTask {
  final String id;
  final String userId;
  final String name;
  final String action;
  final String cron;
  final bool enabled;
  final String trigger;
  final int maxRetries;
  final int retryCount;
  final DateTime? lastRunAt;
  final String? lastRunStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ScheduledTask({
    required this.id,
    required this.userId,
    required this.name,
    required this.action,
    required this.cron,
    required this.enabled,
    required this.trigger,
    required this.maxRetries,
    required this.retryCount,
    this.lastRunAt,
    this.lastRunStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory ScheduledTask.fromJson(Map<String, dynamic> json) {
    return ScheduledTask(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      action: _stringFromJson(json['action']),
      cron: json['cron'],
      enabled: json['enabled'] ?? true,
      trigger: _stringFromJson(json['trigger'], defaultValue: 'cron'),
      maxRetries: json['max_retries'] ?? 3,
      retryCount: json['retry_count'] ?? 0,
      lastRunAt: json['last_run_at'] != null ? DateTime.parse(json['last_run_at']) : null,
      lastRunStatus: json['last_run_status'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'action': action,
      'cron': cron,
      'enabled': enabled,
      'trigger': trigger,
      'max_retries': maxRetries,
      'retry_count': retryCount,
      'last_run_at': lastRunAt?.toIso8601String(),
      'last_run_status': lastRunStatus,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

String _stringFromJson(dynamic value, {String defaultValue = ''}) {
  if (value == null) return defaultValue;
  if (value is String) return value;
  if (value is Map) {
    final dynamic type = value['type'];
    if (type is String) return type;
    return value.toString();
  }
  return value.toString();
}

class TaskExecution {
  final String id;
  final String taskId;
  final bool success;
  final dynamic output;
  final String? error;
  final int? duration;
  final DateTime executedAt;

  TaskExecution({
    required this.id,
    required this.taskId,
    required this.success,
    this.output,
    this.error,
    this.duration,
    required this.executedAt,
  });

  factory TaskExecution.fromJson(Map<String, dynamic> json) {
    return TaskExecution(
      id: json['id'],
      taskId: json['task_id'],
      success: json['success'],
      output: json['output'],
      error: json['error'],
      duration: json['duration'],
      executedAt: DateTime.parse(json['executed_at']),
    );
  }
}
