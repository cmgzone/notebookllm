// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ebook_image.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EbookImageImpl _$$EbookImageImplFromJson(Map<String, dynamic> json) =>
    _$EbookImageImpl(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      url: json['url'] as String,
      caption: json['caption'] as String? ?? '',
      type: json['type'] as String? ?? 'generated',
    );

Map<String, dynamic> _$$EbookImageImplToJson(_$EbookImageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'prompt': instance.prompt,
      'url': instance.url,
      'caption': instance.caption,
      'type': instance.type,
    };
