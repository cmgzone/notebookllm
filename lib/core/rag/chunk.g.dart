// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chunk.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChunkImpl _$$ChunkImplFromJson(Map<String, dynamic> json) => _$ChunkImpl(
      id: json['id'] as String,
      sourceId: json['sourceId'] as String,
      text: json['text'] as String,
      start: (json['start'] as num).toInt(),
      end: (json['end'] as num).toInt(),
      embedding: (json['embedding'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );

Map<String, dynamic> _$$ChunkImplToJson(_$ChunkImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sourceId': instance.sourceId,
      'text': instance.text,
      'start': instance.start,
      'end': instance.end,
      'embedding': instance.embedding,
    };
