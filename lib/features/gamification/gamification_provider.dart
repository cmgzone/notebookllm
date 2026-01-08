import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'achievement.dart';
import 'daily_challenge.dart';
import '../../core/api/api_service.dart';
import '../../core/services/activity_logger_service.dart';

/// State for gamification system
class GamificationState {
  final UserStats stats;
  final List<Achievement> achievements;
  final List<DailyChallenge> dailyChallenges;
  final List<Achievement> recentUnlocks;
  final int languageMessagesSent;

  const GamificationState({
    this.stats = const UserStats(),
    this.achievements = const [],
    this.dailyChallenges = const [],
    this.recentUnlocks = const [],
    this.languageMessagesSent = 0,
  });

  GamificationState copyWith({
    UserStats? stats,
    List<Achievement>? achievements,
    List<DailyChallenge>? dailyChallenges,
    List<Achievement>? recentUnlocks,
    int? languageMessagesSent,
  }) {
    return GamificationState(
      stats: stats ?? this.stats,
      achievements: achievements ?? this.achievements,
      dailyChallenges: dailyChallenges ?? this.dailyChallenges,
      recentUnlocks: recentUnlocks ?? this.recentUnlocks,
      languageMessagesSent: languageMessagesSent ?? this.languageMessagesSent,
    );
  }

  int get unlockedCount => achievements.where((a) => a.isUnlocked).length;
  int get totalAchievements => achievements.length;
  List<DailyChallenge> get todaysChallenges =>
      dailyChallenges.where((c) => c.isToday).toList();
  int get completedTodayCount =>
      todaysChallenges.where((c) => c.isCompleted).length;
}

/// Provider for gamification system
class GamificationNotifier extends StateNotifier<GamificationState> {
  final Ref ref;

  GamificationNotifier(this.ref) : super(const GamificationState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadFromBackend();
  }

  Future<void> _loadFromBackend() async {
    try {
      final api = ref.read(apiServiceProvider);

      // Load stats
      final statsData = await api.getGamificationStats();
      final stats = UserStats.fromBackendJson(statsData);

      // Load achievements
      final achievementsData = await api.getAchievements();
      final achievementsMap = {
        for (var a in achievementsData) a['achievement_id'] as String: a
      };

      final achievements = AchievementDefinitions.all.map((template) {
        final saved = achievementsMap[template.id];
        if (saved != null) {
          return Achievement(
            id: template.id,
            title: template.title,
            description: template.description,
            category: template.category,
            tier: template.tier,
            icon: template.icon,
            targetValue: template.targetValue,
            currentValue: saved['current_value'] ?? 0,
            isUnlocked: saved['is_unlocked'] ?? false,
            unlockedAt: saved['unlocked_at'] != null
                ? DateTime.parse(saved['unlocked_at'])
                : null,
          );
        }
        return template;
      }).toList();

      // Load daily challenges
      final challengesData = await api.getDailyChallenges();
      final challenges =
          challengesData.map((j) => DailyChallenge.fromBackendJson(j)).toList();

      state = state.copyWith(
        stats: stats,
        achievements: achievements,
        dailyChallenges: challenges,
      );

      // Update streak client-side and sync
      _updateStreak();

      // If no challenges for today, generate them and sync to backend
      if (state.todaysChallenges.isEmpty) {
        await _generateAndSyncDailyChallenges();
      }
    } catch (e) {
      debugPrint('Error loading gamification data from backend: $e');
    }
  }

  Future<void> _generateAndSyncDailyChallenges() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newChallenges = _generateDailyChallenges(today);

