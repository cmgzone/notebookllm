import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final imageGenerationServiceProvider = Provider<ImageGenerationService>((ref) => ImageGenerationService());

class ImageGenerationService {
  // Placeholder base URL - User needs to confirm the exact endpoint for "Nanobanana"
  // If it's a wrapper around Gemini/Imagen, it might be different.
  // For now, I'll use a generic structure that can be easily updated.
  static const String _baseUrl = 'https://api.nanobanana.ai/v1'; 

  Future<String> generateImage(String prompt) async {
    final apiKey = dotenv.env['NANOBANANA_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing NANOBANANA_API_KEY in .env');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'prompt': prompt,
          'model': 'nanobanana-v1', // Hypothetical model name
          'size': '1024x1024',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Assuming standard response format { "url": "..." } or { "data": [{ "url": "..." }] }
        // Adjust based on actual API response
        if (data['url'] != null) {
          return data['url'];
        } else if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          return data['data'][0]['url'];
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception('Image generation failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate image: $e');
    }
  }
}
