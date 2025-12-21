import 'package:uuid/uuid.dart';

/// Represents a tutoring session with Socratic method questioning
class TutorSession {
  final String id;
  final String notebookId;
  final String? sourceId;
  final String topic;
  final TutorDifficulty difficulty;
  final TutorStyle style;
  final List<TutorExchange> exchanges;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int questionsAsked;
  final int correctAnswers;
  final bool isComplete;

  TutorSession({
    String? id,
    required this.notebookId,
    this.sourceId,
    required this.topic,
    this.difficulty = TutorDifficulty.adaptive,
    this.style = TutorStyle.socratic,
    this.exchanges = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.questionsAsked = 0,
    this.correctAnswers = 0,
    this.isComplete = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get accuracy =>
      questionsAsked > 0 ? correctAnswers / questionsAsked : 0;

  TutorSession copyWith({
    String? topic,
    TutorDifficulty? difficulty,
    TutorStyle? style,
    List<TutorExchange>? exchanges,
    DateTime? updatedAt,
    int? questionsAsked,
    int? correctAnswers,
    bool? isComplete,
  }) {
    return TutorSession(
      id: id,
      notebookId: notebookId,
      sourceId: sourceId,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      style: style ?? this.style,
      exchanges: exchanges ?? this.exchanges,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      questionsAsked: questionsAsked ?? this.questionsAsked,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notebookId': notebookId,
        'sourceId': sourceId,
        'topic': topic,
        'difficulty': difficulty.name,
        'style': style.name,
        'exchanges': exchanges.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'questionsAsked': questionsAsked,
        'correctAnswers': correctAnswers,
        'isComplete': isComplete,
      };

  factory TutorSession.fromJson(Map<String, dynamic> json) => TutorSession(
        id: json['id'],
        notebookId: json['notebookId'],
        sourceId: json['sourceId'],
        topic: json['topic'],
        difficulty: TutorDifficulty.values.firstWhere(
          (d) => d.name == json['difficulty'],
          orElse: () => TutorDifficulty.adaptive,
        ),
        style: TutorStyle.values.firstWhere(
          (s) => s.name == json['style'],
          orElse: () => TutorStyle.socratic,
        ),
        exchanges: (json['exchanges'] as List?)
                ?.map((e) => TutorExchange.fromJson(e))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        questionsAsked: json['questionsAsked'] ?? 0,
        correctAnswers: json['correctAnswers'] ?? 0,
        isComplete: json['isComplete'] ?? false,
      );
}

/// A single exchange in the tutoring session
class TutorExchange {
  final String id;
  final ExchangeType type;
  final String content;
  final String? userResponse;
  final String? feedback;
  final bool? wasCorrect;
  final DateTime timestamp;

  TutorExchange({
    String? id,
    required this.type,
    required this.content,
    this.userResponse,
    this.feedback,
    this.wasCorrect,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  TutorExchange copyWith({
    String? userResponse,
    String? feedback,
    bool? wasCorrect,
  }) {
    return TutorExchange(
      id: id,
      type: type,
      content: content,
      userResponse: userResponse ?? this.userResponse,
      feedback: feedback ?? this.feedback,
      wasCorrect: wasCorrect ?? this.wasCorrect,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content,
        'userResponse': userResponse,
        'feedback': feedback,
        'wasCorrect': wasCorrect,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TutorExchange.fromJson(Map<String, dynamic> json) => TutorExchange(
        id: json['id'],
        type: ExchangeType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ExchangeType.question,
        ),
        content: json['content'],
        userResponse: json['userResponse'],
        feedback: json['feedback'],
        wasCorrect: json['wasCorrect'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

enum TutorDifficulty {
  beginner,
  intermediate,
  advanced,
  adaptive,
}

enum TutorStyle {
  socratic, // Ask probing questions to guide understanding
  explanatory, // Explain concepts then test
  challenge, // Present problems to solve
  mixed, // Combination of styles
}

enum ExchangeType {
  question, // Tutor asks a question
  hint, // Tutor provides a hint
  explanation, // Tutor explains a concept
  encouragement, // Positive reinforcement
  correction, // Gentle correction with explanation
  summary, // Session summary
}

extension TutorDifficultyExt on TutorDifficulty {
  String get displayName {
    switch (this) {
      case TutorDifficulty.beginner:
        return 'Beginner';
      case TutorDifficulty.intermediate:
        return 'Intermediate';
      case TutorDifficulty.advanced:
        return 'Advanced';
      case TutorDifficulty.adaptive:
        return 'Adaptive';
    }
  }

  String get description {
    switch (this) {
      case TutorDifficulty.beginner:
        return 'Simple questions with more hints';
      case TutorDifficulty.intermediate:
        return 'Balanced difficulty';
      case TutorDifficulty.advanced:
        return 'Challenging questions';
      case TutorDifficulty.adaptive:
        return 'Adjusts to your performance';
    }
  }
}

extension TutorStyleExt on TutorStyle {
  String get displayName {
    switch (this) {
      case TutorStyle.socratic:
        return 'Socratic';
      case TutorStyle.explanatory:
        return 'Explanatory';
      case TutorStyle.challenge:
        return 'Challenge';
      case TutorStyle.mixed:
        return 'Mixed';
    }
  }

  String get description {
    switch (this) {
      case TutorStyle.socratic:
        return 'Guided discovery through questions';
      case TutorStyle.explanatory:
        return 'Learn concepts then practice';
      case TutorStyle.challenge:
        return 'Problem-solving focused';
      case TutorStyle.mixed:
        return 'Variety of teaching methods';
    }
  }
}
