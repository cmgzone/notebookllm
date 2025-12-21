import 'package:uuid/uuid.dart';

/// Represents a daily challenge for the user
class DailyChallenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final int targetValue;
  final int currentValue;
  final int xpReward;
  final DateTime date;
  final bool isCompleted;
  final DateTime? completedAt;

  DailyChallenge({
    String? id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    required this.xpReward,
    required this.date,
    this.isCompleted = false,
    this.completedAt,
  }) : id = id ?? const Uuid().v4();

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  DailyChallenge copyWith({
    int? currentValue,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return DailyChallenge(
      id: id,
      title: title,
      description: description,
      type: type,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
      xpReward: xpReward,
      date: date,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.index,
        'targetValue': targetValue,
        'currentValue': currentValue,
        'isCompleted': isCompleted,
        'xpReward': xpReward,
        'date': date.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'target_value': targetValue,
        'current_value': currentValue,
        'is_completed': isCompleted,
        'xp_reward': xpReward,
        'date': date.toIso8601String().split('T')[0],
        'completed_at': completedAt?.toIso8601String(),
      };

  factory DailyChallenge.fromBackendJson(Map<String, dynamic> json) =>
      DailyChallenge(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        type: ChallengeType.values.firstWhere((e) => e.name == json['type']),
        targetValue: json['target_value'] ?? 0,
        currentValue: json['current_value'] ?? 0,
        isCompleted: json['is_completed'] ?? false,
        xpReward: json['xp_reward'] ?? 0,
        date: DateTime.parse(json['date']),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
      );

  factory DailyChallenge.fromJson(Map<String, dynamic> json) => DailyChallenge(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        type: ChallengeType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ChallengeType.reviewFlashcards,
        ),
        targetValue: json['targetValue'],
        currentValue: json['currentValue'] ?? 0,
        xpReward: json['xpReward'],
        date: DateTime.parse(json['date']),
        isCompleted: json['isCompleted'] ?? false,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'])
            : null,
      );
}

enum ChallengeType {
  reviewFlashcards,
  completeQuiz,
  addSource,
  chatWithAI,
  tutorSession,
  createMindmap,
  perfectQuiz,
  studyTime,
  deepResearch,
  voiceMode,
}

extension ChallengeTypeExt on ChallengeType {
  String get actionVerb {
    switch (this) {
      case ChallengeType.reviewFlashcards:
        return 'Review';
      case ChallengeType.completeQuiz:
        return 'Complete';
      case ChallengeType.addSource:
        return 'Add';
      case ChallengeType.chatWithAI:
        return 'Send';
      case ChallengeType.tutorSession:
        return 'Complete';
      case ChallengeType.createMindmap:
        return 'Create';
      case ChallengeType.perfectQuiz:
        return 'Get';
      case ChallengeType.studyTime:
        return 'Study for';
      case ChallengeType.deepResearch:
        return 'Complete';
      case ChallengeType.voiceMode:
        return 'Use';
    }
  }
}

/// User's gamification stats
class UserStats {
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;
  final int level;
  final int quizzesCompleted;
  final int flashcardsReviewed;
  final int notebooksCreated;
  final int sourcesAdded;
  final int tutorSessionsCompleted;
  final int chatMessagesSent;
  final int perfectQuizzes;
  final int deepResearchCompleted;
  final int voiceModeUsed;
  final int mindmapsCreated;
  final Set<String> featuresUsed;

  const UserStats({
    this.totalXp = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.level = 1,
    this.quizzesCompleted = 0,
    this.flashcardsReviewed = 0,
    this.notebooksCreated = 0,
    this.sourcesAdded = 0,
    this.tutorSessionsCompleted = 0,
    this.chatMessagesSent = 0,
    this.perfectQuizzes = 0,
    this.deepResearchCompleted = 0,
    this.voiceModeUsed = 0,
    this.mindmapsCreated = 0,
    this.featuresUsed = const {},
  });

  int get xpForNextLevel => level * 500;
  int get xpInCurrentLevel => totalXp - _xpForLevel(level - 1);
  double get levelProgress => xpInCurrentLevel / xpForNextLevel;

  int _xpForLevel(int lvl) {
    if (lvl <= 0) return 0;
    return (lvl * (lvl + 1) / 2 * 500).toInt();
  }

