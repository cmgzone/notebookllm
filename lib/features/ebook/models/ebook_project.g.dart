// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ebook_project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EbookProjectImpl _$$EbookProjectImplFromJson(Map<String, dynamic> json) =>
    _$EbookProjectImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      topic: json['topic'] as String,
      targetAudience: json['targetAudience'] as String,
      branding:
          BrandingConfig.fromJson(json['branding'] as Map<String, dynamic>),
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((e) => EbookChapter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      status: $enumDecodeNullable(_$EbookStatusEnumMap, json['status']) ??
          EbookStatus.draft,
      selectedModel: json['selectedModel'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      coverImageUrl: json['coverImageUrl'] as String?,
      notebookId: json['notebookId'] as String?,
      chapterAudioUrls: (json['chapterAudioUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      currentPhase: json['currentPhase'] as String? ?? 'Starting...',
      useDeepResearch: json['useDeepResearch'] as bool? ?? false,
      imageSource:
          $enumDecodeNullable(_$ImageSourceTypeEnumMap, json['imageSource']) ??
              ImageSourceType.aiGenerated,
      deepResearchSummary: json['deepResearchSummary'] as String?,
      webSearchedImages: (json['webSearchedImages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$EbookProjectImplToJson(_$EbookProjectImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'topic': instance.topic,
      'targetAudience': instance.targetAudience,
      'branding': instance.branding,
      'chapters': instance.chapters,
      'status': _$EbookStatusEnumMap[instance.status]!,
      'selectedModel': instance.selectedModel,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'coverImageUrl': instance.coverImageUrl,
      'notebookId': instance.notebookId,
      'chapterAudioUrls': instance.chapterAudioUrls,
      'currentPhase': instance.currentPhase,
      'useDeepResearch': instance.useDeepResearch,
      'imageSource': _$ImageSourceTypeEnumMap[instance.imageSource]!,
      'deepResearchSummary': instance.deepResearchSummary,
      'webSearchedImages': instance.webSearchedImages,
    };

const _$EbookStatusEnumMap = {
  EbookStatus.draft: 'draft',
  EbookStatus.generating: 'generating',
  EbookStatus.completed: 'completed',
  EbookStatus.error: 'error',
};

const _$ImageSourceTypeEnumMap = {
  ImageSourceType.aiGenerated: 'aiGenerated',
  ImageSourceType.webSearch: 'webSearch',
  ImageSourceType.both: 'both',
};
