import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/ai/openrouter_service.dart';
import '../../core/ai/ai_settings_service.dart';
import '../../core/security/global_credentials_service.dart';

class FactCheckResult {
  final String claim;
  final String verdict; // 'True', 'False', 'Misleading', 'Unverified'
  final String explanation;
  final double confidence;

  FactCheckResult({
    required this.claim,
    required this.verdict,
    required this.explanation,
    required this.confidence,
  });

  factory FactCheckResult.fromJson(Map<String, dynamic> json) {
    return FactCheckResult(
      claim: json['claim'] as String? ?? 'Unknown claim',
      verdict: json['verdict'] as String? ?? 'Unverified',
      explanation: json['explanation'] as String? ?? 'No explanation provided',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FactCheckService {
  final Ref ref;

  FactCheckService(this.ref);

  Future<String> _generateContent(String prompt) async {
    final creds = ref.read(globalCredentialsServiceProvider);

    final settings = await AISettingsService.getSettings();
    final provider = settings.provider;
    final model = settings.getEffectiveModel();

    if (provider == 'openrouter') {
      final apiKey = await creds.getApiKey('openrouter');
      return await OpenRouterService()
          .generateContent(prompt, model: model, apiKey: apiKey);
    } else {
      final apiKey = await creds.getApiKey('gemini');
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Gemini API key not found');
      }
      return await GeminiService(apiKey: apiKey)
          .generateContent(prompt, model: model);
    }
  }

  Future<List<FactCheckResult>> verifyContent(String content) async {
    if (content.trim().isEmpty) return [];

    // Truncate if too long to avoid token limits (rudimentary check)
    final truncatedContent = content.length > 20000
        ? '${content.substring(0, 20000)}...(truncated)'
        : content;

    final prompt = '''
You are a professional fact-checker. Analyze the following text and identify specific factual claims that can be verified. 
For each claim, verify its accuracy based on your general knowledge.

Text to analyze:
"""
$truncatedContent
"""

Return a JSON array where each object has:
- "claim": The specific claim extracted from the text.
- "verdict": "True", "False", "Misleading", or "Unverified".
- "explanation": A brief explanation of why.
- "confidence": A score from 0.0 to 1.0 indicating your certainty.

Ensure the output is valid JSON. Do not include markdown code blocks (```json).
''';

    try {
      final response = await _generateContent(prompt);

      // Clean response
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```json')) jsonStr = jsonStr.substring(7);
      if (jsonStr.startsWith('```')) jsonStr = jsonStr.substring(3);
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }

      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((e) => FactCheckResult.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Fact check verification failed: $e');
    }
  }
}

final factCheckServiceProvider =
    Provider<FactCheckService>((ref) => FactCheckService(ref));
