import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ai/ai_settings_service.dart';
import '../../core/api/api_service.dart';

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
    final settings = await AISettingsService.getSettings();
    final model = settings.getEffectiveModel();

    // Use Backend Proxy (Admin's API keys)
    final apiService = ref.read(apiServiceProvider);
    final messages = [
      {'role': 'user', 'content': prompt}
    ];

    return await apiService.chatWithAI(
      messages: messages,
      provider: settings.provider,
      model: model,
    );
  }

  Future<List<FactCheckResult>> verifyContent(String content) async {
    if (content.trim().isEmpty) return [];

    // Truncate if too long to avoid token limits (rudimentary check)
    final truncatedContent = content.length > 20000
        ? '${content.substring(0, 20000)}...(truncated)'
        : content;

    final prompt = '''
You are a professional fact-checker and research analyst. Analyze the following text and identify specific factual claims that can be verified. 
For each claim, verify its accuracy based on your general knowledge.

Text to analyze:
"""
$truncatedContent
"""

Return a JSON array where each object has:
- "claim": The specific claim extracted from the text (quote it exactly or paraphrase clearly).
- "verdict": "True", "False", "Misleading", or "Unverified".
- "explanation": A DETAILED explanation (2-4 sentences) explaining:
  1. WHY this verdict was given
  2. What evidence or reasoning supports this conclusion
  3. Any important context or nuance
  4. If False/Misleading, what the correct information is
- "confidence": A score from 0.0 to 1.0 indicating your certainty.

IMPORTANT: The explanation must be thorough and educational. Don't just state the verdict - explain the reasoning behind it so users understand WHY a claim is true, false, or misleading.

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
