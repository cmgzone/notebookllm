import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import 'models/message.dart';
import 'models/study_group.dart';

// State classes
class ConversationsState {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;

  ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  ConversationsState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DirectChatState {
  final String? otherUserId;
  final String? otherUsername;
  final List<Message> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  DirectChatState({
    this.otherUserId,
    this.otherUsername,
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  DirectChatState copyWith({
    String? otherUserId,
    String? otherUsername,
    List<Message>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return DirectChatState(
      otherUserId: otherUserId ?? this.otherUserId,
      otherUsername: otherUsername ?? this.otherUsername,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class GroupChatState {
  final String? groupId;
  final String? groupName;
  final GroupRole? groupRole;
  final List<GroupMessage> messages;
  final List<PendingGroupMessage> pendingMessages;
  final List<GroupMessage> pinnedMessages;
  final bool isLoading;
  final bool isLoadingPins;
  final bool hasMore;
  final String? error;

  GroupChatState({
    this.groupId,
    this.groupName,
    this.groupRole,
    this.messages = const [],
    this.pendingMessages = const [],
    this.pinnedMessages = const [],
    this.isLoading = false,
    this.isLoadingPins = false,
    this.hasMore = true,
    this.error,
  });

  GroupChatState copyWith({
    String? groupId,
    String? groupName,
    GroupRole? groupRole,
    List<GroupMessage>? messages,
    List<PendingGroupMessage>? pendingMessages,
    List<GroupMessage>? pinnedMessages,
    bool? isLoading,
    bool? isLoadingPins,
    bool? hasMore,
    String? error,
  }) {
    return GroupChatState(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      groupRole: groupRole ?? this.groupRole,
      messages: messages ?? this.messages,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      pinnedMessages: pinnedMessages ?? this.pinnedMessages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingPins: isLoadingPins ?? this.isLoadingPins,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

enum PendingSendStatus { sending, failed }

class PendingGroupMessage {
  final String tempId;
  final String content;
  final DateTime createdAt;
  final PendingSendStatus status;
  final String? replyToId;
  final String? replyToContent;

  PendingGroupMessage({
    required this.tempId,
    required this.content,
    required this.createdAt,
    required this.status,
    this.replyToId,
    this.replyToContent,
  });

  PendingGroupMessage copyWith({
    String? tempId,
    String? content,
    DateTime? createdAt,
    PendingSendStatus? status,
    String? replyToId,
    String? replyToContent,
  }) {
    return PendingGroupMessage(
      tempId: tempId ?? this.tempId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
      replyToContent: replyToContent ?? this.replyToContent,
    );
  }
}

// Conversations Provider
class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final ApiService _api;

  ConversationsNotifier(this._api) : super(ConversationsState());

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/messaging/conversations');
      final conversations = (response['conversations'] as List)
          .map((c) => Conversation.fromJson(c))
          .toList();
      state = state.copyWith(conversations: conversations, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void updateConversation(Conversation updated) {
    final conversations = state.conversations.map((c) {
      return c.id == updated.id ? updated : c;
    }).toList();
    state = state.copyWith(conversations: conversations);
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  return ConversationsNotifier(ref.watch(apiServiceProvider));
});

// Direct Chat Provider
class DirectChatNotifier extends StateNotifier<DirectChatState> {
  final ApiService _api;

  DirectChatNotifier(this._api) : super(DirectChatState());

  Future<void> openChat(String userId, String username) async {
    state = DirectChatState(
      otherUserId: userId,
      otherUsername: username,
      isLoading: true,
    );
    await loadMessages();
  }

  Future<void> loadMessages({bool loadMore = false}) async {
    if (state.otherUserId == null) return;
    if (state.isLoading && loadMore) return; // Only skip if loading more

    if (!loadMore) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      String url = '/messaging/direct/${state.otherUserId}?limit=50';
      if (loadMore && state.messages.isNotEmpty) {
        url += '&before=${state.messages.first.id}';
      }

      final response = await _api.get(url);
      final messages = (response['messages'] as List)
          .map((m) => Message.fromJson(m))
          .toList();

      state = state.copyWith(
        messages: loadMore ? [...messages, ...state.messages] : messages,
        isLoading: false,
        hasMore: messages.length >= 50,
        error: null,
      );

      // Mark as read
      if (state.otherUserId != null) {
        await _api.post('/messaging/direct/${state.otherUserId}/read', {});
      }
    } catch (e) {
      final errorMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  Future<void> sendMessage(String content) async {
    if (state.otherUserId == null || content.trim().isEmpty) return;

    try {
      final response =
          await _api.post('/messaging/direct/${state.otherUserId}', {
        'content': content.trim(),
      });
      final message = Message.fromJson(response['message']);
      state = state.copyWith(messages: [...state.messages, message]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  void addMessage(Message message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void closeChat() {
    state = DirectChatState();
  }
}

final directChatProvider =
    StateNotifierProvider<DirectChatNotifier, DirectChatState>((ref) {
  return DirectChatNotifier(ref.watch(apiServiceProvider));
});

// Group Chat Provider
class GroupChatNotifier extends StateNotifier<GroupChatState> {
  final ApiService _api;

  GroupChatNotifier(this._api) : super(GroupChatState());

  Future<void> openChat(String groupId, String groupName) async {
    state = GroupChatState(
      groupId: groupId,
      groupName: groupName,
      isLoading: true,
    );
    await Future.wait([
      loadMessages(),
      _loadGroupDetails(),
      loadPinnedMessages(),
    ]);
  }

  Future<void> loadMessages({bool loadMore = false}) async {
    if (state.groupId == null) return;
    if (state.isLoading && loadMore) return; // Only skip if loading more

    state = state.copyWith(isLoading: true, error: null);
    try {
      String url = '/messaging/groups/${state.groupId}?limit=50';
      if (loadMore && state.messages.isNotEmpty) {
        url += '&before=${state.messages.first.id}';
      }

      final response = await _api.get(url);
      final messages = (response['messages'] as List)
          .map((m) => GroupMessage.fromJson(m))
          .toList();

      state = state.copyWith(
        messages: loadMore ? [...messages, ...state.messages] : messages,
        isLoading: false,
        hasMore: messages.length >= 50,
      );

      // Mark as read
      if (state.groupId != null && state.messages.isNotEmpty) {
        await _api.post('/messaging/groups/${state.groupId}/read', {
          'lastMessageId': state.messages.last.id,
        });
      }
    } catch (e) {
      final errorMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  Future<void> loadPinnedMessages() async {
    if (state.groupId == null) return;
    state = state.copyWith(isLoadingPins: true);
    try {
      final response = await _api.get('/messaging/groups/${state.groupId}/pins');
      final list = response['messages'] as List? ?? [];
      final messages =
          list.map((m) => GroupMessage.fromJson(m)).toList();
      state = state.copyWith(pinnedMessages: messages, isLoadingPins: false);
    } catch (e) {
      state = state.copyWith(isLoadingPins: false);
    }
  }

  Future<void> _loadGroupDetails() async {
    if (state.groupId == null) return;
    try {
      final response = await _api.get('/social/groups/${state.groupId}');
      final group = StudyGroup.fromJson(response['group']);
      state = state.copyWith(
        groupName: group.name,
        groupRole: group.role,
      );
    } catch (e) {
      // Ignore group detail errors to avoid blocking chat
    }
  }

  Future<void> sendMessage(String content, {String? replyToId}) async {
    if (state.groupId == null || content.trim().isEmpty) return;

    final tempId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final pending = PendingGroupMessage(
      tempId: tempId,
      content: content.trim(),
      createdAt: DateTime.now(),
      status: PendingSendStatus.sending,
      replyToId: replyToId,
      replyToContent: _findReplyPreview(replyToId),
    );

    state = state.copyWith(
      pendingMessages: [...state.pendingMessages, pending],
      error: null,
    );

    try {
      final response = await _api.post('/messaging/groups/${state.groupId}', {
        'content': content.trim(),
        if (replyToId != null) 'replyToId': replyToId,
      });
      final message = GroupMessage.fromJson(response['message']);
      state = state.copyWith(
        messages: [...state.messages, message],
        pendingMessages:
            state.pendingMessages.where((m) => m.tempId != tempId).toList(),
      );
    } catch (e) {
      final errorMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      state = state.copyWith(
        error: errorMsg,
        pendingMessages: state.pendingMessages
            .map((m) =>
                m.tempId == tempId ? m.copyWith(status: PendingSendStatus.failed) : m)
            .toList(),
      );
      rethrow;
    }
  }

  Future<void> retryPendingMessage(String tempId) async {
    final pending =
        state.pendingMessages.firstWhere((m) => m.tempId == tempId, orElse: () {
      return PendingGroupMessage(
        tempId: tempId,
        content: '',
        createdAt: DateTime.now(),
        status: PendingSendStatus.failed,
      );
    });

    if (pending.content.trim().isEmpty) return;

    state = state.copyWith(
      pendingMessages: state.pendingMessages
          .map((m) => m.tempId == tempId
              ? m.copyWith(status: PendingSendStatus.sending)
              : m)
          .toList(),
      error: null,
    );

    try {
      final response = await _api.post('/messaging/groups/${state.groupId}', {
        'content': pending.content.trim(),
        if (pending.replyToId != null) 'replyToId': pending.replyToId,
      });
      final message = GroupMessage.fromJson(response['message']);
      state = state.copyWith(
        messages: [...state.messages, message],
        pendingMessages:
            state.pendingMessages.where((m) => m.tempId != tempId).toList(),
      );
    } catch (e) {
      final errorMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      state = state.copyWith(
        error: errorMsg,
        pendingMessages: state.pendingMessages
            .map((m) => m.tempId == tempId
                ? m.copyWith(status: PendingSendStatus.failed)
                : m)
            .toList(),
      );
    }
  }

  void addMessage(GroupMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  Future<void> editMessage(String messageId, String content) async {
    if (state.groupId == null) return;
    final response = await _api.patch(
      '/messaging/groups/${state.groupId}/messages/$messageId',
      {'content': content},
    );
    final updated = GroupMessage.fromJson(response['message']);
    _replaceMessage(updated);
  }

  Future<void> deleteMessage(String messageId) async {
    if (state.groupId == null) return;
    final response = await _api.delete(
      '/messaging/groups/${state.groupId}/messages/$messageId',
    );
    final updated = GroupMessage.fromJson(response['message']);
    _replaceMessage(updated);
    state = state.copyWith(
      pinnedMessages:
          state.pinnedMessages.where((m) => m.id != messageId).toList(),
    );
  }

  Future<void> addReaction(String messageId, String reactionType) async {
    if (state.groupId == null) return;
    final response = await _api.post(
      '/messaging/groups/${state.groupId}/messages/$messageId/reactions',
      {'reactionType': reactionType},
    );
    final updated = GroupMessage.fromJson(response['message']);
    _replaceMessage(updated);
  }

  Future<void> removeReaction(String messageId) async {
    if (state.groupId == null) return;
    final response = await _api.delete(
      '/messaging/groups/${state.groupId}/messages/$messageId/reactions',
    );
    final updated = GroupMessage.fromJson(response['message']);
    _replaceMessage(updated);
  }

  Future<void> pinMessage(String messageId) async {
    if (state.groupId == null) return;
    final response = await _api.post(
      '/messaging/groups/${state.groupId}/messages/$messageId/pin',
      {},
    );
    final updated = GroupMessage.fromJson(response['message']);
    _replaceMessage(updated);
    await loadPinnedMessages();
  }

  Future<void> unpinMessage(String messageId) async {
    if (state.groupId == null) return;
    final response = await _api.delete(
      '/messaging/groups/${state.groupId}/messages/$messageId/pin',
    );
    final updated = GroupMessage.fromJson(response['message']);
    _replaceMessage(updated);
    await loadPinnedMessages();
  }

  Future<List<GroupMessage>> loadThread(String messageId,
      {int limit = 50, String? before}) async {
    if (state.groupId == null) return [];
    String url =
        '/messaging/groups/${state.groupId}/threads/$messageId?limit=$limit';
    if (before != null) {
      url += '&before=$before';
    }
    final response = await _api.get(url);
    return (response['messages'] as List)
        .map((m) => GroupMessage.fromJson(m))
        .toList();
  }

  void closeChat() {
    state = GroupChatState();
  }

  String? _findReplyPreview(String? replyToId) {
    if (replyToId == null) return null;
    final match = state.messages.firstWhere(
      (m) => m.id == replyToId,
      orElse: () => GroupMessage(
        id: replyToId,
        senderId: '',
        senderUsername: 'Unknown',
        content: '',
        createdAt: DateTime.now(),
        groupId: state.groupId ?? '',
      ),
    );
    if (match.content.isEmpty) return null;
    return '${match.senderUsername}: ${match.content}';
  }

  void _replaceMessage(GroupMessage updated) {
    final messages =
        state.messages.map((m) => m.id == updated.id ? updated : m).toList();
    final pinned = state.pinnedMessages
        .map((m) => m.id == updated.id ? updated : m)
        .toList();
    state = state.copyWith(messages: messages, pinnedMessages: pinned);
  }
}

final groupChatProvider =
    StateNotifierProvider<GroupChatNotifier, GroupChatState>((ref) {
  return GroupChatNotifier(ref.watch(apiServiceProvider));
});

// Unread counts provider
final unreadCountsProvider = FutureProvider<UnreadCounts>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.get('/messaging/unread');
  return UnreadCounts.fromJson(response);
});
