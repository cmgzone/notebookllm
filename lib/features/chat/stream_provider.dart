import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'stream_token.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/ai/openrouter_service.dart';
import '../../core/security/global_credentials_service.dart';
import '../../core/ai/ai_settings_service.dart';
import '../../core/services/wakelock_service.dart';
import '../sources/source_provider.dart';
import '../gamification/gamification_provider.dart';
import '../../core/search/serper_service.dart';
import 'message.dart';
import '../../core/ai/ai_models_provider.dart';
import '../../core/api/api_service.dart';

class StreamNotifier extends StateNotifier<List<StreamToken>> {
  StreamNotifier(this.ref) : super([]);
  final Ref ref;
  final GeminiService _geminiService = GeminiService();
  final OpenRouterService _openRouterService = OpenRouterService();
  late final SerperService _serperService = SerperService(ref);

  Future<String> _getSelectedProvider() async {
    // Get the selected model first
    final model = await AISettingsService.getModel();

    if (model != null && model.isNotEmpty) {
      // Auto-detect provider from the model
      return await AISettingsService.getProviderForModel(model, ref);
    }

    // Fallback to saved provider if no model selected
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ai_provider') ?? 'gemini';
  }

  Future<String> _getSelectedModel() async {
    final settings = await AISettingsService.getSettings();
    if (settings.model == null || settings.model!.isEmpty) {
      throw Exception(
          'No AI model selected. Please configure a model in settings.');
    }
    return settings.model!;
  }

