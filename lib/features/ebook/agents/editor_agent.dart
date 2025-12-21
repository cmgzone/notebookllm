import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/ai/gemini_service.dart';
import '../../../core/ai/openrouter_service.dart';
import '../../../core/security/global_credentials_service.dart';

class EditorAgent {
  final Ref ref;

  EditorAgent(this.ref);

  Future<String> _getSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ai_provider') ?? 'gemini';
  }

  Future<String> _generateContent(String prompt) async {
    final provider = await _getSelectedProvider();
    final creds = ref.read(globalCredentialsServiceProvider);

    if (provider == 'openrouter') {
      final prefs = await SharedPreferences.getInstance();
      final model = prefs.getString('ai_model') ?? 'amazon/nova-2-lite-v1:free';
      final apiKey = await creds.getApiKey('openrouter');
      return await OpenRouterService()
          .generateContent(prompt, model: model, apiKey: apiKey);
    } else {
      final apiKey = await creds.getApiKey('gemini');
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Gemini API key not found');
      }
      return await GeminiService(apiKey: apiKey).generateContent(prompt);
    }
  }

  Future<String> refineText(String text, String instruction) async {
    try {
      final prompt = '''
You are an expert Editor Agent.
Instruction: $instruction
Original Text:
"$text"

Rewrite the text following the instruction. Maintain the core meaning but improve the style/tone/clarity as requested.
Return ONLY the rewritten text.
''';

      return await _generateContent(prompt);
    } catch (e) {
      return text; // Fallback to original
    }
  }
}

final editorAgentProvider = Provider<EditorAgent>((ref) => EditorAgent(ref));
