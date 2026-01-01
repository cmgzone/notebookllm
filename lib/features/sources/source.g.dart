// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SourceImpl _$$SourceImplFromJson(Map<String, dynamic> json) => _$SourceImpl(
      id: json['id'] as String,
      notebookId: json['notebookId'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      content: json['content'] as String,
      summary: json['summary'] as String?,
      summaryGeneratedAt: json['summaryGeneratedAt'] == null
          ? null
          : DateTime.parse(json['summaryGeneratedAt'] as String),
      imageUrl: json['imageUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      tagIds: (json['tagIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$SourceImplToJson(_$SourceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'notebookId': instance.notebookId,
      'title': instance.title,
      'type': instance.type,
      'addedAt': instance.addedAt.toIso8601String(),
      'content': instance.content,
      'summary': instance.summary,
      'summaryGeneratedAt': instance.summaryGeneratedAt?.toIso8601String(),
      'imageUrl': instance.imageUrl,
      'thumbnailUrl': instance.thumbnailUrl,
      'tagIds': instance.tagIds,
    };
