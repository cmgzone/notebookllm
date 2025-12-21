import 'package:flutter/material.dart';

/// Represents an achievement/badge in the app
class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final AchievementTier tier;
  final IconData icon;
  final int targetValue;
  final int currentValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.tier,
    required this.icon,
    required this.targetValue,
    this.currentValue = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  Achievement copyWith({
    int? currentValue,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      category: category,
      tier: tier,
      icon: icon,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'currentValue': currentValue,
        'isUnlocked': isUnlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
      };

  static Achievement fromSaved(
      Achievement template, Map<String, dynamic> json) {
    return template.copyWith(
      currentValue: json['currentValue'] ?? 0,
      isUnlocked: json['isUnlocked'] ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'])
          : null,
    );
  }
}

enum AchievementCategory {
  learning,
  creation,
  consistency,
  mastery,
  exploration,
  social,
}

enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
}

extension AchievementCategoryExt on AchievementCategory {
  String get displayName {
    switch (this) {
      case AchievementCategory.learning:
        return 'Learning';
      case AchievementCategory.creation:
        return 'Creation';
      case AchievementCategory.consistency:
        return 'Consistency';
      case AchievementCategory.mastery:
        return 'Mastery';
      case AchievementCategory.exploration:
        return 'Exploration';
      case AchievementCategory.social:
        return 'Social';
    }
  }

  IconData get icon {
    switch (this) {
      case AchievementCategory.learning:
        return Icons.school;
      case AchievementCategory.creation:
        return Icons.create;
      case AchievementCategory.consistency:
        return Icons.local_fire_department;
      case AchievementCategory.mastery:
        return Icons.emoji_events;
      case AchievementCategory.exploration:
        return Icons.explore;
      case AchievementCategory.social:
        return Icons.people;
    }
  }
}

extension AchievementTierExt on AchievementTier {
  String get displayName {
    switch (this) {
      case AchievementTier.bronze:
        return 'Bronze';
      case AchievementTier.silver:
        return 'Silver';
      case AchievementTier.gold:
        return 'Gold';
      case AchievementTier.platinum:
        return 'Platinum';
      case AchievementTier.diamond:
        return 'Diamond';
    }
  }

  Color get color {
    switch (this) {
      case AchievementTier.bronze:
        return const Color(0xFFCD7F32);
      case AchievementTier.silver:
        return const Color(0xFFC0C0C0);
      case AchievementTier.gold:
        return const Color(0xFFFFD700);
      case AchievementTier.platinum:
        return const Color(0xFFE5E4E2);
      case AchievementTier.diamond:
        return const Color(0xFFB9F2FF);
    }
  }

  int get xpReward {
    switch (this) {
      case AchievementTier.bronze:
        return 50;
      case AchievementTier.silver:
        return 100;
      case AchievementTier.gold:
        return 250;
      case AchievementTier.platinum:
        return 500;
      case AchievementTier.diamond:
        return 1000;
    }
  }
}

