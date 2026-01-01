// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notebook.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotebookImpl _$$NotebookImplFromJson(Map<String, dynamic> json) =>
    _$NotebookImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      coverImage: json['coverImage'] as String?,
      sourceCount: (json['sourceCount'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isAgentNotebook: json['isAgentNotebook'] as bool? ?? false,
      agentSessionId: json['agentSessionId'] as String?,
      agentName: json['agentName'] as String?,
      agentIdentifier: json['agentIdentifier'] as String?,
      agentStatus: json['agentStatus'] as String? ?? 'active',
    );

Map<String, dynamic> _$$NotebookImplToJson(_$NotebookImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'description': instance.description,
      'coverImage': instance.coverImage,
      'sourceCount': instance.sourceCount,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'isAgentNotebook': instance.isAgentNotebook,
      'agentSessionId': instance.agentSessionId,
      'agentName': instance.agentName,
      'agentIdentifier': instance.agentIdentifier,
      'agentStatus': instance.agentStatus,
    };
