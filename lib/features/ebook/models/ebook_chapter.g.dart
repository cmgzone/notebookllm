// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ebook_chapter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EbookChapterImpl _$$EbookChapterImplFromJson(Map<String, dynamic> json) =>
    _$EbookChapterImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => EbookImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      orderIndex: (json['orderIndex'] as num).toInt(),
      isGenerating: json['isGenerating'] as bool? ?? false,
    );

Map<String, dynamic> _$$EbookChapterImplToJson(_$EbookChapterImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'images': instance.images,
      'orderIndex': instance.orderIndex,
      'isGenerating': instance.isGenerating,
    };
