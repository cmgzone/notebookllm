import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import '../../core/utils/app_logger.dart';
import 'models/friend.dart';
import 'models/study_group.dart';
import 'models/activity.dart';

const _logger = AppLogger('SocialProvider');

// Sentinel value to distinguish between "not passed" and "passed as null"
const _sentinel = Object();

// State classes
class FriendsState {
  final List<Friend> friends;
  final List<FriendRequest> receivedRequests;
  final List<FriendRequest> sentRequests;
  final bool isLoading;
  final String? error;

  FriendsState({
    this.friends = const [],
    this.receivedRequests = const [],
    this.sentRequests = const [],
    this.isLoading = false,
    this.error,
  });

  FriendsState copyWith({
    List<Friend>? friends,
    List<FriendRequest>? receivedRequests,
    List<FriendRequest>? sentRequests,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      receivedRequests: receivedRequests ?? this.receivedRequests,
      sentRequests: sentRequests ?? this.sentRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

class StudyGroupsState {
  final List<StudyGroup> groups;
  final List<GroupInvitation> invitations;
  final bool isLoading;
  final String? error;

  StudyGroupsState({
    this.groups = const [],
    this.invitations = const [],
    this.isLoading = false,
    this.error,
  });

  StudyGroupsState copyWith({
    List<StudyGroup>? groups,
    List<GroupInvitation>? invitations,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return StudyGroupsState(
      groups: groups ?? this.groups,
      invitations: invitations ?? this.invitations,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

class ActivityFeedState {
  final List<Activity> activities;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  ActivityFeedState({
    this.activities = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  ActivityFeedState copyWith({
    List<Activity>? activities,
    bool? isLoading,
    bool? hasMore,
    Object? error = _sentinel,
  }) {
    return ActivityFeedState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final UserRank? userRank;
  final String type; // 'global' or 'friends'
  final String period; // 'weekly', 'monthly', 'all_time'
  final String metric; // 'xp', 'quizzes', 'flashcards'
  final bool isLoading;
  final String? error;

  LeaderboardState({
    this.entries = const [],
    this.userRank,
    this.type = 'global',
    this.period = 'weekly',
    this.metric = 'xp',
    this.isLoading = false,
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    UserRank? userRank,
    String? type,
    String? period,
    String? metric,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      userRank: userRank ?? this.userRank,
      type: type ?? this.type,
      period: period ?? this.period,
      metric: metric ?? this.metric,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

// Friends Provider
class FriendsNotifier extends StateNotifier<FriendsState> {
  final ApiService _api;

  FriendsNotifier(this._api) : super(FriendsState());

  Future<void> loadFriends() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      _logger.debug('Loading friends...');
      final response = await _api.get('/social/friends');
      _logger.debug('Friends response: $response');
      final friendsList = response['friends'];
      if (friendsList == null) {
        _logger.debug('Friends list is null, returning empty list');
        state = state.copyWith(friends: [], isLoading: false);
        return;
      }
      final friends =
          (friendsList as List).map((f) => Friend.fromJson(f)).toList();
      _logger.debug('Loaded ${friends.length} friends');
      state = state.copyWith(friends: friends, isLoading: false);
    } catch (e, stack) {
      _logger.error('Error loading friends', e, stack);
      final errorMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  Future<void> loadRequests() async {
    try {
      final response = await _api.get('/social/friends/requests');
      final receivedList = response['received'];
      final sentList = response['sent'];
      final received = receivedList != null
          ? (receivedList as List)
              .map((r) => FriendRequest.fromJson(r))
              .toList()
          : <FriendRequest>[];
      final sent = sentList != null
          ? (sentList as List).map((r) => FriendRequest.fromJson(r)).toList()
          : <FriendRequest>[];
      state = state.copyWith(
          receivedRequests: received, sentRequests: sent, error: null);
    } catch (e) {
      // Don't set error for requests - it's not critical
      // Just log it and continue with empty lists
      _logger.error('Error loading friend requests', e);
      state = state.copyWith(receivedRequests: [], sentRequests: []);
    }
  }

  Future<List<UserSearchResult>> searchUsers(String query) async {
    final response = await _api.get('/social/users/search?q=$query');
    return (response['users'] as List)
        .map((u) => UserSearchResult.fromJson(u))
        .toList();
  }

  Future<void> sendFriendRequest(String friendId) async {
    await _api.post('/social/friends/request', {'friendId': friendId});
    await loadRequests();
  }

  Future<void> acceptRequest(String requestId) async {
    await _api.post('/social/friends/accept/$requestId', {});
    await Future.wait([loadFriends(), loadRequests()]);
  }

  Future<void> declineRequest(String requestId) async {
    await _api.post('/social/friends/decline/$requestId', {});
    await loadRequests();
  }

  Future<void> removeFriend(String friendshipId) async {
    await _api.delete('/social/friends/$friendshipId');
    await loadFriends();
  }
}

final friendsProvider =
    StateNotifierProvider<FriendsNotifier, FriendsState>((ref) {
  return FriendsNotifier(ref.watch(apiServiceProvider));
});

// Study Groups Provider
class StudyGroupsNotifier extends StateNotifier<StudyGroupsState> {
  final ApiService _api;

  StudyGroupsNotifier(this._api) : super(StudyGroupsState());

  Future<void> loadGroups() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      _logger.debug('Loading study groups...');
      final response = await _api.get('/social/groups');
      _logger.debug('Groups response: $response');
      final groupsList = response['groups'];
      if (groupsList == null) {
        _logger.debug('Groups list is null, returning empty list');
        state = state.copyWith(groups: [], isLoading: false);
        return;
      }
      final groups =
          (groupsList as List).map((g) => StudyGroup.fromJson(g)).toList();
      _logger.debug('Loaded ${groups.length} groups');
      state = state.copyWith(groups: groups, isLoading: false);
    } catch (e, stack) {
      _logger.error('Error loading groups', e, stack);
      final errorMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  Future<void> loadInvitations() async {
    try {
      _logger.debug('Loading group invitations...');
      final response = await _api.get('/social/groups/invitations/pending');
      _logger.debug('Invitations response: $response');
      final invitationsList = response['invitations'];
      if (invitationsList == null) {
        state = state.copyWith(invitations: [], error: null);
        return;
      }
      final invitations = (invitationsList as List)
          .map((i) => GroupInvitation.fromJson(i))
          .toList();
      _logger.debug('Loaded ${invitations.length} invitations');
      state = state.copyWith(invitations: invitations, error: null);
    } catch (e, stack) {
      _logger.error('Error loading invitations', e, stack);
      // Don't set error for invitations - it's not critical
      // Just log it and continue with empty invitations
      state = state.copyWith(invitations: []);
    }
  }

  Future<StudyGroup> createGroup({
    required String name,
    String? description,
    String? icon,
    bool isPublic = false,
  }) async {
    final response = await _api.post('/social/groups', {
      'name': name,
      'description': description,
      'icon': icon,
      'isPublic': isPublic,
    });
    await loadGroups();
    return StudyGroup.fromJson(response['group']);
  }

  Future<void> deleteGroup(String groupId) async {
    await _api.delete('/social/groups/$groupId');
    await loadGroups();
  }

  Future<void> leaveGroup(String groupId) async {
    await _api.post('/social/groups/$groupId/leave', {});
    await loadGroups();
  }

  Future<void> inviteUser(String groupId, String userId) async {
    await _api.post('/social/groups/$groupId/invite', {'userId': userId});
  }

  Future<void> acceptInvitation(String invitationId) async {
    await _api.post('/social/groups/invitations/$invitationId/accept', {});
    await Future.wait([loadGroups(), loadInvitations()]);
  }

  Future<StudySession> createSession({
    required String groupId,
    required String title,
    String? description,
    required DateTime scheduledAt,
    int durationMinutes = 60,
    String? meetingUrl,
  }) async {
    final response = await _api.post('/social/groups/$groupId/sessions', {
      'title': title,
      'description': description,
      'scheduledAt': scheduledAt.toIso8601String(),
      'durationMinutes': durationMinutes,
      'meetingUrl': meetingUrl,
    });
    return StudySession.fromJson(response['session']);
  }
}

final studyGroupsProvider =
    StateNotifierProvider<StudyGroupsNotifier, StudyGroupsState>((ref) {
  return StudyGroupsNotifier(ref.watch(apiServiceProvider));
});

// Activity Feed Provider
class ActivityFeedNotifier extends StateNotifier<ActivityFeedState> {
  final ApiService _api;

  ActivityFeedNotifier(this._api) : super(ActivityFeedState());

  Future<void> loadFeed({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final offset = refresh ? 0 : state.activities.length;
      final response = await _api.get('/social/feed?limit=20&offset=$offset');
      final activities = (response['activities'] as List)
          .map((a) => Activity.fromJson(a))
          .toList();

      state = state.copyWith(
        activities: refresh ? activities : [...state.activities, ...activities],
        isLoading: false,
        hasMore: activities.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addReaction(String activityId, String reactionType) async {
    await _api.post(
        '/social/activities/$activityId/react', {'reactionType': reactionType});
    // Update local state
    final activities = state.activities.map((a) {
      if (a.id == activityId) {
        return Activity(
          id: a.id,
          userId: a.userId,
          activityType: a.activityType,
          title: a.title,
          description: a.description,
          metadata: a.metadata,
          referenceId: a.referenceId,
          referenceType: a.referenceType,
          isPublic: a.isPublic,
          createdAt: a.createdAt,
          username: a.username,
          avatarUrl: a.avatarUrl,
          reactionCount:
              a.userReaction == null ? a.reactionCount + 1 : a.reactionCount,
          userReaction: reactionType,
        );
      }
      return a;
    }).toList();
    state = state.copyWith(activities: activities);
  }

  Future<void> removeReaction(String activityId) async {
    await _api.delete('/social/activities/$activityId/react');
    // Update local state
    final activities = state.activities.map((a) {
      if (a.id == activityId) {
        return Activity(
          id: a.id,
          userId: a.userId,
          activityType: a.activityType,
          title: a.title,
          description: a.description,
          metadata: a.metadata,
          referenceId: a.referenceId,
          referenceType: a.referenceType,
          isPublic: a.isPublic,
          createdAt: a.createdAt,
          username: a.username,
          avatarUrl: a.avatarUrl,
          reactionCount: a.reactionCount > 0 ? a.reactionCount - 1 : 0,
          userReaction: null,
        );
      }
      return a;
    }).toList();
    state = state.copyWith(activities: activities);
  }
}

final activityFeedProvider =
    StateNotifierProvider<ActivityFeedNotifier, ActivityFeedState>((ref) {
  return ActivityFeedNotifier(ref.watch(apiServiceProvider));
});

// Leaderboard Provider
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final ApiService _api;

  LeaderboardNotifier(this._api) : super(LeaderboardState());

  Future<void> loadLeaderboard({
    String? type,
    String? period,
    String? metric,
  }) async {
    final newType = type ?? state.type;
    final newPeriod = period ?? state.period;
    final newMetric = metric ?? state.metric;

    state = state.copyWith(
      isLoading: true,
      error: null,
      type: newType,
      period: newPeriod,
      metric: newMetric,
    );

    try {
      final response = await _api.get(
          '/social/leaderboard?type=$newType&period=$newPeriod&metric=$newMetric');

      final entries = (response['leaderboard'] as List)
          .map((e) => LeaderboardEntry.fromJson(e))
          .toList();
      final userRank = UserRank.fromJson(response['userRank']);

      state = state.copyWith(
        entries: entries,
        userRank: userRank,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  return LeaderboardNotifier(ref.watch(apiServiceProvider));
});
