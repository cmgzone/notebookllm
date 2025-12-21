import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'stream_token.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/ai/openrouter_service.dart';
import '../../core/security/global_credentials_service.dart';
import '../../core/services/wakelock_service.dart';
import '../sources/source_provider.dart';
import '../gamification/gamification_provider.dart';
import '../../core/search/serper_service.dart';
import 'message.dart';

class StreamNotifier extends StateNotifier<List<StreamToken>> {
  StreamNotifier(this.ref) : super([]);
  final Ref ref;
  final GeminiService _geminiService = GeminiService();
  final OpenRouterService _openRouterService = OpenRouterService();
  late final SerperService _serperService = SerperService(ref);

  Future<String> _getSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ai_provider') ?? 'gemini';
  }

  Future<String> _getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ai_model') ?? 'gemini-2.0-flash-exp';
  }

  String _buildContextualPrompt(String query, List<Message> chatHistory,
      {String? webResults}) {
    final sources = ref.read(sourceProvider);

    final buffer = StringBuffer();

    // Add sources context
    buffer.writeln('=== AVAILABLE SOURCES ===');
    if (sources.isEmpty) {
      buffer.writeln('You have 0 sources available.');
      buffer.writeln(
          'If the user asks about their sources, inform them that no sources have been added yet.');
    } else {
      buffer.writeln(
          'You have access to ${sources.length} sources. Use them to provide accurate, cited responses:');
      buffer.writeln();

      for (final source in sources.take(10)) {
        // Limit to 10 sources to avoid token limits
        buffer.writeln('Source: ${source.title}');
        buffer.writeln('Type: ${source.type}');
        // Limit content to first 500 chars per source
        final content = source.content.length > 500
            ? '${source.content.substring(0, 500)}...'
            : source.content;
        buffer.writeln('Content: $content');
        buffer.writeln();
      }

      if (sources.length > 10) {
        buffer
            .writeln('... and ${sources.length - 10} more sources available.');
      }
    }
    buffer.writeln('=== END SOURCES ===');
    buffer.writeln();

    // Add chat history (last 5 messages for context)
    if (chatHistory.isNotEmpty) {
      buffer.writeln('=== CONVERSATION HISTORY ===');
      final recentMessages = chatHistory.length > 5
          ? chatHistory.sublist(chatHistory.length - 5)
          : chatHistory;

      for (final msg in recentMessages) {
        buffer.writeln('${msg.isUser ? "User" : "Assistant"}: ${msg.text}');
      }

      // Add web search results if available
      if (webResults != null && webResults.isNotEmpty) {
        buffer.writeln('=== WEB SEARCH RESULTS ===');
        buffer.writeln(
            'Use these recent search results to answer the user query:');
        buffer.writeln(webResults);
        buffer.writeln('=== END WEB SEARCH RESULTS ===');
        buffer.writeln();
      }
      buffer.writeln('=== END HISTORY ===');
      buffer.writeln();
    }

    // Add current query
    buffer.writeln('=== CURRENT QUESTION ===');
    buffer.writeln(query);
    buffer.writeln();
    buffer.writeln('=== INSTRUCTIONS ===');
    buffer.writeln('1. Answer the question based on the sources provided.');
    buffer.writeln(
        '2. Use Markdown formatting to make your response visually appealing and easy to read:');
    buffer.writeln('   - Use **bold** for emphasis and key terms');
    buffer.writeln('   - Use headers (###) to structure your response');
    buffer.writeln('   - Use bullet points for lists');
    buffer.writeln('   - Use `code blocks` for any code snippets');
    buffer.writeln('   - Use > blockquotes for direct quotes from sources');
    buffer.writeln('3. Be concise and professional.');
    buffer.writeln('4. **Notebook Creation**:');
    buffer.writeln(
        '   - If the user explicitly asks to create a notebook (e.g., "Create a notebook about Space"), output ONLY the following command on a new line:');
    buffer.writeln('     `[[CREATE_NOTEBOOK: Title of Notebook]]`');
    buffer.writeln(
        '   - Replace "Title of Notebook" with the actual title requested or a suitable one.');
    buffer.writeln(
        '   - Follow this command with a brief confirmation message to the user.');
    buffer.writeln('5. **Ebook Creation**:');
    buffer.writeln(
        '   - If the user explicitly asks to create an ebook (e.g., "Create an ebook about AI"), output ONLY the following command on a new line:');
    buffer.writeln('     `[[CREATE_EBOOK: Title | Topic]]`');
    buffer.writeln(
        '   - Replace "Title" with a catchy title and "Topic" with the subject matter.');
    buffer.writeln(
        '   - Follow this command with a brief confirmation message to the user.');

    return buffer.toString();
  }

  Future<String?> _getApiKey(String provider) async {
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      return await creds.getApiKey(provider);
    } catch (e) {
      return null;
    }
  }

  /// Ask a question and get a stream of tokens back
  Stream<List<StreamToken>> ask(String query,
      {List<Message> chatHistory = const [],
      bool useDeepSearch = false}) async* {
    // Keep screen awake during AI generation
    await wakelockService.acquire();

    try {
      final provider = await _getSelectedProvider();
      final model = await _getSelectedModel();

      String? webResults;
      if (useDeepSearch) {
        // Yield a token to indicate searching
        yield [const StreamToken.text(text: '*Searching the web...*\n\n')];
        webResults = await _performWebSearch(query);
      }

      // Build contextual prompt with sources and history
      final contextualPrompt =
          _buildContextualPrompt(query, chatHistory, webResults: webResults);

      final String response;
      if (provider == 'openrouter') {
        // Use OpenRouter
        final apiKey = await _getApiKey('openrouter');
        response = await _openRouterService.generateContent(contextualPrompt,
            model: model, apiKey: apiKey);
      } else {
        // Use Gemini's streaming API
        final apiKey = await _getApiKey('gemini');
        response = await _geminiService.generateStream(contextualPrompt,
            model: model, apiKey: apiKey);
      }

      // Stream the response word by word for smooth UI updates
      final words = response.split(' ');
      for (int i = 0; i < words.length; i++) {
        final chunk = i == 0 ? words[i] : ' ${words[i]}';
        final tokens = <StreamToken>[
          StreamToken.text(text: chunk),
        ];
        state = [...state, ...tokens];
        yield tokens;

        // Small delay for smooth streaming effect
        await Future.delayed(const Duration(milliseconds: 30));
      }

      // Signal completion
      const doneToken = StreamToken.done();
      state = [...state, doneToken];
      yield [doneToken];

      // Track gamification
      ref.read(gamificationProvider.notifier).trackChatMessage();
      ref.read(gamificationProvider.notifier).trackFeatureUsed('chat');
    } catch (e) {
      // Handle errors
      final errorToken = StreamToken.text(text: 'Error: $e');
      state = [...state, errorToken];
      yield [errorToken];
    } finally {
      // Release wake lock when done
      await wakelockService.release();
    }
  }

  Future<String> _performWebSearch(String query) async {
    try {
      final results = await _serperService.search(query, num: 5);
      if (results.isEmpty) return '';

      final buffer = StringBuffer();
      for (final result in results) {
        buffer.writeln('Title: ${result.title}');
        buffer.writeln('URL: ${result.link}');
        buffer.writeln('Snippet: ${result.snippet}');

        // Try to fetch content for top 2 results for more depth
        if (results.indexOf(result) < 2) {
          try {
            final content = await _serperService.fetchPageContent(result.link);
            if (content.isNotEmpty) {
              buffer.writeln(
                  'Content: ${content.length > 1000 ? "${content.substring(0, 1000)}..." : content}');
            }
          } catch (_) {}
        }
        buffer.writeln('---');
      }
      return buffer.toString();
    } catch (e) {
      return 'Error performing web search: $e';
    }
  }
}

final streamProvider = StateNotifierProvider<StreamNotifier, List<StreamToken>>(
    (ref) => StreamNotifier(ref));
