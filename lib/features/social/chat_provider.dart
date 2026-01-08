import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import 'models/message.dart';

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
  final List<GroupMessage> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  GroupChatState({
    this.groupId,
    this.groupName,
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  GroupChatState copyWith({
    String? groupId,
    String? groupName,
    List<GroupMessage>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return GroupChatState(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
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
    if (state.isLoading && !loadMore) return;

    state = state.copyWith(isLoading: true, error: null);
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
      );

      // Mark as read
      if (state.otherUserId != null) {
        await _api.post('/messaging/direct/${state.otherUserId}/read', {});
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
    await loadMessages();
  }

  Future<void> loadMessages({bool loadMore = false}) async {
    if (state.groupId == null) return;
    if (state.isLoading && !loadMore) return;

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
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendMessage(String content, {String? replyToId}) async {
    if (state.groupId == null || content.trim().isEmpty) return;

    try {
      final response = await _api.post('/messaging/groups/${state.groupId}', {
        'content': content.trim(),
        if (replyToId != null) 'replyToId': replyToId,
      });
      final message = GroupMessage.fromJson(response['message']);
      state = state.copyWith(messages: [...state.messages, message]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  void addMessage(GroupMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void closeChat() {
    state = GroupChatState();
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