    final api = ref.read(apiServiceProvider);
    try {
      final synced = await api.batchUpdateChallenges(
          newChallenges.map((c) => c.toBackendJson()).toList());
      state = state.copyWith(
        dailyChallenges: [
          ...state.dailyChallenges,
          ...synced.map((j) => DailyChallenge.fromBackendJson(j))
        ],
      );
    } catch (e) {
      debugPrint('Error syncing daily challenges: $e');
    }
  }

  void _updateStreak() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastActive = state.stats.lastActiveDate;

    if (lastActive == null) {
      _addXp(10); // Bonus for first day
      _syncStat('current_streak', 1);
      _syncStat('longest_streak', 1);
      _syncStat('last_active_date', today.toIso8601String());
    } else {
      final lastActiveDay = DateTime(
        lastActive.year,
        lastActive.month,
        lastActive.day,
      );
      final difference = today.difference(lastActiveDay).inDays;

      if (difference == 0) {
        // Same day
      } else if (difference == 1) {
        final newStreak = state.stats.currentStreak + 1;
        _syncStat('current_streak', newStreak);
        if (newStreak > state.stats.longestStreak) {
          _syncStat('longest_streak', newStreak);
        }
        _syncStat('last_active_date', today.toIso8601String());
        _checkStreakAchievements(newStreak);
      } else if (difference > 1) {
        _syncStat('current_streak', 1);
        _syncStat('last_active_date', today.toIso8601String());
      }
    }
  }

  Future<void> _syncStat(String field, dynamic value) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.trackActivity(field: field, value: value);
      // We don't refresh the whole state here to avoid loops, but update local state
      state = state.copyWith(
        stats: _updateStatsLocally(state.stats, field, value),
      );
    } catch (e) {
      debugPrint('Error syncing stat $field: $e');
    }
  }

  UserStats _updateStatsLocally(
      UserStats current, String field, dynamic value) {
    // Translate backend field names if necessary, but here we just need to update the model
    // Actually simpler to just refresh after all syncs are done or use copyWith
    switch (field) {
      case 'current_streak':
        return current.copyWith(currentStreak: value);
      case 'longest_streak':
        return current.copyWith(longestStreak: value);
      case 'last_active_date':
        return current.copyWith(lastActiveDate: DateTime.parse(value));
      default:
        return current;
    }
  }

  List<DailyChallenge> _generateDailyChallenges(DateTime date) {
    final random = Random(date.millisecondsSinceEpoch);
    final challenges = <DailyChallenge>[];
    final types = ChallengeType.values.toList()..shuffle(random);

    for (int i = 0; i < 3 && i < types.length; i++) {
      challenges.add(_createChallenge(types[i], date, random));
    }
    return challenges;
  }

  DailyChallenge _createChallenge(
      ChallengeType type, DateTime date, Random random) {
    switch (type) {
      case ChallengeType.reviewFlashcards:
        final count = [10, 15, 20, 25][random.nextInt(4)];
        return DailyChallenge(
          title: 'Flashcard Review',
          description: 'Review $count flashcards',
          type: type,
          targetValue: count,
          xpReward: count * 2,
          date: date,
        );
      case ChallengeType.completeQuiz:
        final count = [1, 2, 3][random.nextInt(3)];
        return DailyChallenge(
          title: 'Quiz Time',
          description: 'Complete $count quiz${count > 1 ? 'zes' : ''}',
          type: type,
          targetValue: count,
          xpReward: count * 25,
          date: date,
        );
      case ChallengeType.addSource:
        return DailyChallenge(
          title: 'Knowledge Builder',
          description: 'Add a new source to any notebook',
          type: type,
          targetValue: 1,
          xpReward: 30,
          date: date,
        );
      case ChallengeType.chatWithAI:
        final count = [5, 10, 15][random.nextInt(3)];
        return DailyChallenge(
          title: 'AI Conversation',
          description: 'Send $count messages to AI',
          type: type,
          targetValue: count,
          xpReward: count * 3,
          date: date,
        );
      case ChallengeType.tutorSession:
        return DailyChallenge(
          title: 'Tutor Time',
          description: 'Complete a tutor session',
          type: type,
          targetValue: 1,
          xpReward: 50,
          date: date,
        );
      case ChallengeType.createMindmap:
        return DailyChallenge(
          title: 'Mind Mapper',
          description: 'Create a mind map',
          type: type,
          targetValue: 1,
          xpReward: 40,
          date: date,
        );
      case ChallengeType.perfectQuiz:
        return DailyChallenge(
          title: 'Perfectionist',
          description: 'Get 100% on any quiz',
          type: type,
          targetValue: 1,
          xpReward: 75,
          date: date,
        );
      case ChallengeType.studyTime:
        final minutes = [15, 30, 45][random.nextInt(3)];
        return DailyChallenge(
          title: 'Study Session',
          description: 'Study for $minutes minutes',
          type: type,
          targetValue: minutes,
          xpReward: minutes,
          date: date,
        );
      case ChallengeType.deepResearch:
        return DailyChallenge(
          title: 'Deep Dive',
          description: 'Complete a deep research session',
          type: type,
          targetValue: 1,
          xpReward: 60,
          date: date,
        );
      case ChallengeType.voiceMode:
        return DailyChallenge(
          title: 'Voice Activated',
          description: 'Use voice mode',
          type: type,
          targetValue: 1,
          xpReward: 25,
          date: date,
        );
    }
  }

  // Public methods to track activities
  Future<void> trackQuizCompleted({bool isPerfect = false}) async {
    await _trackIncrement('quizzes_completed', 1);
    if (isPerfect) {
      await _trackIncrement('perfect_quizzes', 1);
    }

    await _updateChallengeProgress(ChallengeType.completeQuiz, 1);
    if (isPerfect) {
      await _updateChallengeProgress(ChallengeType.perfectQuiz, 1);
    }

    await _addXp(isPerfect ? 50 : 25);
    await _loadFromBackend();
  }

  Future<void> trackFlashcardsReviewed(int count) async {
    await _trackIncrement('flashcards_reviewed', count);
    await _updateChallengeProgress(ChallengeType.reviewFlashcards, count);
    await _addXp(count);
    await _loadFromBackend();
  }

  Future<void> trackNotebookCreated() async {
    await _trackIncrement('notebooks_created', 1);
    await _addXp(20);
    await _loadFromBackend();
  }

  Future<void> trackSourceAdded() async {
    await _trackIncrement('sources_added', 1);
    await _updateChallengeProgress(ChallengeType.addSource, 1);
    await _addXp(10);
    await _loadFromBackend();
  }

  Future<void> trackTutorSessionCompleted({double accuracy = 0}) async {
    await _trackIncrement('tutor_sessions_completed', 1);
    await _updateChallengeProgress(ChallengeType.tutorSession, 1);
    if (accuracy >= 0.8) {
      await _updateAchievementProgress('tutor_accuracy_80', 1, true);
    }
    await _addXp(40);
    await _loadFromBackend();
  }

  Future<void> trackChatMessage() async {
    await _trackIncrement('chat_messages_sent', 1);
    await _updateChallengeProgress(ChallengeType.chatWithAI, 1);
    await _addXp(2);
    await _loadFromBackend();
  }

  Future<void> trackDeepResearch() async {
    await _trackIncrement('deep_research_completed', 1);
    await _updateChallengeProgress(ChallengeType.deepResearch, 1);
    await _addXp(50);
    await _loadFromBackend();
  }

  Future<void> trackVoiceModeUsed() async {
    await _trackIncrement('voice_mode_used', 1);
    await _updateChallengeProgress(ChallengeType.voiceMode, 1);
    await _addXp(5);
    await _loadFromBackend();
  }

  Future<void> trackMindmapCreated() async {
    await _trackIncrement('mindmaps_created', 1);
    await _updateChallengeProgress(ChallengeType.createMindmap, 1);
    await _addXp(30);
    await _loadFromBackend();
  }

  Future<void> trackFeatureUsed(String featureName) async {
    final features = Set<String>.from(state.stats.featuresUsed)
      ..add(featureName);
    await _syncStat('features_used', features.toList());
  }

  Future<void> trackLanguageMessageSent() async {
    // In a full implementation, we'd have a specific language_messages field
    await _addXp(2);
    await _loadFromBackend();
  }

  Future<void> trackLanguageSessionCompleted() async {
    await _addXp(50);
    _updateStreak();
    await _loadFromBackend();
  }

  Future<void> trackEbookGenerated() async {
    await _addXp(100);
    await _loadFromBackend();
  }

  void _checkStreakAchievements(int streak) {
    if (streak >= 3) _updateAchievementProgress('streak_3', streak, true);
    if (streak >= 7) _updateAchievementProgress('streak_7', streak, true);
    if (streak >= 30) _updateAchievementProgress('streak_30', streak, true);
    if (streak >= 100) _updateAchievementProgress('streak_100', streak, true);

    // Log streak milestones to activity feed
    if (streak == 3 ||
        streak == 7 ||
        streak == 14 ||
        streak == 30 ||
        streak == 100) {
      ref.read(activityLoggerProvider).logStudyStreak(streak);
    }
  }

  Future<void> _updateAchievementProgress(
      String achievementId, int value, bool isUnlocked) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateAchievementProgress(
        achievementId: achievementId,
        value: value,
        isUnlocked: isUnlocked,
      );

      // Log achievement unlock to activity feed
      if (isUnlocked) {
        // Find the achievement title from definitions
        final achievement = AchievementDefinitions.all.firstWhere(
          (a) => a.id == achievementId,
          orElse: () => const Achievement(
            id: 'unknown',
            title: 'Achievement',
            description: '',
            category: AchievementCategory.learning,
            tier: AchievementTier.bronze,
            icon: Icons.emoji_events,
            targetValue: 1,
          ),
        );
        ref.read(activityLoggerProvider).logAchievementUnlocked(
              achievement.title,
              achievementId,
            );
      }
    } catch (e) {
      debugPrint('Error updating achievement: $e');
    }
  }

  Future<void> _trackIncrement(String field, int amount) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.trackActivity(field: field, increment: amount);
    } catch (e) {
      debugPrint('Error incrementing $field: $e');
    }
  }

  Future<void> _addXp(int amount) async {
    await _trackIncrement('total_xp', amount);
  }

  Future<void> _updateChallengeProgress(
      ChallengeType type, int increment) async {
    final challenges = [...state.dailyChallenges];
    final api = ref.read(apiServiceProvider);

    for (int i = 0; i < challenges.length; i++) {
      final challenge = challenges[i];
      if (challenge.type == type &&
          challenge.isToday &&
          !challenge.isCompleted) {
        final newValue = challenge.currentValue + increment;
        final isComplete = newValue >= challenge.targetValue;

        final updated = challenge.copyWith(
          currentValue: newValue,
          isCompleted: isComplete,
          completedAt: isComplete ? DateTime.now() : null,
        );

        await api.batchUpdateChallenges([updated.toBackendJson()]);
      }
    }
  }

  void clearRecentUnlocks() {
    state = state.copyWith(recentUnlocks: []);
  }
}

final gamificationProvider =
    StateNotifierProvider<GamificationNotifier, GamificationState>((ref) {
  return GamificationNotifier(ref);
});
