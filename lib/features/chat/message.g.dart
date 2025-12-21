// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessageImpl _$$MessageImplFromJson(Map<String, dynamic> json) =>
    _$MessageImpl(
      id: json['id'] as String,
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      citations: (json['citations'] as List<dynamic>?)
              ?.map((e) => Citation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      suggestedQuestions: (json['suggestedQuestions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      relatedSources: (json['relatedSources'] as List<dynamic>?)
              ?.map((e) => SourceSuggestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$MessageImplToJson(_$MessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'isUser': instance.isUser,
      'timestamp': instance.timestamp.toIso8601String(),
      'citations': instance.citations,
      'suggestedQuestions': instance.suggestedQuestions,
      'relatedSources': instance.relatedSources,
    };

_$CitationImpl _$$CitationImplFromJson(Map<String, dynamic> json) =>
    _$CitationImpl(
      id: json['id'] as String,
      sourceId: json['sourceId'] as String,
      snippet: json['snippet'] as String,
      start: (json['start'] as num).toInt(),
      end: (json['end'] as num).toInt(),
    );

Map<String, dynamic> _$$CitationImplToJson(_$CitationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sourceId': instance.sourceId,
      'snippet': instance.snippet,
      'start': instance.start,
      'end': instance.end,
    };

_$SourceSuggestionImpl _$$SourceSuggestionImplFromJson(
        Map<String, dynamic> json) =>
    _$SourceSuggestionImpl(
      title: json['title'] as String,
      url: json['url'] as String,
      type: json['type'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );

Map<String, dynamic> _$$SourceSuggestionImplToJson(
        _$SourceSuggestionImpl instance) =>
    <String, dynamic>{
      'title': instance.title,
      'url': instance.url,
      'type': instance.type,
      'thumbnailUrl': instance.thumbnailUrl,
    };
