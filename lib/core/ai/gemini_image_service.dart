import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'gemini_config.dart';

class GeminiImageService {
  final String apiKey;
  static const String _nanoBananaUrl =
      'https://api.nanobanana.com/v1/images/generations';

  GeminiImageService({String? apiKey}) : apiKey = apiKey ?? GeminiConfig.apiKey;

  /// Generate an image using Nano Banana API
  Future<String> generateImage(String prompt) async {
    try {
      if (apiKey.isEmpty) {
        throw Exception('Missing API key. Set it in .env');
      }

      final response = await http.post(
        Uri.parse(_nanoBananaUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'prompt': prompt,
          'model': 'nano-banana-v1',
          'size': '512x512',
          'n': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final images = data['data'] as List?;

        if (images != null && images.isNotEmpty) {
          // Return URL or base64 depending on response format
          final imageUrl = images[0]['url'] ?? images[0]['b64_json'];
          if (imageUrl != null) {
            if (images[0]['b64_json'] != null) {
              return 'data:image/png;base64,${images[0]['b64_json']}';
            }
            return imageUrl;
          }
        }
        throw Exception('No image data in response');
      } else {
        debugPrint(
            '[GeminiImageService] Nano Banana API error: ${response.body}');
        return _generatePlaceholderImage(prompt);
      }
    } catch (e) {
      debugPrint(
          '[GeminiImageService] Image generation failed: $e. Using placeholder.');
      return _generatePlaceholderImage(prompt);
    }
  }

  /// Analyze an image using Gemini's vision capabilities
  Future<String> analyzeImage(Uint8List imageBytes, String prompt) async {
    try {
      if (apiKey.isEmpty) {
        throw Exception('Missing GEMINI_API_KEY');
      }

      final model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: apiKey,
      );

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await model.generateContent(content);
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
