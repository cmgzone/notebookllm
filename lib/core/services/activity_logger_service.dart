import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../api/api_service.dart';

/// Centralized service for logging user activities to the social feed.
/// This service provides a simple API for logging various content creation
/// and sharing activities that appear in the Activity Feed.
class ActivityLoggerService {
  final ApiService _api;

  ActivityLoggerService(this._api);

  /// Log a generic activity
  Future<void> logActivity({
    required String activityType,
    required String title,
    String? description,
    String? referenceId,
    String? referenceType,
    Map<String, dynamic>? metadata,
    bool isPublic = true,
  }) async {
    try {
      await _api.post('/social/activities', {
        'activityType': activityType,
        'title': title,
        if (description != null) 'description': description,
        if (referenceId != null) 'referenceId': referenceId,
        if (referenceType != null) 'referenceType': referenceType,
        if (metadata != null) 'metadata': metadata,
        'isPublic': isPublic,
      });
      debugPrint('[ActivityLogger] Logged: $activityType - $title');
    } catch (e) {
      // Don't throw - activity logging shouldn't break the app
      debugPrint('[ActivityLogger] Failed to log activity: $e');
    }
  }

  // ==================== QUIZ & FLASHCARDS ====================

  /// Log when user completes a quiz
  Future<void> logQuizCompleted(
      String quizTitle, int score, String quizId) async {
    await logActivity(
      activityType: 'quiz_completed',
      title: 'Completed quiz: $quizTitle',
      description: 'Scored $score%',
      referenceId: quizId,
      referenceType: 'quiz',
      metadata: {'quizTitle': quizTitle, 'score': score},
    );
  }

  /// Log when user completes a flashcard deck
  Future<void> logFlashcardDeckCompleted(
      String deckTitle, String deckId) async {
    await logActivity(
      activityType: 'flashcard_deck_completed',
      title: 'Completed flashcard deck: $deckTitle',
      referenceId: deckId,
      referenceType: 'flashcard_deck',
      metadata: {'deckTitle': deckTitle},
    );
  }

  // ==================== NOTEBOOKS & SOURCES ====================

  /// Log when user creates a notebook
  Future<void> logNotebookCreated(
      String notebookTitle, String notebookId) async {
    await logActivity(
      activityType: 'notebook_created',
      title: 'Created notebook: $notebookTitle',
      referenceId: notebookId,
      referenceType: 'notebook',
      metadata: {'notebookTitle': notebookTitle},
    );
  }

  /// Log when user shares a notebook
  Future<void> logNotebookShared(
      String notebookTitle, String notebookId) async {
    await logActivity(
      activityType: 'notebook_shared',
      title: 'Shared notebook: $notebookTitle',
      referenceId: notebookId,
      referenceType: 'notebook',
      metadata: {'notebookTitle': notebookTitle},
    );
  }

  /// Log when user shares a source (PDF, URL, etc.)
  Future<void> logSourceShared(
      String sourceTitle, String sourceId, String sourceType) async {
    await logActivity(
      activityType: 'source_shared',
      title: 'Shared a $sourceType: $sourceTitle',
      referenceId: sourceId,
      referenceType: 'source',
      metadata: {'sourceTitle': sourceTitle, 'sourceType': sourceType},
    );
  }

  // ==================== CONTENT CREATION ====================

  /// Log when user generates a podcast
  Future<void> logPodcastGenerated(String podcastTitle, String podcastId,
      {int? durationSeconds}) async {
    await logActivity(
      activityType: 'podcast_generated',
      title: 'Generated podcast: $podcastTitle',
      description: durationSeconds != null
          ? 'Duration: ${(durationSeconds / 60).round()} minutes'
          : null,
      referenceId: podcastId,
      referenceType: 'podcast',
      metadata: {
        'podcastTitle': podcastTitle,
        if (durationSeconds != null) 'duration': durationSeconds
      },
    );
  }

  /// Log when user completes deep research
  Future<void> logResearchCompleted(String topic, String researchId) async {
    await logActivity(
      activityType: 'research_completed',
      title: 'Completed deep research: $topic',
      referenceId: researchId,
      referenceType: 'research',
      metadata: {'topic': topic},
    );
  }

  /// Log when user uploads images
  Future<void> logImageUploaded(int imageCount, {String? notebookId}) async {
    await logActivity(
      activityType: 'image_uploaded',
      title: 'Uploaded $imageCount image${imageCount > 1 ? 's' : ''}',
      referenceId: notebookId,
      referenceType: 'notebook',
      metadata: {'imageCount': imageCount},
    );
  }

