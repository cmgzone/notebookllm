import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'message.dart';
import 'stream_provider.dart';
import '../notebook/notebook_provider.dart';
import 'package:uuid/uuid.dart';
import '../ebook/ebook_provider.dart';
import '../ebook/models/ebook_project.dart';
import '../ebook/models/branding_config.dart';
import 'services/suggestion_service.dart';

class ChatNotifier extends StateNotifier<List<Message>> {
  ChatNotifier(this.ref) : super([]);
  final Ref ref;

  void addAIMessage(String text) {
    final aiMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    state = [...state, aiMsg];
  }

  Future<void> send(String text, {bool useDeepSearch = false}) async {
    final userMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = [...state, userMsg];

    // Pass chat history to stream provider for context
    final chatHistory = state.where((m) => m.id != userMsg.id).toList();
    final stream = ref.read(streamProvider.notifier).ask(
          text,
          chatHistory: chatHistory,
          useDeepSearch: useDeepSearch,
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
      );
      state = [...state.sublist(0, state.length - 1), aiMsg];
    }

    // Post-processing: Check for commands
    final fullText = buffer.toString();
    final notebookRegex = RegExp(r'\[\[CREATE_NOTEBOOK:\s*(.*?)\]\]');
    final match = notebookRegex.firstMatch(fullText);

    if (match != null) {
      final title = match.group(1)?.trim();
      if (title != null && title.isNotEmpty) {
        final cleanText = fullText.replaceAll(notebookRegex, '').trim();

        // Update the last message with clean text
        final lastMsg = state.last;
        final updatedMsg = lastMsg.copyWith(text: cleanText);
        state = [...state.sublist(0, state.length - 1), updatedMsg];

        _createNotebook(title);
      }
    }

    // Check for ebook creation command
    final ebookRegex = RegExp(r'\[\[CREATE_EBOOK:\s*(.*?)\]\]');
    final ebookMatch = ebookRegex.firstMatch(fullText);

    if (ebookMatch != null) {
      final content = ebookMatch.group(1)?.trim();
      if (content != null && content.isNotEmpty) {
        final parts = content.split('|');
        final title = parts[0].trim();
        final topic = parts.length > 1 ? parts[1].trim() : title;

        final cleanText = fullText.replaceAll(ebookRegex, '').trim();

        // Update the last message with clean text
        final lastMsg = state.last;
        final updatedMsg = lastMsg.copyWith(text: cleanText);
        state = [...state.sublist(0, state.length - 1), updatedMsg];

        await _createEbook(title, topic);
      }
    }

    // Generate Smart Suggestions
    _generateSuggestions();
  }

  void _createNotebook(String title) {
    ref.read(notebookProvider.notifier).addNotebook(title);
  }

  Future<void> _createEbook(String title, String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final currentModel = prefs.getString('ai_model') ?? 'gemini-1.5-flash';

    final id = const Uuid().v4();
    final now = DateTime.now();
    final ebook = EbookProject(
      id: id,
      title: title,
      topic: topic,
      targetAudience: 'General Audience',
      branding: const BrandingConfig(
        primaryColorValue: 0xFF000000,
        fontFamily: 'Roboto',
      ),
      selectedModel: currentModel,
      createdAt: now,
      updatedAt: now,
      status: EbookStatus.draft,
    );
    ref.read(ebookProvider.notifier).addEbook(ebook);
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
