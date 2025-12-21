// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FlashcardImpl _$$FlashcardImplFromJson(Map<String, dynamic> json) =>
    _$FlashcardImpl(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      notebookId: json['notebookId'] as String,
      sourceId: json['sourceId'] as String?,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      timesReviewed: (json['timesReviewed'] as num?)?.toInt() ?? 0,
      timesCorrect: (json['timesCorrect'] as num?)?.toInt() ?? 0,
      lastReviewedAt: json['lastReviewedAt'] == null
          ? null
          : DateTime.parse(json['lastReviewedAt'] as String),
      nextReviewAt: json['nextReviewAt'] == null
          ? null
          : DateTime.parse(json['nextReviewAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$FlashcardImplToJson(_$FlashcardImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'question': instance.question,
      'answer': instance.answer,
      'notebookId': instance.notebookId,
      'sourceId': instance.sourceId,
      'difficulty': instance.difficulty,
      'timesReviewed': instance.timesReviewed,
      'timesCorrect': instance.timesCorrect,
      'lastReviewedAt': instance.lastReviewedAt?.toIso8601String(),
      'nextReviewAt': instance.nextReviewAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

_$FlashcardDeckImpl _$$FlashcardDeckImplFromJson(Map<String, dynamic> json) =>
    _$FlashcardDeckImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      notebookId: json['notebookId'] as String,
      sourceId: json['sourceId'] as String?,
      cards: (json['cards'] as List<dynamic>?)
              ?.map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$FlashcardDeckImplToJson(_$FlashcardDeckImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'notebookId': instance.notebookId,
      'sourceId': instance.sourceId,
      'cards': instance.cards,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