  /// Log when user creates an ebook
  Future<void> logEbookCreated(String ebookTitle, String ebookId) async {
    await logActivity(
      activityType: 'ebook_created',
      title: 'Created ebook: $ebookTitle',
      referenceId: ebookId,
      referenceType: 'ebook',
      metadata: {'ebookTitle': ebookTitle},
    );
  }

  /// Log when user creates a mind map
  Future<void> logMindmapCreated(String mindmapTitle, String mindmapId) async {
    await logActivity(
      activityType: 'mindmap_created',
      title: 'Created mind map: $mindmapTitle',
      referenceId: mindmapId,
      referenceType: 'mindmap',
      metadata: {'mindmapTitle': mindmapTitle},
    );
  }

  /// Log when user creates an infographic
  Future<void> logInfographicCreated(
      String infographicTitle, String infographicId) async {
    await logActivity(
      activityType: 'infographic_created',
      title: 'Created infographic: $infographicTitle',
      referenceId: infographicId,
      referenceType: 'infographic',
      metadata: {'infographicTitle': infographicTitle},
    );
  }

  /// Log when user creates a story
  Future<void> logStoryCreated(String storyTitle, String storyId) async {
    await logActivity(
      activityType: 'story_created',
      title: 'Created story: $storyTitle',
      referenceId: storyId,
      referenceType: 'story',
      metadata: {'storyTitle': storyTitle},
    );
  }

  // ==================== PROJECTS & PLANS ====================

  /// Log when user starts a new project
  Future<void> logProjectStarted(
      String projectTitle, String projectId, String category) async {
    await logActivity(
      activityType: 'project_started',
      title: 'Started new $category project: $projectTitle',
      referenceId: projectId,
      referenceType: 'project',
      metadata: {'projectTitle': projectTitle, 'category': category},
    );
  }

  /// Log when user shares a plan
  Future<void> logPlanShared(String planTitle, String planId,
      {String? category}) async {
    await logActivity(
      activityType: 'plan_shared',
      title: 'Shared project plan: $planTitle',
      description: category != null ? 'Category: $category' : null,
      referenceId: planId,
      referenceType: 'plan',
      metadata: {
        'planTitle': planTitle,
        if (category != null) 'category': category
      },
    );
  }

  // ==================== SOCIAL & GAMIFICATION ====================

  /// Log when user joins a study group
  Future<void> logJoinedGroup(String groupName, String groupId) async {
    await logActivity(
      activityType: 'joined_group',
      title: 'Joined study group: $groupName',
      referenceId: groupId,
      referenceType: 'study_group',
      metadata: {'groupName': groupName},
    );
  }

  /// Log when user adds a friend
  Future<void> logFriendAdded(String friendName, String friendId) async {
    await logActivity(
      activityType: 'friend_added',
      title: 'Added $friendName as a friend',
      referenceId: friendId,
      referenceType: 'friend',
      metadata: {'friendName': friendName},
    );
  }

  /// Log when user unlocks an achievement
  Future<void> logAchievementUnlocked(
      String achievementName, String achievementId) async {
    await logActivity(
      activityType: 'achievement_unlocked',
      title: 'Unlocked achievement: $achievementName',
      referenceId: achievementId,
      referenceType: 'achievement',
      metadata: {'achievementName': achievementName},
    );
  }

  /// Log study streak milestone
  Future<void> logStudyStreak(int streakDays) async {
    await logActivity(
      activityType: 'study_streak',
      title: '$streakDays day study streak! 🔥',
      metadata: {'streakDays': streakDays},
    );
  }

  /// Log level up
  Future<void> logLevelUp(int newLevel) async {
    await logActivity(
      activityType: 'level_up',
      title: 'Reached level $newLevel! 🎉',
      metadata: {'level': newLevel},
    );
  }

  /// Log study session completed
  Future<void> logStudySessionCompleted(String sessionTitle, String sessionId,
      {int? durationMinutes}) async {
    await logActivity(
      activityType: 'study_session_completed',
      title: 'Completed study session: $sessionTitle',
      description:
          durationMinutes != null ? 'Duration: $durationMinutes minutes' : null,
      referenceId: sessionId,
      referenceType: 'study_session',
      metadata: {
        'sessionTitle': sessionTitle,
        if (durationMinutes != null) 'duration': durationMinutes
      },
    );
  }
}

/// Provider for the activity logger service
final activityLoggerProvider = Provider<ActivityLoggerService>((ref) {
  return ActivityLoggerService(ref.watch(apiServiceProvider));
});
