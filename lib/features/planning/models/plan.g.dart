// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DesignNoteImpl _$$DesignNoteImplFromJson(Map<String, dynamic> json) =>
    _$DesignNoteImpl(
      id: json['id'] as String,
      planId: json['planId'] as String,
      requirementIds: (json['requirementIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$DesignNoteImplToJson(_$DesignNoteImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planId': instance.planId,
      'requirementIds': instance.requirementIds,
      'content': instance.content,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_$AgentAccessImpl _$$AgentAccessImplFromJson(Map<String, dynamic> json) =>
    _$AgentAccessImpl(
      id: json['id'] as String,
      planId: json['planId'] as String,
      agentSessionId: json['agentSessionId'] as String,
      agentName: json['agentName'] as String?,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['read'],
      grantedAt: DateTime.parse(json['grantedAt'] as String),
      revokedAt: json['revokedAt'] == null
          ? null
          : DateTime.parse(json['revokedAt'] as String),
    );

Map<String, dynamic> _$$AgentAccessImplToJson(_$AgentAccessImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planId': instance.planId,
      'agentSessionId': instance.agentSessionId,
      'agentName': instance.agentName,
      'permissions': instance.permissions,
      'grantedAt': instance.grantedAt.toIso8601String(),
      'revokedAt': instance.revokedAt?.toIso8601String(),
    };

_$PlanImpl _$$PlanImplFromJson(Map<String, dynamic> json) => _$PlanImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: $enumDecodeNullable(_$PlanStatusEnumMap, json['status']) ??
          PlanStatus.draft,
      requirements: (json['requirements'] as List<dynamic>?)
              ?.map((e) => Requirement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      designNotes: (json['designNotes'] as List<dynamic>?)
              ?.map((e) => DesignNote.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) => PlanTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isPrivate: json['isPrivate'] as bool? ?? true,
      sharedAgents: (json['sharedAgents'] as List<dynamic>?)
              ?.map((e) => AgentAccess.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isPublic: json['isPublic'] as bool? ?? false,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );

Map<String, dynamic> _$$PlanImplToJson(_$PlanImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'description': instance.description,
      'status': _$PlanStatusEnumMap[instance.status]!,
      'requirements': instance.requirements,
      'designNotes': instance.designNotes,
      'tasks': instance.tasks,
      'isPrivate': instance.isPrivate,
      'sharedAgents': instance.sharedAgents,
      'isPublic': instance.isPublic,
      'viewCount': instance.viewCount,
      'shareCount': instance.shareCount,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
    };

const _$PlanStatusEnumMap = {
  PlanStatus.draft: 'draft',
  PlanStatus.active: 'active',
  PlanStatus.completed: 'completed',
  PlanStatus.archived: 'archived',
};
