// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'infographic.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InfographicImpl _$$InfographicImplFromJson(Map<String, dynamic> json) =>
    _$InfographicImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      sourceId: json['sourceId'] as String,
      notebookId: json['notebookId'] as String,
      imageUrl: json['imageUrl'] as String?,
      imageBase64: json['imageBase64'] as String?,
      description: json['description'] as String?,
      style: $enumDecodeNullable(_$InfographicStyleEnumMap, json['style']) ??
          InfographicStyle.modern,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$InfographicImplToJson(_$InfographicImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'sourceId': instance.sourceId,
      'notebookId': instance.notebookId,
      'imageUrl': instance.imageUrl,
      'imageBase64': instance.imageBase64,
      'description': instance.description,
      'style': _$InfographicStyleEnumMap[instance.style]!,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$InfographicStyleEnumMap = {
  InfographicStyle.modern: 'modern',
  InfographicStyle.minimal: 'minimal',
  InfographicStyle.colorful: 'colorful',
  InfographicStyle.professional: 'professional',
  InfographicStyle.playful: 'playful',
};
