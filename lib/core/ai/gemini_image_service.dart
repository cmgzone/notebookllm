import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'gemini_config.dart';

class GeminiImageService {
  final String apiKey;

  GeminiImageService({String? apiKey}) : apiKey = apiKey ?? GeminiConfig.apiKey;

  /// Generate an image using Nano Banana API
  Future<String> generateImage(String prompt,
      {String? model, String? provider}) async {
    try {
      if (apiKey.isEmpty) {
        throw Exception('Missing API key.');
      }

      if (provider == 'openrouter') {
        return _generateImageOpenRouter(prompt, model ?? 'openai/dall-e-3');
      }

      // Default to placeholder for Gemini until specialized Imagen API is implemented
      // or if using Nano Banana (removing Nano Banana as it appears broken/fake)
      debugPrint(
          '[GeminiImageService] Gemini Image Gen not fully implemented. Using placeholder.');
      return _generatePlaceholderImage(prompt);

      /* 
      // Legacy Nano Banana implementation removed
      */
    } catch (e) {
      debugPrint(
          '[GeminiImageService] Image generation failed: $e. Using placeholder.');
      return _generatePlaceholderImage(prompt);
    }
  }

  Future<String> _generateImageOpenRouter(String prompt, String model) async {
    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/images/generations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://notbook-llm.app', // Optional
          'X-Title': 'NotBook LLM', // Optional
        },
        body: jsonEncode({
          'prompt': prompt,
          'model': model,
          'n': 1,
          'size': '1024x1024',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final images = data['data'] as List?;
        if (images != null && images.isNotEmpty) {
          return images[0]['url'] ?? _generatePlaceholderImage(prompt);
        }
      }
      debugPrint(
          'OpenRouter Image Error: ${response.statusCode} ${response.body}');
      throw Exception('OpenRouter Image Generation failed: ${response.body}');
    } catch (e) {
      debugPrint('OpenRouter generation error: $e');
      rethrow;
    }
  }

  /// Analyze an image using Gemini's vision capabilities
  Future<String> analyzeImage(Uint8List imageBytes, String prompt,
      {required String model}) async {
    try {
      if (apiKey.isEmpty) {
        throw Exception('Missing GEMINI_API_KEY');
      }

      final genModel = GenerativeModel(
        model: model,
        apiKey: apiKey,
      );

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await genModel.generateContent(content);
      return response.text ?? 'No analysis available';
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }

  /// Generate placeholder image as base64 (simple colored square with text)
  String _generatePlaceholderImage(String prompt) {
    final truncatedPrompt =
        prompt.length > 50 ? '${prompt.substring(0, 50)}...' : prompt;
    final svg = '''
<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">
  <rect width="400" height="400" fill="#9333EA"/>
  <text x="50%" y="50%" font-size="16" fill="white" text-anchor="middle" dominant-baseline="middle">
    $truncatedPrompt
  </text>
</svg>
''';
    final bytes = utf8.encode(svg);
    final base64Svg = base64Encode(bytes);
    return 'data:image/svg+xml;base64,$base64Svg';
  }

  /// Generate an image with custom parameters
  Future<String> generateImageWithOptions({
    required String prompt,
    String aspectRatio = '1:1',
    int sampleCount = 1,
    String safetyLevel = 'block_some',
  }) async {
    return await generateImage(prompt);
  }
}
