import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import '../../core/ai/web_browsing_service.dart';
import 'message.dart';
import 'stream_provider.dart';
import '../subscription/services/credit_manager.dart';

import 'services/suggestion_service.dart';

class ChatNotifier extends StateNotifier<List<Message>> {
  ChatNotifier(this.ref) : super([]) {
    _loadHistory();
  }

  final Ref ref;

  // Web browsing state
  bool _isWebBrowsing = false;
  WebBrowsingUpdate? _currentBrowsingUpdate;

  bool get isWebBrowsing => _isWebBrowsing;
  WebBrowsingUpdate? get currentBrowsingUpdate => _currentBrowsingUpdate;

  Future<void> _loadHistory() async {
    try {
      final history =
          await ref.read(apiServiceProvider).getChatHistory(notebookId: null);
      state = history
          .map((data) => Message(
                id: data['id'],
                text: data['content'],
                isUser: data['role'] == 'user',
                timestamp: DateTime.parse(data['created_at']),
              ))
          .toList();
    } catch (e) {
      // Log error for debugging but don't crash - chat can work without history
      debugPrint('Error loading chat history: $e');
    }
  }

  void addAIMessage(String text) {
    // Also save this if used?
    final aiMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    state = [...state, aiMsg];
  }

  /// Send message with optional web browsing mode
  Future<void> send(String text,
      {bool useDeepSearch = false,
      bool useWebBrowsing = false,
      String? imagePath,
      Uint8List? imageBytes}) async {
    // Save to backend
    try {
      await ref.read(apiServiceProvider).saveChatMessage(
            role: 'user',
            content: text,
          );
    } catch (_) {}

    final userMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      imageUrl: imagePath,
    );
    state = [...state, userMsg];

    // Use web browsing mode if enabled
    if (useWebBrowsing) {
      await _handleWebBrowsing(text);
      return;
    }

    // Pass chat history to stream provider for context
    final chatHistory = state.where((m) => m.id != userMsg.id).toList();
    final stream = ref.read(streamProvider.notifier).ask(
          text,
          chatHistory: chatHistory,
          useDeepSearch: useDeepSearch,
          imageBytes: imageBytes,
        );

    StringBuffer buffer = StringBuffer();
    List<Citation> citations = [];

    // Add initial placeholder AI message
    final placeholderMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      isDeepSearch: useDeepSearch,
    );
    state = [...state, placeholderMsg];

    try {
      await for (final tokens in stream) {
        for (final t in tokens) {
          t.when(
            text: (txt) => buffer.write(txt),
            citation: (id, snippet) {
              final parts = id.split('::');
              final chunkId = parts.isNotEmpty ? parts.first : id;
              final sourceId = parts.length > 1 ? parts[1] : 's1';
              citations.add(Citation(
                  id: chunkId,
                  sourceId: sourceId,
                  snippet: snippet,
                  start: 0,
                  end: 10));
            },
            done: () {},
          );
        }

        final aiMsg = Message(
          id: placeholderMsg.id,
          text: buffer.toString(),
          isUser: false,
          timestamp: DateTime.now(),
          citations: citations,
          isDeepSearch: useDeepSearch,
        );
        state = [...state.sublist(0, state.length - 1), aiMsg];
      }
    } catch (e) {
      debugPrint('Error in AI stream: $e');
      // Update the placeholder with an error message
      final errorMsg = Message(
        id: placeholderMsg.id,
        text: buffer.isEmpty
            ? '⚠️ Sorry, something went wrong. Please try again.'
            : '${buffer.toString()}\n\n⚠️ *Response interrupted due to an error.*',
        isUser: false,
        timestamp: DateTime.now(),
        isDeepSearch: useDeepSearch,
      );
      state = [...state.sublist(0, state.length - 1), errorMsg];
    }

    // Save AI response
    try {
      await ref.read(apiServiceProvider).saveChatMessage(
            role: 'model',
            content: buffer.toString(),
          );
    } catch (_) {}

    // Generate Smart Suggestions
    _generateSuggestions();
  }

  /// Handle web browsing mode with real-time updates
  Future<void> _handleWebBrowsing(String query) async {
    // Check credits first
    final creditManager = ref.read(creditManagerProvider);
    if (creditManager.currentBalance <= 0) {
      final errorMsg = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            '⚠️ **Insufficient Credits**\n\nYou do not have enough credits to send this message.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = [...state, errorMsg];
      return;
    }

    _isWebBrowsing = true;
    _currentBrowsingUpdate = null;

    // Add placeholder AI message
    final placeholderMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: '🌐 Browsing the web...',
      isUser: false,
      timestamp: DateTime.now(),
      isWebBrowsing: true,
    );
    state = [...state, placeholderMsg];

    final webService = ref.read(webBrowsingServiceProvider);
    final screenshots = <String>[];

    await for (final update in webService.browse(query: query)) {
      _currentBrowsingUpdate = update;

      // Collect screenshots
      if (update.screenshotUrl != null &&
          !screenshots.contains(update.screenshotUrl)) {
        screenshots.add(update.screenshotUrl!);
      }

      // Update the message with current status
      final statusMsg = Message(
        id: placeholderMsg.id,
        text: update.isComplete
            ? update.finalResponse ?? 'No response generated'
            : '🌐 ${update.status}',
        isUser: false,
        timestamp: DateTime.now(),
        isWebBrowsing: true,
        webBrowsingStatus: update.status,
        webBrowsingScreenshots: screenshots,
        webBrowsingSources: update.sources,
        isDeepSearch: true,
      );

      state = [...state.sublist(0, state.length - 1), statusMsg];
    }

    _isWebBrowsing = false;
    _currentBrowsingUpdate = null;

    // Consume credits after successful browsing
    try {
      await creditManager.useCredits(
          amount: CreditCosts.chatMessage * 3, feature: 'web_browsing_chat');
    } catch (e) {
      debugPrint('Error consuming credits: $e');
    }

    // Save AI response
    if (state.isNotEmpty && !state.last.isUser) {
      try {
        await ref.read(apiServiceProvider).saveChatMessage(
              role: 'model',
              content: state.last.text,
            );
      } catch (_) {}
    }

    // Generate Smart Suggestions
    _generateSuggestions();
  }

  Future<void> _generateSuggestions() async {
    // Only generate if the last message is from AI
    if (state.isEmpty || state.last.isUser) return;

    final suggestionService = ref.read(suggestionServiceProvider);
    final suggestions =
        await suggestionService.generateSuggestions(history: state);

    if (suggestions.questions.isNotEmpty || suggestions.sources.isNotEmpty) {
      final lastMsg = state.last;

      if (!lastMsg.isUser) {
        final updatedMsg = lastMsg.copyWith(
          suggestedQuestions: suggestions.questions,
          relatedSources: suggestions.sources,
        );
        state = [...state.sublist(0, state.length - 1), updatedMsg];
      }
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<Message>>(
    (ref) => ChatNotifier(ref));
