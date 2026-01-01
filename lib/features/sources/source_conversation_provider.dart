import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../core/api/api_service.dart';

/// Message model for source conversations
/// Requirements: 3.5
class SourceMessage {
  final String id;
  final String sourceId;
  final String role; // 'user' or 'agent'
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final bool isRead;

  const SourceMessage({
    required this.id,
    required this.sourceId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
    this.isRead = false,
  });

  factory SourceMessage.fromJson(Map<String, dynamic> json) {
    return SourceMessage(
      id: json['id'] as String,
      sourceId:
          json['source_id'] as String? ?? json['sourceId'] as String? ?? '',
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : json['timestamp'] != null
              ? DateTime.parse(json['timestamp'] as String)
              : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  bool get isUser => role == 'user';
  bool get isAgent => role == 'agent';

  /// Check if this message contains a code update
  bool get hasCodeUpdate => metadata != null && metadata!['codeUpdate'] != null;

  /// Get the code update if present
  Map<String, dynamic>? get codeUpdate =>
      metadata?['codeUpdate'] as Map<String, dynamic>?;
}

/// State for a source conversation
class SourceConversationState {
  final String sourceId;
  final List<SourceMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String? agentSessionId;
  final DateTime? lastMessageAt;

  const SourceConversationState({
    required this.sourceId,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.agentSessionId,
    this.lastMessageAt,
  });

  SourceConversationState copyWith({
    String? sourceId,
    List<SourceMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    String? agentSessionId,
    DateTime? lastMessageAt,
  }) {
    return SourceConversationState(
      sourceId: sourceId ?? this.sourceId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      agentSessionId: agentSessionId ?? this.agentSessionId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  bool get hasMessages => messages.isNotEmpty;
  int get messageCount => messages.length;
  int get unreadCount => messages.where((m) => !m.isRead && m.isAgent).length;
}

/// Provider for managing source conversation state
/// Requirements: 3.5
class SourceConversationNotifier
    extends StateNotifier<SourceConversationState> {
  final Ref ref;
  final String sourceId;

  SourceConversationNotifier(this.ref, this.sourceId)
      : super(SourceConversationState(sourceId: sourceId)) {
    loadConversation();
  }

  /// Load conversation history from the API
  Future<void> loadConversation() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getSourceConversation(sourceId);

      final conversation = response['conversation'];
      final messagesData = response['messages'] as List<dynamic>? ?? [];

      final messages = messagesData
          .map((m) => SourceMessage.fromJson(m as Map<String, dynamic>))
          .toList();

      // Sort messages by timestamp
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      state = state.copyWith(
        messages: messages,
        isLoading: false,
        agentSessionId: conversation?['agent_session_id'] as String?,
        lastMessageAt: messages.isNotEmpty ? messages.last.timestamp : null,
      );

      debugPrint('✅ Loaded ${messages.length} messages for source $sourceId');
    } catch (e) {
      debugPrint('❌ Error loading conversation: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Send a follow-up message to the agent
  /// Requirements: 3.2
  Future<bool> sendMessage(String message) async {
    if (message.trim().isEmpty) return false;

    state = state.copyWith(isSending: true, error: null);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.sendFollowupMessage(sourceId, message);

      // Add the user's message to the local state immediately
      final userMessage = SourceMessage(
        id: response['message']?['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        sourceId: sourceId,
        role: 'user',
        content: message,
        timestamp: DateTime.now(),
        isRead: true,
      );

      final updatedMessages = [...state.messages, userMessage];

      // If there's an agent response, add it too
      if (response['agentResponse'] != null) {
        final agentMessage = SourceMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}_agent',
          sourceId: sourceId,
          role: 'agent',
          content: response['agentResponse'] as String,
          timestamp: DateTime.now().add(const Duration(milliseconds: 100)),
          metadata:
              response['codeUpdated'] == true ? {'codeUpdate': true} : null,
          isRead: false,
        );
        updatedMessages.add(agentMessage);
      }

      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
        lastMessageAt: DateTime.now(),
      );

      debugPrint('✅ Message sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Add a message locally (for optimistic updates)
  void addLocalMessage(SourceMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
      lastMessageAt: message.timestamp,
    );
  }

  /// Refresh the conversation
  Future<void> refresh() async {
    await loadConversation();
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Family provider for source conversations
/// Each source has its own conversation state
final sourceConversationProvider = StateNotifierProvider.family<
    SourceConversationNotifier, SourceConversationState, String>(
  (ref, sourceId) => SourceConversationNotifier(ref, sourceId),
);

/// Provider to check if a source has an agent session
final sourceHasAgentProvider = FutureProvider.family<bool, String>(
  (ref, sourceId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getSourceConversation(sourceId);
      final conversation = response['conversation'];
      return conversation != null && conversation['agent_session_id'] != null;
    } catch (e) {
      return false;
    }
  },
);
