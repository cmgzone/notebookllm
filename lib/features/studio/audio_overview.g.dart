// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_overview.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AudioOverviewImpl _$$AudioOverviewImplFromJson(Map<String, dynamic> json) =>
    _$AudioOverviewImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      duration: Duration(microseconds: (json['duration'] as num).toInt()),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isOffline: json['isOffline'] as bool? ?? false,
    );

Map<String, dynamic> _$$AudioOverviewImplToJson(_$AudioOverviewImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'url': instance.url,
      'duration': instance.duration.inMicroseconds,
      'createdAt': instance.createdAt.toIso8601String(),
      'isOffline': instance.isOffline,
    };
