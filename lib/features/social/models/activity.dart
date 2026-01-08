enum ActivityType {
  achievementUnlocked,
  quizCompleted,
  flashcardDeckCompleted,
  notebookCreated,
  notebookShared,
  studyStreak,
  levelUp,
  joinedGroup,
  studySessionCompleted,
  friendAdded,
  // New content-rich activity types
  sourceShared,
  planShared,
  podcastGenerated,
  researchCompleted,
  imageUploaded,
  ebookCreated,
  projectStarted,
  mindmapCreated,
  infographicCreated,
  storyCreated,
}

extension ActivityTypeExtension on ActivityType {
  String get value {
    switch (this) {
      case ActivityType.achievementUnlocked:
        return 'achievement_unlocked';
      case ActivityType.quizCompleted:
        return 'quiz_completed';
      case ActivityType.flashcardDeckCompleted:
        return 'flashcard_deck_completed';
      case ActivityType.notebookCreated:
        return 'notebook_created';
      case ActivityType.notebookShared:
        return 'notebook_shared';
      case ActivityType.studyStreak:
        return 'study_streak';
      case ActivityType.levelUp:
        return 'level_up';
      case ActivityType.joinedGroup:
        return 'joined_group';
      case ActivityType.studySessionCompleted:
        return 'study_session_completed';
      case ActivityType.friendAdded:
        return 'friend_added';
      case ActivityType.sourceShared:
        return 'source_shared';
      case ActivityType.planShared:
        return 'plan_shared';
      case ActivityType.podcastGenerated:
        return 'podcast_generated';
      case ActivityType.researchCompleted:
        return 'research_completed';
      case ActivityType.imageUploaded:
        return 'image_uploaded';
      case ActivityType.ebookCreated:
        return 'ebook_created';
      case ActivityType.projectStarted:
        return 'project_started';
      case ActivityType.mindmapCreated:
        return 'mindmap_created';
      case ActivityType.infographicCreated:
        return 'infographic_created';
      case ActivityType.storyCreated:
        return 'story_created';
    }
  }

  String get icon {
    switch (this) {
      case ActivityType.achievementUnlocked:
        return '🏆';
      case ActivityType.quizCompleted:
        return '📝';
      case ActivityType.flashcardDeckCompleted:
        return '🃏';
      case ActivityType.notebookCreated:
        return '📓';
      case ActivityType.notebookShared:
        return '🤝';
      case ActivityType.studyStreak:
        return '🔥';
      case ActivityType.levelUp:
        return '⬆️';
      case ActivityType.joinedGroup:
        return '👥';
      case ActivityType.studySessionCompleted:
        return '✅';
      case ActivityType.friendAdded:
        return '👋';
      case ActivityType.sourceShared:
        return '📤';
      case ActivityType.planShared:
        return '📋';
      case ActivityType.podcastGenerated:
        return '🎙️';
      case ActivityType.researchCompleted:
        return '🔬';
      case ActivityType.imageUploaded:
        return '🖼️';
      case ActivityType.ebookCreated:
        return '📚';
      case ActivityType.projectStarted:
        return '🚀';
      case ActivityType.mindmapCreated:
        return '🧠';
      case ActivityType.infographicCreated:
        return '📊';
      case ActivityType.storyCreated:
        return '📖';
    }
  }

  static ActivityType fromString(String value) {
    switch (value) {
      case 'achievement_unlocked':
        return ActivityType.achievementUnlocked;
      case 'quiz_completed':
        return ActivityType.quizCompleted;
      case 'flashcard_deck_completed':
        return ActivityType.flashcardDeckCompleted;
      case 'notebook_created':
        return ActivityType.notebookCreated;
      case 'notebook_shared':
        return ActivityType.notebookShared;
      case 'study_streak':
        return ActivityType.studyStreak;
      case 'level_up':
        return ActivityType.levelUp;
      case 'joined_group':
        return ActivityType.joinedGroup;
      case 'study_session_completed':
        return ActivityType.studySessionCompleted;
      case 'friend_added':
        return ActivityType.friendAdded;
      case 'source_shared':
        return ActivityType.sourceShared;
      case 'plan_shared':
        return ActivityType.planShared;
      case 'podcast_generated':
        return ActivityType.podcastGenerated;
      case 'research_completed':
        return ActivityType.researchCompleted;
      case 'image_uploaded':
        return ActivityType.imageUploaded;
      case 'ebook_created':
        return ActivityType.ebookCreated;
      case 'project_started':
        return ActivityType.projectStarted;
      case 'mindmap_created':
        return ActivityType.mindmapCreated;
      case 'infographic_created':
        return ActivityType.infographicCreated;
      case 'story_created':
        return ActivityType.storyCreated;
      default:
        return ActivityType.notebookCreated;
    }
  }
}

class Activity {
  final String id;
  final String userId;
  final ActivityType activityType;
  final String title;
  final String? description;
  final Map<String, dynamic> metadata;
  final String? referenceId;
  final String? referenceType;
  final bool isPublic;
  final DateTime createdAt;
  final String? username;
  final String? avatarUrl;
  final int reactionCount;
  final String? userReaction;

  Activity({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.title,
    this.description,
    this.metadata = const {},
    this.referenceId,
    this.referenceType,
    this.isPublic = true,
    required this.createdAt,
    this.username,
    this.avatarUrl,
    this.reactionCount = 0,
    this.userReaction,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'],
      userId: json['user_id'] ?? json['userId'],
      activityType: ActivityTypeExtension.fromString(
          json['activity_type'] ?? json['activityType']),
      title: json['title'],
      description: json['description'],
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'])
          : {},
      referenceId: json['reference_id'] ?? json['referenceId'],
      referenceType: json['reference_type'] ?? json['referenceType'],
      isPublic: json['is_public'] ?? json['isPublic'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      username: json['username'],
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      reactionCount: json['reaction_count'] ?? json['reactionCount'] ?? 0,
      userReaction: json['user_reaction'] ?? json['userReaction'],
    );
  }

  String get icon => activityType.icon;
}

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String username;
  final String? avatarUrl;
  final int score;
  final bool isFriend;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.score,
    this.isFriend = false,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'],
      userId: json['user_id'] ?? json['userId'],
      username: json['username'],
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      score: json['score'],
      isFriend: json['is_friend'] ?? json['isFriend'] ?? false,
      isCurrentUser: json['is_current_user'] ?? json['isCurrentUser'] ?? false,
    );
  }
}

class UserRank {
  final int rank;
  final int score;
  final int totalUsers;

  UserRank({
    required this.rank,
    required this.score,
    required this.totalUsers,
  });

  factory UserRank.fromJson(Map<String, dynamic> json) {
    return UserRank(
      rank: json['rank'] ?? 0,
      score: json['score'] ?? 0,
      totalUsers: json['total_users'] ?? json['totalUsers'] ?? 0,
    );
  }
}
