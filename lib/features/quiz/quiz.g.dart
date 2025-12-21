// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$QuizQuestionImpl _$$QuizQuestionImplFromJson(Map<String, dynamic> json) =>
    _$QuizQuestionImpl(
      id: json['id'] as String,
      question: json['question'] as String,
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      correctOptionIndex: (json['correctOptionIndex'] as num).toInt(),
      explanation: json['explanation'] as String?,
      hint: json['hint'] as String?,
    );

Map<String, dynamic> _$$QuizQuestionImplToJson(_$QuizQuestionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'question': instance.question,
      'options': instance.options,
      'correctOptionIndex': instance.correctOptionIndex,
      'explanation': instance.explanation,
      'hint': instance.hint,
    };

_$QuizImpl _$$QuizImplFromJson(Map<String, dynamic> json) => _$QuizImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      notebookId: json['notebookId'] as String,
      sourceId: json['sourceId'] as String?,
      questions: (json['questions'] as List<dynamic>)
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      timesAttempted: (json['timesAttempted'] as num?)?.toInt() ?? 0,
      bestScore: (json['bestScore'] as num?)?.toInt(),
      lastScore: (json['lastScore'] as num?)?.toInt(),
      lastAttemptedAt: json['lastAttemptedAt'] == null
          ? null
          : DateTime.parse(json['lastAttemptedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$QuizImplToJson(_$QuizImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'notebookId': instance.notebookId,
      'sourceId': instance.sourceId,
      'questions': instance.questions,
      'timesAttempted': instance.timesAttempted,
      'bestScore': instance.bestScore,
      'lastScore': instance.lastScore,
      'lastAttemptedAt': instance.lastAttemptedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_$QuizAttemptImpl _$$QuizAttemptImplFromJson(Map<String, dynamic> json) =>
    _$QuizAttemptImpl(
      id: json['id'] as String,
      quizId: json['quizId'] as String,
      userAnswers: (json['userAnswers'] as List<dynamic>)
          .map((e) => (e as num?)?.toInt())
          .toList(),
      score: (json['score'] as num).toInt(),
      totalQuestions: (json['totalQuestions'] as num).toInt(),
      timeTaken: Duration(microseconds: (json['timeTaken'] as num).toInt()),
      completedAt: DateTime.parse(json['completedAt'] as String),
    );

Map<String, dynamic> _$$QuizAttemptImplToJson(_$QuizAttemptImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'quizId': instance.quizId,
      'userAnswers': instance.userAnswers,
      'score': instance.score,
      'totalQuestions': instance.totalQuestions,
      'timeTaken': instance.timeTaken.inMicroseconds,
      'completedAt': instance.completedAt.toIso8601String(),
    };
