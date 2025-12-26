import 'package:freezed_annotation/freezed_annotation.dart';

part 'flashcard.freezed.dart';
part 'flashcard.g.dart';

/// Represents a single flashcard for spaced repetition learning
@freezed
class Flashcard with _$Flashcard {
  const Flashcard._();

  const factory Flashcard({
    required String id,
    required String question,
    required String answer,
    required String notebookId,
    String? sourceId,
    @Default(1) int difficulty, // 1=easy, 2=medium, 3=hard
    @Default(0) int timesReviewed,
    @Default(0) int timesCorrect,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    required DateTime createdAt,
  }) = _Flashcard;

  factory Flashcard.fromJson(Map<String, dynamic> json) =>
      _$FlashcardFromJson(json);

  factory Flashcard.fromBackendJson(Map<String, dynamic> json) {
    // Convert text difficulty to int
    int difficultyInt = 1;
    final diff = json['difficulty'];
    if (diff is int) {
      difficultyInt = diff;
    } else if (diff is String) {
      difficultyInt = diff == 'easy'
          ? 1
          : diff == 'medium'
              ? 2
              : 3;
    }

    return Flashcard(
      id: json['id'],
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      notebookId: json['notebook_id'] ?? json['deck_id'] ?? '',
      sourceId: json['source_id'],
      difficulty: difficultyInt,
      timesReviewed: json['times_reviewed'] ?? 0,
      timesCorrect: json['times_correct'] ?? 0,
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.parse(json['last_reviewed_at'])
          : null,
      nextReviewAt: json['next_review_at'] != null
          ? DateTime.parse(json['next_review_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'question': question,
        'answer': answer,
        'notebook_id': notebookId,
        'source_id': sourceId,
        'difficulty': difficulty,
        'times_reviewed': timesReviewed,
        'times_correct': timesCorrect,
        'last_reviewed_at': lastReviewedAt?.toIso8601String(),
        'next_review_at': nextReviewAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

/// A deck of flashcards grouped together
@freezed
class FlashcardDeck with _$FlashcardDeck {
  const FlashcardDeck._();

  const factory FlashcardDeck({
    required String id,
    required String title,
    required String notebookId,
    String? sourceId,
    @Default([]) List<Flashcard> cards,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _FlashcardDeck;

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) =>
      _$FlashcardDeckFromJson(json);

  factory FlashcardDeck.fromBackendJson(Map<String, dynamic> json) =>
      FlashcardDeck(
        id: json['id'],
        title: json['title'],
        notebookId: json['notebook_id'],
        sourceId: json['source_id'],
        cards: (json['cards'] as List? ?? [])
            .map((c) => Flashcard.fromBackendJson(c))
            .toList(),
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'title': title,
        'notebook_id': notebookId,
        'source_id': sourceId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
