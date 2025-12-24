import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'quiz.freezed.dart';
part 'quiz.g.dart';

/// Represents a single quiz question with multiple choice options
@freezed
class QuizQuestion with _$QuizQuestion {
  const factory QuizQuestion({
    required String id,
    required String question,
    required List<String> options,
    required int correctOptionIndex,
    String? explanation,
    String? hint,
  }) = _QuizQuestion;

  const QuizQuestion._();

  factory QuizQuestion.fromBackendJson(Map<String, dynamic> json) {
    dynamic optionsRaw = json['options'];
    List<String> optionsList = [];
    if (optionsRaw is String) {
      optionsList = List<String>.from(jsonDecode(optionsRaw));
    } else if (optionsRaw is List) {
      optionsList = List<String>.from(optionsRaw);
    }

    return QuizQuestion(
      id: json['id'],
      question: json['question'],
      options: optionsList,
      correctOptionIndex: json['correct_option_index'] ?? 0,
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'question': question,
        'options': options,
        'correctOptionIndex': correctOptionIndex,
        'explanation': explanation,
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) =>
      _$QuizQuestionFromJson(json);
}

/// Represents a complete quiz with multiple questions
@freezed
class Quiz with _$Quiz {
  const factory Quiz({
    required String id,
    required String title,
    required String notebookId,
    String? sourceId,
    required List<QuizQuestion> questions,
    @Default(0) int timesAttempted,
    int? bestScore,
    int? lastScore,
    DateTime? lastAttemptedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Quiz;

  const Quiz._();

  factory Quiz.fromBackendJson(Map<String, dynamic> json) => Quiz(
        id: json['id'],
        title: json['title'],
        notebookId: json['notebook_id'],
        sourceId: json['source_id'],
        questions: (json['questions'] as List? ?? [])
            .map((q) => QuizQuestion.fromBackendJson(q))
            .toList(),
        timesAttempted: json['times_attempted'] ?? 0,
        bestScore: json['best_score'],
        lastScore: json['last_score'],
        lastAttemptedAt: json['last_attempted_at'] != null
            ? DateTime.parse(json['last_attempted_at'])
            : null,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'title': title,
        'notebook_id': notebookId,
        'source_id': sourceId,
        'questions': questions.map((q) => q.toBackendJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Quiz.fromJson(Map<String, dynamic> json) => _$QuizFromJson(json);
}

/// Represents a single quiz attempt/session
@freezed
class QuizAttempt with _$QuizAttempt {
  const factory QuizAttempt({
    required String id,
    required String quizId,
    required List<int?> userAnswers, // null if not answered
    required int score,
    required int totalQuestions,
    required Duration timeTaken,
    required DateTime completedAt,
  }) = _QuizAttempt;

  factory QuizAttempt.fromJson(Map<String, dynamic> json) =>
      _$QuizAttemptFromJson(json);
}