  String _buildContextualPrompt(String query, List<Message> chatHistory,
      {String? webResults, int maxContextChars = 30000}) {
    final sources = ref.read(sourceProvider);

    final buffer = StringBuffer();
    int currentChars = 0;

    // Reserve space for instructions and query (~2000 chars)
    const reservedChars = 2000;
    final availableForContext = maxContextChars - reservedChars;

    // Add sources context (dynamically limited)
    buffer.writeln('=== AVAILABLE SOURCES ===');
    if (sources.isEmpty) {
      buffer.writeln('You have 0 sources available.');
      buffer.writeln(
          'If the user asks about their sources, inform them that no sources have been added yet.');
    } else {
      buffer.writeln(
          'You have access to ${sources.length} sources. Use them to provide accurate, cited responses:');
      buffer.writeln();

      final maxSourceChars =
          (availableForContext * 0.6).toInt(); // 60% for sources
      int sourcesAdded = 0;

      for (final source in sources) {
        if (currentChars >= maxSourceChars) {
          buffer.writeln(
              '... (${sources.length - sourcesAdded} more sources truncated due to context limits)');
          break;
        }

        final sourceHeader = 'Source: ${source.title}\nType: ${source.type}\n';
        // Limit content per source based on remaining space
        final remainingChars = maxSourceChars - currentChars;
        final maxContentLen = (remainingChars * 0.8).toInt().clamp(100, 500);

        final content = source.content.length > maxContentLen
            ? '${source.content.substring(0, maxContentLen)}...'
            : source.content;
        final sourceBlock = '$sourceHeader Content: $content\n\n';

        buffer.write(sourceBlock);
        currentChars += sourceBlock.length;
        sourcesAdded++;
      }
    }
    buffer.writeln('=== END SOURCES ===');
    buffer.writeln();

    // Add chat history (dynamically limited)
    if (chatHistory.isNotEmpty) {
      buffer.writeln('=== CONVERSATION HISTORY ===');
      final maxHistoryChars =
          (availableForContext * 0.2).toInt(); // 20% for history
      int historyChars = 0;

      // Take recent messages, but limit by character count
      final recentMessages = chatHistory.length > 10
          ? chatHistory.sublist(chatHistory.length - 10)
          : chatHistory;

      final historyBuffer = StringBuffer();
      for (final msg in recentMessages.reversed) {
        final msgText = '${msg.isUser ? "User" : "Assistant"}: ${msg.text}\n';
        if (historyChars + msgText.length > maxHistoryChars) break;
        historyBuffer.write(msgText);
        historyChars += msgText.length;
      }
      buffer.write(historyBuffer.toString().split('\n').reversed.join('\n'));

      // Add web search results if available (limited)
      if (webResults != null && webResults.isNotEmpty) {
        buffer.writeln('=== WEB SEARCH RESULTS ===');
        buffer.writeln(
            'Use these recent search results to answer the user query:');
        final maxWebChars = (availableForContext * 0.2).toInt(); // 20% for web
        if (webResults.length > maxWebChars) {
          buffer.writeln('${webResults.substring(0, maxWebChars)}...');
        } else {
          buffer.writeln(webResults);
        }
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
      bool useDeepSearch = false,
      Uint8List? imageBytes}) async* {
    // Keep screen awake during AI generation
    await wakelockService.acquire();

    try {
      final provider = await _getSelectedProvider();
      final model = await _getSelectedModel();

      // Determine max context based on model characteristics
      int maxContextChars = 30000; // Default fallback

      try {
        // Try to get dynamic context window from available models
        final modelsAsync = await ref.read(availableModelsProvider.future);
        // Search in all providers
        for (final models in modelsAsync.values) {
          final modelFound = models.where((m) => m.id == model).firstOrNull;
          if (modelFound != null) {
            // Convert tokens to chars (approx 3.5-4 chars per token)
            // Being conservative with 3.5x to leave room for overhead
            maxContextChars = (modelFound.contextWindow * 3.5).toInt();
            break;
          }
        }
      } catch (e) {
        debugPrint(
            '[StreamNotifier] Error fetching dynamic context window: $e');
      }

      // Fallback heuristics if dynamic lookup failed or returned restrictive default
      if (maxContextChars == 30000) {
        if (model.contains('gpt-3.5')) {
          maxContextChars = 12000;
        } else if (model.contains('gpt-4-turbo') || model.contains('gpt-4o')) {
          maxContextChars = 100000;
        } else if (model.contains('gemini-1.5') ||
            model.contains('gemini-2') ||
            model.contains('gemini-3')) {
          maxContextChars = 200000; // Large context for modern Gemini
        } else if (model.contains('claude-3')) {
          maxContextChars = 150000; // Claude 3 has large context
        } else if (model.contains('llama') || model.contains('mistral')) {
          maxContextChars = 30000;
        }
      }

      String? webResults;
      if (useDeepSearch) {
        // Yield a token to indicate searching
        yield [const StreamToken.text(text: '🔍 *Searching the web...*\n\n')];
        webResults = await _performWebSearch(query);
        if (webResults.isNotEmpty) {
          yield [
            const StreamToken.text(text: '✅ *Found relevant results!*\n\n')
          ];
        }
      }

      // Build contextual prompt with sources and history (dynamic context limit)
      final contextualPrompt = _buildContextualPrompt(query, chatHistory,
          webResults: webResults, maxContextChars: maxContextChars);

      String response = '';
      bool streamed = false;

      // Handle image input
      if (imageBytes != null) {
        yield [const StreamToken.text(text: '🖼️ *Analyzing image...*\n\n')];

        if (provider == 'openrouter') {
          final apiKey = await _getApiKey('openrouter');
          // Use vision-capable model for images
          final visionModel = model.contains('gemini') ||
                  model.contains('gpt-4') ||
                  model.contains('claude')
              ? model
              : (await _getSelectedModel()); // Use current model and hope it's vision capable
          response = await _openRouterService.generateWithImage(
            contextualPrompt,
            imageBytes,
            model: visionModel,
            apiKey: apiKey,
          );
        } else {
          // Gemini with image
          final apiKey = await _getApiKey('gemini');
          response = await _geminiService.generateContentWithImage(
            contextualPrompt,
            imageBytes,
            apiKey: apiKey,
            model: model,
          );
        }
      } else {
        // Text generation (fallback to Backend Proxy if no local key)
        final apiKey = await _getApiKey(provider);

        if (apiKey == null || apiKey.isEmpty) {
          // Use Backend Proxy (Admin Keys from Server)
          // We wrap the contextual prompt as a single user message
          final messages = [
            {'role': 'user', 'content': contextualPrompt}
          ];

          final stream = ref.read(apiServiceProvider).chatWithAIStream(
                messages: messages,
                provider: provider,
                model: model,
              );

          await for (final chunk in stream) {
            response += chunk;
            final tokens = [StreamToken.text(text: chunk)];
            state = [...state, ...tokens];
            yield tokens;
          }
          streamed = true;
        } else {
          // Use Client-Side Logic (Local Key)
          if (provider == 'openrouter') {
            response = await _openRouterService.generateContent(
                contextualPrompt,
                model: model,
                apiKey: apiKey);
          } else {
            // Use Gemini's client API
            response = await _geminiService.generateStream(contextualPrompt,
                model: model, apiKey: apiKey);
          }
        }
      }

      if (!streamed && response.isNotEmpty) {
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
      }

      // Signal completion
      const doneToken = StreamToken.done();
      state = [...state, doneToken];
      yield [doneToken];

      // Track gamification
      ref.read(gamificationProvider.notifier).trackChatMessage();
      ref.read(gamificationProvider.notifier).trackFeatureUsed('chat');
      if (imageBytes != null) {
        ref.read(gamificationProvider.notifier).trackFeatureUsed('image_chat');
      }
      if (useDeepSearch) {
        ref.read(gamificationProvider.notifier).trackFeatureUsed('deep_search');
      }
    } catch (e) {
      // Handle errors with better messages
      String errorMessage = e.toString();

      // Detect token limit errors and provide helpful guidance
      // Detect token limit errors and provide helpful guidance
      final lowerError = errorMessage.toLowerCase();

      // Check for API limits first (Quota/Rate)
      if (lowerError.contains('quota') ||
          lowerError.contains('rate') ||
          lowerError.contains('resource exhausted')) {
        errorMessage = '⚠️ **API Limit Reached**\n\n'
            'You\'ve hit the API rate limit or quota. Please wait a moment and try again.';
      } else if (lowerError.contains('token') ||
          lowerError.contains('context length') ||
          lowerError.contains('too long') ||
          lowerError.contains('maximum context') ||
          lowerError.contains('exceed')) {
        errorMessage = '⚠️ **Context limit exceeded**\n\n'
            'The conversation or sources are too large for this model. Try:\n'
            '- Switching to a model with larger context (Gemini 1.5 Pro, GPT-4 Turbo, Claude 3)\n'
            '- Removing some sources from your notebook\n'
            '- Starting a new conversation';
      } else if (lowerError.contains('not found') ||
          lowerError.contains('invalid model')) {
        errorMessage = '⚠️ **Model not available**\n\n'
            'The selected model is not available. Please go to Settings and select a different AI model.';
      }

      final errorToken = StreamToken.text(text: errorMessage);
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
