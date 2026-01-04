import 'package:freezed_annotation/freezed_annotation.dart';
import 'requirement.dart';
import 'plan_task.dart';

part 'plan.freezed.dart';
part 'plan.g.dart';

/// Represents a plan status
enum PlanStatus {
  draft,
  active,
  completed,
  archived,
}

/// Represents a design note linked to requirements
@freezed
class DesignNote with _$DesignNote {
  const factory DesignNote({
    required String id,
    required String planId,
    @Default([]) List<String> requirementIds,
    required String content,
    required DateTime createdAt,
  }) = _DesignNote;

  factory DesignNote.fromJson(Map<String, dynamic> json) =>
      _$DesignNoteFromJson(json);

  factory DesignNote.fromBackendJson(Map<String, dynamic> json) => DesignNote(
        id: json['id'] as String? ?? '',
        planId: (json['planId'] ?? json['plan_id']) as String? ?? '',
        requirementIds: List<String>.from(
            json['requirementIds'] ?? json['requirement_ids'] ?? []),
        content: json['content'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : json['created_at'] != null
                ? DateTime.parse(json['created_at'] as String)
                : DateTime.now(),
      );
}

/// Represents agent access to a plan
@freezed
class AgentAccess with _$AgentAccess {
  const factory AgentAccess({
    required String id,
    required String planId,
    required String agentSessionId,
    String? agentName,
    @Default(['read']) List<String> permissions,
    required DateTime grantedAt,
    DateTime? revokedAt,
  }) = _AgentAccess;

  factory AgentAccess.fromJson(Map<String, dynamic> json) =>
      _$AgentAccessFromJson(json);

  factory AgentAccess.fromBackendJson(Map<String, dynamic> json) => AgentAccess(
        id: json['id'] as String? ?? '',
        planId: (json['planId'] ?? json['plan_id']) as String? ?? '',
        agentSessionId:
            (json['agentSessionId'] ?? json['agent_session_id']) as String? ??
                '',
        agentName: (json['agentName'] ?? json['agent_name']) as String?,
        permissions: List<String>.from(json['permissions'] ?? ['read']),
        grantedAt: json['grantedAt'] != null
            ? DateTime.parse(json['grantedAt'] as String)
            : json['granted_at'] != null
                ? DateTime.parse(json['granted_at'] as String)
                : DateTime.now(),
        revokedAt: json['revokedAt'] != null
            ? DateTime.parse(json['revokedAt'] as String)
            : json['revoked_at'] != null
                ? DateTime.parse(json['revoked_at'] as String)
                : null,
      );
}

/// Represents a structured plan with requirements, design, and tasks
/// Requirements: 1.1, 4.1
@freezed
class Plan with _$Plan {
  const factory Plan({
    required String id,
    required String userId,
    required String title,
    @Default('') String description,
    @Default(PlanStatus.draft) PlanStatus status,

    // Spec-driven structure (Requirements 4.1)
    @Default([]) List<Requirement> requirements,
    @Default([]) List<DesignNote> designNotes,
    @Default([]) List<PlanTask> tasks,

    // Access control (Requirements 7.1, 7.4)
    @Default(true) bool isPrivate,
    @Default([]) List<AgentAccess> sharedAgents,

    // Metadata
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? completedAt,
  }) = _Plan;

  const Plan._();

  factory Plan.fromJson(Map<String, dynamic> json) => _$PlanFromJson(json);

  factory Plan.fromBackendJson(Map<String, dynamic> json) {
    final requirementsList = json['requirements'] as List?;
    final designNotesList = json['designNotes'] ?? json['design_notes'];
    final tasksList = json['tasks'] as List?;
    final sharedAgentsList = json['sharedAgents'] ?? json['shared_agents'];

    return Plan(
      id: json['id'] as String? ?? '',
      userId: (json['userId'] ?? json['user_id']) as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: _parseStatus(json['status'] as String?),
      requirements: requirementsList != null
          ? requirementsList
              .map(
                  (r) => Requirement.fromBackendJson(r as Map<String, dynamic>))
              .toList()
          : <Requirement>[],
      designNotes: designNotesList != null && designNotesList is List
          ? designNotesList
              .map((d) => DesignNote.fromBackendJson(d as Map<String, dynamic>))
              .toList()
          : <DesignNote>[],
      tasks: tasksList != null
          ? tasksList
              .map((t) => PlanTask.fromBackendJson(t as Map<String, dynamic>))
              .toList()
          : <PlanTask>[],
      isPrivate: (json['isPrivate'] ?? json['is_private']) as bool? ?? true,
      sharedAgents: sharedAgentsList != null && sharedAgentsList is List
          ? sharedAgentsList
              .map(
                  (a) => AgentAccess.fromBackendJson(a as Map<String, dynamic>))
              .toList()
          : <AgentAccess>[],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : json['completed_at'] != null
              ? DateTime.parse(json['completed_at'] as String)
              : null,
    );
  }