/// All available achievements in the app
class AchievementDefinitions {
  static const List<Achievement> all = [
    // Learning achievements
    Achievement(
      id: 'first_quiz',
      title: 'Quiz Starter',
      description: 'Complete your first quiz',
      category: AchievementCategory.learning,
      tier: AchievementTier.bronze,
      icon: Icons.quiz,
      targetValue: 1,
    ),
    Achievement(
      id: 'quiz_master_10',
      title: 'Quiz Enthusiast',
      description: 'Complete 10 quizzes',
      category: AchievementCategory.learning,
      tier: AchievementTier.silver,
      icon: Icons.quiz,
      targetValue: 10,
    ),
    Achievement(
      id: 'quiz_master_50',
      title: 'Quiz Master',
      description: 'Complete 50 quizzes',
      category: AchievementCategory.learning,
      tier: AchievementTier.gold,
      icon: Icons.quiz,
      targetValue: 50,
    ),
    Achievement(
      id: 'perfect_quiz',
      title: 'Perfect Score',
      description: 'Get 100% on a quiz',
      category: AchievementCategory.mastery,
      tier: AchievementTier.silver,
      icon: Icons.star,
      targetValue: 1,
    ),
    Achievement(
      id: 'flashcard_reviewer',
      title: 'Card Flipper',
      description: 'Review 100 flashcards',
      category: AchievementCategory.learning,
      tier: AchievementTier.bronze,
      icon: Icons.style,
      targetValue: 100,
    ),
    Achievement(
      id: 'flashcard_master',
      title: 'Memory Master',
      description: 'Review 1000 flashcards',
      category: AchievementCategory.learning,
      tier: AchievementTier.gold,
      icon: Icons.style,
      targetValue: 1000,
    ),

    // Creation achievements
    Achievement(
      id: 'first_notebook',
      title: 'Note Taker',
      description: 'Create your first notebook',
      category: AchievementCategory.creation,
      tier: AchievementTier.bronze,
      icon: Icons.book,
      targetValue: 1,
    ),
    Achievement(
      id: 'notebook_collector',
      title: 'Knowledge Collector',
      description: 'Create 10 notebooks',
      category: AchievementCategory.creation,
      tier: AchievementTier.silver,
      icon: Icons.library_books,
      targetValue: 10,
    ),
    Achievement(
      id: 'source_adder',
      title: 'Source Hunter',
      description: 'Add 25 sources',
      category: AchievementCategory.creation,
      tier: AchievementTier.silver,
      icon: Icons.source,
      targetValue: 25,
    ),
    Achievement(
      id: 'mindmap_creator',
      title: 'Mind Mapper',
      description: 'Create 5 mind maps',
      category: AchievementCategory.creation,
      tier: AchievementTier.bronze,
      icon: Icons.account_tree,
      targetValue: 5,
    ),
    Achievement(
      id: 'ebook_author',
      title: 'Author',
      description: 'Generate your first eBook',
      category: AchievementCategory.creation,
      tier: AchievementTier.gold,
      icon: Icons.auto_stories,
      targetValue: 1,
    ),

    // Consistency achievements
    Achievement(
      id: 'streak_3',
      title: 'Getting Started',
      description: 'Maintain a 3-day streak',
      category: AchievementCategory.consistency,
      tier: AchievementTier.bronze,
      icon: Icons.local_fire_department,
      targetValue: 3,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Week Warrior',
      description: 'Maintain a 7-day streak',
      category: AchievementCategory.consistency,
      tier: AchievementTier.silver,
      icon: Icons.local_fire_department,
      targetValue: 7,
    ),
    Achievement(
      id: 'streak_30',
      title: 'Monthly Master',
      description: 'Maintain a 30-day streak',
      category: AchievementCategory.consistency,
      tier: AchievementTier.gold,
      icon: Icons.local_fire_department,
      targetValue: 30,
    ),
    Achievement(
      id: 'streak_100',
      title: 'Unstoppable',
      description: 'Maintain a 100-day streak',
      category: AchievementCategory.consistency,
      tier: AchievementTier.diamond,
      icon: Icons.whatshot,
      targetValue: 100,
    ),

    // Mastery achievements
    Achievement(
      id: 'tutor_sessions_5',
      title: 'Eager Learner',
      description: 'Complete 5 tutor sessions',
      category: AchievementCategory.mastery,
      tier: AchievementTier.bronze,
      icon: Icons.school,
      targetValue: 5,
    ),
    Achievement(
      id: 'tutor_accuracy_80',
      title: 'Quick Learner',
      description: 'Achieve 80% accuracy in a tutor session',
      category: AchievementCategory.mastery,
      tier: AchievementTier.silver,
      icon: Icons.psychology,
      targetValue: 1,
    ),
    Achievement(
      id: 'deep_research',
      title: 'Deep Diver',
      description: 'Complete 3 deep research sessions',
      category: AchievementCategory.mastery,
      tier: AchievementTier.gold,
      icon: Icons.search,
      targetValue: 3,
    ),

    // Exploration achievements
    Achievement(
      id: 'feature_explorer',
      title: 'Explorer',
      description: 'Try 5 different features',
      category: AchievementCategory.exploration,
      tier: AchievementTier.bronze,
      icon: Icons.explore,
      targetValue: 5,
    ),
    Achievement(
      id: 'voice_mode_user',
      title: 'Voice Activated',
      description: 'Use voice mode 10 times',
      category: AchievementCategory.exploration,
      tier: AchievementTier.silver,
      icon: Icons.mic,
      targetValue: 10,
    ),
    Achievement(
      id: 'ai_chat_pro',
      title: 'Conversation Pro',
      description: 'Send 100 chat messages',
      category: AchievementCategory.exploration,
      tier: AchievementTier.silver,
      icon: Icons.chat,
      targetValue: 100,
    ),
    // Language Learning achievements
    Achievement(
      id: 'polyglot',
      title: 'Polyglot',
      description: 'Practice 3 different languages',
      category: AchievementCategory.learning,
      tier: AchievementTier.gold,
      icon: Icons.language,
      targetValue: 3,
    ),
    Achievement(
      id: 'fluency_builder',
      title: 'Fluency Builder',
      description: 'Send 100 messages in Language Learning',
      category: AchievementCategory.learning,
      tier: AchievementTier.silver,
      icon: Icons.chat_bubble_outline,
      targetValue: 100,
    ),
  ];
}
