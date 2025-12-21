import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/ai/gemini_service.dart';
import '../../../core/ai/openrouter_service.dart';
import '../../../core/security/global_credentials_service.dart';

class ResearchAgent {
  final Ref ref;

  ResearchAgent(this.ref);

  Future<String> _generateContent(String prompt, {String? model}) async {
    final creds = ref.read(globalCredentialsServiceProvider);

    // Determine provider and model
    String provider;
    String targetModel;

    if (model != null && model.isNotEmpty) {
      // Use the model selected for this specific project
      // Check if it looks like an OpenRouter model ID (usually vendor/model)
      // or definitely isn't a known Google model
      final isOpenRouterParams = model.contains('/') ||
          model.startsWith('openai/') ||
          model.startsWith('anthropic/') ||
          model.startsWith('deepseek/');

      if (isOpenRouterParams) {
        provider = 'openrouter';
        targetModel = model;
      } else {
        provider = 'gemini';
        targetModel = model;
      }
    } else {
      // Fallback to global settings
      final prefs = await SharedPreferences.getInstance();
      provider = prefs.getString('ai_provider') ?? 'gemini';
      targetModel = prefs.getString('ai_model') ?? 'gemini-1.5-flash';
    }

    if (provider == 'openrouter') {
      final apiKey = await creds.getApiKey('openrouter');
      return await OpenRouterService()
          .generateContent(prompt, model: targetModel, apiKey: apiKey);
    } else {
      final apiKey = await creds.getApiKey('gemini');
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Gemini API key not found');
      }
      return await GeminiService(apiKey: apiKey)
          .generateContent(prompt, model: targetModel);
    }
  }

  Future<String> researchTopic(String topic,
      {List<String> context = const [],
      String? notebookId,
      String? model}) async {
    try {
      String sourceContext = context.join('\n\n');

      // Note: Source fetching is handled by EbookOrchestrator before calling this method
      // The orchestrator passes sources via the context parameter

      final prompt = '''
You are a Research Agent tasked with gathering key information for an ebook about: "$topic".

Existing Context (from User's Notebook):
$sourceContext

Please provide a comprehensive summary of key facts, important dates, main concepts, and interesting details that should be included in this ebook. 
Focus on accuracy and depth, prioritizing the provided context.
''';

      return await _generateContent(prompt, model: model);
    } catch (e) {
      return "Research failed: $e";
    }
  }
}

final researchAgentProvider =
    Provider<ResearchAgent>((ref) => ResearchAgent(ref));