  /// Convert to backend JSON format
  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'status': status.name,
        'is_private': isPrivate,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      };

  /// Calculate completion percentage (Requirements 8.1)
  int get completionPercentage {
    if (tasks.isEmpty) return 0;
    final completedCount =
        tasks.where((t) => t.status == TaskStatus.completed).length;
    return ((completedCount / tasks.length) * 100).round();
  }

  /// Get task count summary
  Map<TaskStatus, int> get taskStatusSummary {
    final summary = <TaskStatus, int>{};
    for (final status in TaskStatus.values) {
      summary[status] = tasks.where((t) => t.status == status).length;
    }
    return summary;
  }

  static PlanStatus _parseStatus(String? status) {
    switch (status) {
      case 'draft':
        return PlanStatus.draft;
      case 'active':
        return PlanStatus.active;
      case 'completed':
        return PlanStatus.completed;
      case 'archived':
        return PlanStatus.archived;
      default:
        return PlanStatus.draft;
    }
  }
}

/// Represents a point in the completion trend
/// Implements Requirement 8.1
class CompletionTrendPoint {
  final DateTime date;
  final int completedCount;

  CompletionTrendPoint({required this.date, required this.completedCount});

  factory CompletionTrendPoint.fromBackendJson(Map<String, dynamic> json) =>
      CompletionTrendPoint(
        date: DateTime.parse(json['date']),
        completedCount: json['completedCount'] ?? json['completed_count'] ?? 0,
      );
}

/// Represents analytics data for a plan
/// Implements Requirement 8.1: Progress Tracking and Analytics
class PlanAnalytics {
  final String planId;
  final int totalTasks;
  final int notStartedTasks;
  final int inProgressTasks;
  final int pausedTasks;
  final int blockedTasks;
  final int completedTasks;
  final int completionPercentage;
  final double totalTimeSpentSeconds;
  final List<CompletionTrendPoint> completionTrend;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  PlanAnalytics({
    required this.planId,
    required this.totalTasks,
    required this.notStartedTasks,
    required this.inProgressTasks,
    required this.pausedTasks,
    required this.blockedTasks,
    required this.completedTasks,
    required this.completionPercentage,
    required this.totalTimeSpentSeconds,
    required this.completionTrend,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory PlanAnalytics.fromBackendJson(Map<String, dynamic> json) {
    final taskSummary = json['taskSummary'] ?? json['task_summary'] ?? {};
    final trend = json['completionTrend'] ?? json['completion_trend'] ?? [];

    return PlanAnalytics(
      planId: json['planId'] ?? json['plan_id'] ?? '',
      totalTasks: taskSummary['total'] ?? 0,
      notStartedTasks:
          taskSummary['notStarted'] ?? taskSummary['not_started'] ?? 0,
      inProgressTasks:
          taskSummary['inProgress'] ?? taskSummary['in_progress'] ?? 0,
      pausedTasks: taskSummary['paused'] ?? 0,
      blockedTasks: taskSummary['blocked'] ?? 0,
      completedTasks: taskSummary['completed'] ?? 0,
      completionPercentage: json['completionPercentage'] ??
          json['completion_percentage'] ??
          taskSummary['completionPercentage'] ??
          taskSummary['completion_percentage'] ??
          0,
      totalTimeSpentSeconds: (json['totalTimeSpentSeconds'] ??
              json['total_time_spent_seconds'] ??
              0)
          .toDouble(),
      completionTrend: (trend as List)
          .map((t) =>
              CompletionTrendPoint.fromBackendJson(t as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      updatedAt: DateTime.parse(json['updatedAt'] ?? json['updated_at']),
      completedAt: json['completedAt'] != null || json['completed_at'] != null
          ? DateTime.parse(json['completedAt'] ?? json['completed_at'])
          : null,
    );
  }

  /// Get formatted time spent string
  String get formattedTimeSpent {
    final hours = (totalTimeSpentSeconds / 3600).floor();
    final minutes = ((totalTimeSpentSeconds % 3600) / 60).floor();
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
