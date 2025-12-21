import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/ai/gemini_service.dart';
import '../../../core/ai/openrouter_service.dart';
import '../../../core/security/global_credentials_service.dart';
import '../message.dart';
import '../../sources/source_provider.dart';

class SuggestionResult {
  final List<String> questions;
  final List<SourceSuggestion> sources;

  SuggestionResult({required this.questions, required this.sources});

  factory SuggestionResult.empty() =>
      SuggestionResult(questions: [], sources: []);
}

class SuggestionService {
  final Ref ref;

  SuggestionService(this.ref);

  Future<SuggestionResult> generateSuggestions({
    required List<Message> history,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final provider = prefs.getString('ai_provider') ?? 'gemini';
      final model = prefs.getString('ai_model') ?? 'gemini-1.5-flash';

      // Get brief source context
      final sources = ref.read(sourceProvider);
      final sourceContext = sources
          .take(5)
          .map((s) =>
              '- ${s.title}: ${s.content.substring(0, 100).replaceAll('\n', ' ')}...')
          .join('\n');

      // Get recent history
      final recentHistory =
          history.length > 5 ? history.sublist(history.length - 5) : history;
      final historyText = recentHistory
          .map((m) => '${m.isUser ? "User" : "AI"}: ${m.text}')
          .join('\n');

      final prompt = '''
Analyze the following conversation and available source context.
Generate 3 short, relevant follow-up questions that the user might want to ask next.
Also generate 3 relevant search queries or video topics that would help the user research this further.

Context:
$sourceContext

Conversation:
$historyText

Return ONLY a valid JSON object with the following structure, no markdown formatting:
{
  "questions": ["Question 1", "Question 2", "Question 3"],
  "sources": [
    {"title": "Specific Topic 1", "query": "search query 1", "type": "web"},
    {"title": "Video Topic 1", "query": "search query 2", "type": "youtube"}
  ]
}
''';

      String responseText;

      if (provider == 'openrouter') {
        final openRouterKey = await ref
            .read(globalCredentialsServiceProvider)
            .getApiKey('openrouter');
        if (openRouterKey == null) return SuggestionResult.empty();

        final service = OpenRouterService();
        responseText = await service.generateContent(prompt,
            model: model, apiKey: openRouterKey);
      } else {
        final geminiKey = await ref
            .read(globalCredentialsServiceProvider)
            .getApiKey('gemini');
        if (geminiKey == null) return SuggestionResult.empty();

        final service = GeminiService(apiKey: geminiKey);
        responseText = await service.generateContent(prompt, model: model);
      }

      final json = jsonDecode(responseText) as Map<String, dynamic>;

      final questions = (json['questions'] as List)
          .cast<String>()
          .take(4)
          .toList(); // Up to 4 questions

      final rawSources = (json['sources'] as List);
      final derivedSources = rawSources.map((s) {
        final query = s['query'] as String;
        final type = s['type'] as String;
        final title = s['title'] as String;

        String url;
        if (type == 'youtube') {
          url =
              'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}';
        } else {
          url = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
        }

        return SourceSuggestion(
          title: title,
          url: url,
          type: type,
        );
      }).toList();

      return SuggestionResult(questions: questions, sources: derivedSources);
    } catch (e) {
      debugPrint('Error generating suggestions: $e');
      return SuggestionResult.empty();
    }
  }
}

final suggestionServiceProvider =
    Provider<SuggestionService>((ref) => SuggestionService(ref));
