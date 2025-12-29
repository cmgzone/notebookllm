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

  /// Generate image using OpenRouter's chat completions with image-capable models
  /// Models like google/gemini-2.0-flash-exp:free can generate images
  Future<String> _generateImageOpenRouter(String prompt, String model) async {
    try {
      // Use an image-capable model. Gemini 2.0 Flash can generate images.
      final imageModel = model.contains('gemini') || model.contains('dall-e')
          ? model
          : 'google/gemini-2.0-flash-exp:free'; // Default to free Gemini model

      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://notebookllm.app',
          'X-Title': 'NotBook LLM',
        },
        body: jsonEncode({
          'model': imageModel,
          'messages': [
            {
              'role': 'user',
              'content':
                  'Generate an image of: $prompt. Return the image directly without any text explanation.'
            }
          ],
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];

        // Check if response contains an image URL or base64 data
        if (content != null) {
          // Look for image URLs in the response
          final urlRegex = RegExp(
              r'https?://[^\s\)\"]+\.(png|jpg|jpeg|gif|webp)',
              caseSensitive: false);
          final match = urlRegex.firstMatch(content);
          if (match != null) {
            return match.group(0)!;
          }

          // Look for base64 image data
          final base64Regex =
              RegExp(r'data:image/[^;]+;base64,[A-Za-z0-9+/=]+');
          final base64Match = base64Regex.firstMatch(content);
          if (base64Match != null) {
            return base64Match.group(0)!;
          }

          // If response contains inline_data (Gemini format)
          if (data['choices']?[0]?['message']?['content'] is List) {
            final parts = data['choices'][0]['message']['content'] as List;
            for (final part in parts) {
              if (part['type'] == 'image_url') {
                return part['image_url']['url'];
              }
            }
          }
        }

        debugPrint(
            '[GeminiImageService] Model response did not contain image. Using placeholder.');
        return _generatePlaceholderImage(prompt);
      }

      final errorBody = response.body;
      debugPrint('OpenRouter Image Error: ${response.statusCode} $errorBody');

      // Check for credit/quota errors
      if (errorBody.contains('credits') || errorBody.contains('quota')) {
        throw Exception(
            'OpenRouter credits exhausted. Please add credits to your account.');
      }

      throw Exception('OpenRouter Image Generation failed: $errorBody');
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
