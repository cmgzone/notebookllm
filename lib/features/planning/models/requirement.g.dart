// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'requirement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RequirementImpl _$$RequirementImplFromJson(Map<String, dynamic> json) =>
    _$RequirementImpl(
      id: json['id'] as String,
      planId: json['planId'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      earsPattern:
          $enumDecodeNullable(_$EarsPatternEnumMap, json['earsPattern']) ??
              EarsPattern.ubiquitous,
      acceptanceCriteria: (json['acceptanceCriteria'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$RequirementImplToJson(_$RequirementImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planId': instance.planId,
      'title': instance.title,
      'description': instance.description,
      'earsPattern': _$EarsPatternEnumMap[instance.earsPattern]!,
      'acceptanceCriteria': instance.acceptanceCriteria,
      'sortOrder': instance.sortOrder,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$EarsPatternEnumMap = {
  EarsPattern.ubiquitous: 'ubiquitous',
  EarsPattern.event: 'event',
  EarsPattern.state: 'state',
  EarsPattern.unwanted: 'unwanted',
  EarsPattern.optional: 'optional',
  EarsPattern.complex: 'complex',
};
