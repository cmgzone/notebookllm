// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StatusChangeImpl _$$StatusChangeImplFromJson(Map<String, dynamic> json) =>
    _$StatusChangeImpl(
      status: $enumDecode(_$TaskStatusEnumMap, json['status']),
      changedAt: DateTime.parse(json['changedAt'] as String),
      changedBy: json['changedBy'] as String,
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$$StatusChangeImplToJson(_$StatusChangeImpl instance) =>
    <String, dynamic>{
      'status': _$TaskStatusEnumMap[instance.status]!,
      'changedAt': instance.changedAt.toIso8601String(),
      'changedBy': instance.changedBy,
      'reason': instance.reason,
    };

const _$TaskStatusEnumMap = {
  TaskStatus.notStarted: 'notStarted',
  TaskStatus.inProgress: 'inProgress',
  TaskStatus.paused: 'paused',
  TaskStatus.blocked: 'blocked',
  TaskStatus.completed: 'completed',
};

_$AgentOutputImpl _$$AgentOutputImplFromJson(Map<String, dynamic> json) =>
    _$AgentOutputImpl(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      agentSessionId: json['agentSessionId'] as String?,
      agentName: json['agentName'] as String?,
      outputType: json['outputType'] as String,
      content: json['content'] as String,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$AgentOutputImplToJson(_$AgentOutputImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'taskId': instance.taskId,
      'agentSessionId': instance.agentSessionId,
      'agentName': instance.agentName,
      'outputType': instance.outputType,
      'content': instance.content,
      'metadata': instance.metadata,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_$PlanTaskImpl _$$PlanTaskImplFromJson(Map<String, dynamic> json) =>
    _$PlanTaskImpl(
      id: json['id'] as String,
      planId: json['planId'] as String,
      parentTaskId: json['parentTaskId'] as String?,
      requirementIds: (json['requirementIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: $enumDecodeNullable(_$TaskStatusEnumMap, json['status']) ??
          TaskStatus.notStarted,
      priority: $enumDecodeNullable(_$TaskPriorityEnumMap, json['priority']) ??
          TaskPriority.medium,
      assignedAgentId: json['assignedAgentId'] as String?,
      agentOutputs: (json['agentOutputs'] as List<dynamic>?)
              ?.map((e) => AgentOutput.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      timeSpentMinutes: (json['timeSpentMinutes'] as num?)?.toInt() ?? 0,
      statusHistory: (json['statusHistory'] as List<dynamic>?)
              ?.map((e) => StatusChange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      blockingReason: json['blockingReason'] as String?,
      subTasks: (json['subTasks'] as List<dynamic>?)
              ?.map((e) => PlanTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );

Map<String, dynamic> _$$PlanTaskImplToJson(_$PlanTaskImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planId': instance.planId,
      'parentTaskId': instance.parentTaskId,
      'requirementIds': instance.requirementIds,
      'title': instance.title,
      'description': instance.description,
      'status': _$TaskStatusEnumMap[instance.status]!,
      'priority': _$TaskPriorityEnumMap[instance.priority]!,
      'assignedAgentId': instance.assignedAgentId,
      'agentOutputs': instance.agentOutputs,
      'timeSpentMinutes': instance.timeSpentMinutes,
      'statusHistory': instance.statusHistory,
      'blockingReason': instance.blockingReason,
      'subTasks': instance.subTasks,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
    };

const _$TaskPriorityEnumMap = {
  TaskPriority.low: 'low',
  TaskPriority.medium: 'medium',
  TaskPriority.high: 'high',
  TaskPriority.critical: 'critical',
};
