// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artifact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ArtifactImpl _$$ArtifactImplFromJson(Map<String, dynamic> json) =>
    _$ArtifactImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      notebookId: json['notebookId'] as String?,
    );

Map<String, dynamic> _$$ArtifactImplToJson(_$ArtifactImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'type': instance.type,
      'content': instance.content,
      'createdAt': instance.createdAt.toIso8601String(),
      'notebookId': instance.notebookId,
    };
