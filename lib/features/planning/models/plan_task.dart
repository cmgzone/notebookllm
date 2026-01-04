import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan_task.freezed.dart';
part 'plan_task.g.dart';

/// Task status values (Requirements 3.1)
enum TaskStatus {
  notStarted,
  inProgress,
  paused,
  blocked,
  completed,
}

/// Task priority levels
enum TaskPriority {
  low,
  medium,
  high,
  critical,
}

/// Represents a status change in task history (Requirements 3.2)
@freezed
class StatusChange with _$StatusChange {
  const factory StatusChange({
    required TaskStatus status,
    required DateTime changedAt,
    required String changedBy, // userId or agentId
    String? reason,
  }) = _StatusChange;

  factory StatusChange.fromJson(Map<String, dynamic> json) =>
      _$StatusChangeFromJson(json);

  factory StatusChange.fromBackendJson(Map<String, dynamic> json) =>
      StatusChange(
        status: _parseTaskStatus(json['status']),
        changedAt: DateTime.parse(json['changed_at']),
        changedBy: json['changed_by'],
        reason: json['reason'],
      );
}

/// Represents output from a coding agent (Requirements 5.6)
@freezed
class AgentOutput with _$AgentOutput {
  const factory AgentOutput({
    required String id,
    required String taskId,
    String? agentSessionId,
    String? agentName,
    required String outputType, // 'comment', 'code', 'file', 'completion'
    required String content,
    @Default({}) Map<String, dynamic> metadata,
    required DateTime createdAt,
  }) = _AgentOutput;

  factory AgentOutput.fromJson(Map<String, dynamic> json) =>
      _$AgentOutputFromJson(json);

  factory AgentOutput.fromBackendJson(Map<String, dynamic> json) => AgentOutput(
        id: json['id'],
        taskId: json['task_id'],
        agentSessionId: json['agent_session_id'],
        agentName: json['agent_name'],
        outputType: json['output_type'],
        content: json['content'],
        metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
        createdAt: DateTime.parse(json['created_at']),
      );
}

/// Represents a task within a plan (Requirements 3.1)
@freezed
class PlanTask with _$PlanTask {
  const factory PlanTask({
    required String id,
    required String planId,
    String? parentTaskId, // For sub-tasks
    @Default([]) List<String> requirementIds, // Links to requirements (4.4)

    required String title,
    @Default('') String description,
    @Default(TaskStatus.notStarted) TaskStatus status,
    @Default(TaskPriority.medium) TaskPriority priority,

    // Agent tracking
    String? assignedAgentId,
    @Default([]) List<AgentOutput> agentOutputs,
    @Default(0) int timeSpentMinutes,

    // Status tracking (Requirements 3.2)
    @Default([]) List<StatusChange> statusHistory,
    String? blockingReason, // Required when status is blocked (3.6)

    // Hierarchy
    @Default([]) List<PlanTask> subTasks,

    // Timestamps
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? completedAt,
  }) = _PlanTask;

  const PlanTask._();

  factory PlanTask.fromJson(Map<String, dynamic> json) =>
      _$PlanTaskFromJson(json);

  factory PlanTask.fromBackendJson(Map<String, dynamic> json) => PlanTask(
        id: json['id'],
        planId: json['plan_id'],
        parentTaskId: json['parent_task_id'],
        requirementIds: List<String>.from(json['requirement_ids'] ?? []),
        title: json['title'],
        description: json['description'] ?? '',
        status: _parseTaskStatus(json['status']),
        priority: _parseTaskPriority(json['priority']),
        assignedAgentId: json['assigned_agent_id'],
        agentOutputs: (json['agent_outputs'] as List? ?? [])
            .map((o) => AgentOutput.fromBackendJson(o as Map<String, dynamic>))
            .toList(),
        timeSpentMinutes: json['time_spent_minutes'] ?? 0,
        statusHistory: (json['status_history'] as List? ?? [])
            .map((s) => StatusChange.fromBackendJson(s as Map<String, dynamic>))
            .toList(),
        blockingReason: json['blocking_reason'],
        subTasks: (json['sub_tasks'] as List? ?? [])
            .map((t) => PlanTask.fromBackendJson(t as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
      );

  /// Convert to backend JSON format
  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'plan_id': planId,
        if (parentTaskId != null) 'parent_task_id': parentTaskId,
        'requirement_ids': requirementIds,
        'title': title,
        'description': description,
        'status': _statusToString(status),
        'priority': priority.name,
        if (assignedAgentId != null) 'assigned_agent_id': assignedAgentId,
        'time_spent_minutes': timeSpentMinutes,
        if (blockingReason != null) 'blocking_reason': blockingReason,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      };

  /// Check if task is blocked
  bool get isBlocked => status == TaskStatus.blocked;

  /// Check if task is completed
  bool get isCompleted => status == TaskStatus.completed;

  /// Check if task is in progress
  bool get isInProgress => status == TaskStatus.inProgress;

  /// Check if task has sub-tasks
  bool get hasSubTasks => subTasks.isNotEmpty;

  /// Get completion percentage for sub-tasks
  int get subTaskCompletionPercentage {
    if (subTasks.isEmpty) return isCompleted ? 100 : 0;
    final completedCount =
        subTasks.where((t) => t.status == TaskStatus.completed).length;
    return ((completedCount / subTasks.length) * 100).round();
  }

  /// Check if all sub-tasks are completed (Requirements 3.5)
  bool get allSubTasksCompleted {
    if (subTasks.isEmpty) return true;
    return subTasks.every((t) => t.status == TaskStatus.completed);
  }

  static String _statusToString(TaskStatus status) {
    switch (status) {
      case TaskStatus.notStarted:
        return 'not_started';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.paused:
        return 'paused';
      case TaskStatus.blocked:
        return 'blocked';
      case TaskStatus.completed:
        return 'completed';
    }
  }
}

TaskStatus _parseTaskStatus(String? status) {
  switch (status) {
    case 'not_started':
      return TaskStatus.notStarted;
    case 'in_progress':
      return TaskStatus.inProgress;
    case 'paused':
      return TaskStatus.paused;
    case 'blocked':
      return TaskStatus.blocked;
    case 'completed':
      return TaskStatus.completed;
    default:
      return TaskStatus.notStarted;
  }
}

TaskPriority _parseTaskPriority(String? priority) {
  switch (priority) {
    case 'low':
      return TaskPriority.low;
    case 'medium':
      return TaskPriority.medium;
    case 'high':
      return TaskPriority.high;
    case 'critical':
      return TaskPriority.critical;
    default:
      return TaskPriority.medium;
  }
}