  UserStats copyWith({
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActiveDate,
    int? level,
    int? quizzesCompleted,
    int? flashcardsReviewed,
    int? notebooksCreated,
    int? sourcesAdded,
    int? tutorSessionsCompleted,
    int? chatMessagesSent,
    int? perfectQuizzes,
    int? deepResearchCompleted,
    int? voiceModeUsed,
    int? mindmapsCreated,
    Set<String>? featuresUsed,
  }) {
    return UserStats(
      totalXp: totalXp ?? this.totalXp,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      level: level ?? this.level,
      quizzesCompleted: quizzesCompleted ?? this.quizzesCompleted,
      flashcardsReviewed: flashcardsReviewed ?? this.flashcardsReviewed,
      notebooksCreated: notebooksCreated ?? this.notebooksCreated,
      sourcesAdded: sourcesAdded ?? this.sourcesAdded,
      tutorSessionsCompleted:
          tutorSessionsCompleted ?? this.tutorSessionsCompleted,
      chatMessagesSent: chatMessagesSent ?? this.chatMessagesSent,
      perfectQuizzes: perfectQuizzes ?? this.perfectQuizzes,
      deepResearchCompleted:
          deepResearchCompleted ?? this.deepResearchCompleted,
      voiceModeUsed: voiceModeUsed ?? this.voiceModeUsed,
      mindmapsCreated: mindmapsCreated ?? this.mindmapsCreated,
      featuresUsed: featuresUsed ?? this.featuresUsed,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalXp': totalXp,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActiveDate': lastActiveDate?.toIso8601String(),
        'level': level,
        'quizzesCompleted': quizzesCompleted,
        'flashcardsReviewed': flashcardsReviewed,
        'notebooksCreated': notebooksCreated,
        'sourcesAdded': sourcesAdded,
        'tutorSessionsCompleted': tutorSessionsCompleted,
        'chatMessagesSent': chatMessagesSent,
        'perfectQuizzes': perfectQuizzes,
        'deepResearchCompleted': deepResearchCompleted,
        'voiceModeUsed': voiceModeUsed,
        'mindmapsCreated': mindmapsCreated,
        'featuresUsed': featuresUsed.toList(),
      };

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalXp: json['totalXp'] ?? 0,
        currentStreak: json['currentStreak'] ?? 0,
        longestStreak: json['longestStreak'] ?? 0,
        lastActiveDate: json['lastActiveDate'] != null
            ? DateTime.parse(json['lastActiveDate'])
            : null,
        level: json['level'] ?? 1,
        quizzesCompleted: json['quizzesCompleted'] ?? 0,
        flashcardsReviewed: json['flashcardsReviewed'] ?? 0,
        notebooksCreated: json['notebooksCreated'] ?? 0,
        sourcesAdded: json['sourcesAdded'] ?? 0,
        tutorSessionsCompleted: json['tutorSessionsCompleted'] ?? 0,
        chatMessagesSent: json['chatMessagesSent'] ?? 0,
        perfectQuizzes: json['perfectQuizzes'] ?? 0,
        deepResearchCompleted: json['deepResearchCompleted'] ?? 0,
        voiceModeUsed: json['voiceModeUsed'] ?? 0,
        mindmapsCreated: json['mindmapsCreated'] ?? 0,
        featuresUsed: Set<String>.from(json['featuresUsed'] ?? []),
      );

  factory UserStats.fromBackendJson(Map<String, dynamic> json) => UserStats(
        totalXp: json['total_xp'] ?? 0,
        currentStreak: json['current_streak'] ?? 0,
        longestStreak: json['longest_streak'] ?? 0,
        lastActiveDate: json['last_active_date'] != null
            ? DateTime.parse(json['last_active_date'])
            : null,
        level: json['level'] ?? 1,
        quizzesCompleted: json['quizzes_completed'] ?? 0,
        flashcardsReviewed: json['flashcards_reviewed'] ?? 0,
        notebooksCreated: json['notebooks_created'] ?? 0,
        sourcesAdded: json['sources_added'] ?? 0,
        tutorSessionsCompleted: json['tutor_sessions_completed'] ?? 0,
        chatMessagesSent: json['chat_messages_sent'] ?? 0,
        perfectQuizzes: json['perfect_quizzes'] ?? 0,
        deepResearchCompleted: json['deep_research_completed'] ?? 0,
        voiceModeUsed: json['voice_mode_used'] ?? 0,
        mindmapsCreated: json['mindmaps_created'] ?? 0,
        featuresUsed: Set<String>.from(json['features_used'] ?? []),
      );
}
