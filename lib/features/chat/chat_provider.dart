import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import 'message.dart';
import 'stream_provider.dart';

import 'services/suggestion_service.dart';

class ChatNotifier extends StateNotifier<List<Message>> {
  ChatNotifier(this.ref) : super([]) {
    _loadHistory();
  }

  final Ref ref;

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
      // Handle error cleanly
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

  Future<void> send(String text,
      {bool useDeepSearch = false,
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
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: buffer.toString(),
        isUser: false,
        timestamp: DateTime.now(),
        citations: citations,
        isDeepSearch: useDeepSearch,
      );
      state = [...state.sublist(0, state.length - 1), aiMsg];
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
