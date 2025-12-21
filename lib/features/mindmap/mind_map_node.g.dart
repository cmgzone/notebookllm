// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mind_map_node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MindMapNodeImpl _$$MindMapNodeImplFromJson(Map<String, dynamic> json) =>
    _$MindMapNodeImpl(
      id: json['id'] as String,
      label: json['label'] as String,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => MindMapNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      level: (json['level'] as num?)?.toInt() ?? 0,
      colorValue: (json['colorValue'] as num?)?.toInt(),
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$MindMapNodeImplToJson(_$MindMapNodeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'children': instance.children,
      'level': instance.level,
      'colorValue': instance.colorValue,
      'x': instance.x,
      'y': instance.y,
    };

_$MindMapImpl _$$MindMapImplFromJson(Map<String, dynamic> json) =>
    _$MindMapImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      notebookId: json['notebookId'] as String,
      sourceId: json['sourceId'] as String?,
      rootNode: MindMapNode.fromJson(json['rootNode'] as Map<String, dynamic>),
      textContent: json['textContent'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$MindMapImplToJson(_$MindMapImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'notebookId': instance.notebookId,
      'sourceId': instance.sourceId,
      'rootNode': instance.rootNode,
      'textContent': instance.textContent,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
