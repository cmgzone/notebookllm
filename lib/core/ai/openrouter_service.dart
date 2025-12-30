import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenRouterService {
  final String? _apiKey;

  OpenRouterService({String? apiKey}) : _apiKey = apiKey;

  String get apiKey => _apiKey ?? dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static const String baseUrl = 'https://openrouter.ai/api/v1';

  // Models are now managed via the database/Admin panel.
  static Map<String, String> get allModels => {};

  Future<String> generateContent(
    String prompt, {
    required String model,
    double temperature = 0.7,
    int maxTokens = 4000, // Reduced to avoid credit issues
    String? apiKey,
  }) async {
    try {
      final key = apiKey ?? this.apiKey;
      if (key.isEmpty || key == 'your_openrouter_key_here') {
        throw Exception(
            'Missing or invalid OPENROUTER_API_KEY. Please set a valid key in .env or deploy it to the database.');
      }

      debugPrint(
          '[OpenRouterService] generateContent starting for model: $model');

      final response = await http
          .post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
          'HTTP-Referer': 'https://notebook-llm.app',
          'X-Title': 'Notebook LLM',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      )
          .timeout(const Duration(seconds: 60), onTimeout: () {
        debugPrint('[OpenRouterService] HTTP request timed out after 60s');
        throw Exception('OpenRouter HTTP request timed out');
      });

      debugPrint('[OpenRouterService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[OpenRouterService] Response received, parsing...');

        final choices = data['choices'] as List<dynamic>?;

        if (choices == null || choices.isEmpty) {
          throw Exception(
              'No choices in response. Full response: ${response.body}');
        }

        final message = choices[0]['message'];

        if (message == null) {
          throw Exception(
              'No message in choice. Response structure: ${choices[0]}');
        }

        final content = message['content'] as String?;

        if (content == null || content.isEmpty) {
          throw Exception(
              'No content in message. Response structure: $message');
        }

        return content;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
            'OpenRouter API error: ${error['error']?['message'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate content: $e');
    }
  }

  Future<Stream<String>> generateStream(
    String prompt, {
    required String model,
    double temperature = 0.7,
    int maxTokens = 4000, // Reduced to avoid credit issues
    String? apiKey,
  }) async {
    final key = apiKey ?? this.apiKey;
    if (key.isEmpty || key == 'your_openrouter_key_here') {
      throw Exception('Missing or invalid OPENROUTER_API_KEY');
    }

    debugPrint('[OpenRouterService] Starting stream request to model: $model');
    final client = http.Client();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/chat/completions'),
      );

      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
        'HTTP-Referer': 'https://notebook-llm.app',
        'X-Title': 'Notebook LLM',
      });

      request.body = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true,
      });

      debugPrint('[OpenRouterService] Sending request...');
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[OpenRouterService] Connection timeout after 30s');
          client.close();
          throw Exception(
              'OpenRouter connection timeout - server took too long to respond');
        },
      );

      debugPrint(
          '[OpenRouterService] Response status: ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString().timeout(
              const Duration(seconds: 10),
              onTimeout: () => 'Timeout reading error response',
            );
        client.close();
        throw Exception(
            'OpenRouter API error (${streamedResponse.statusCode}): $body');
      }

      return streamedResponse.stream
          .timeout(
            const Duration(seconds: 45),
            onTimeout: (sink) {
              debugPrint(
                  '[OpenRouterService] Stream timeout - no data for 45s');
              client.close();
              sink.close();
            },
          )
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((line) {
            // Check for stream end
            if (line == 'data: [DONE]') {
              debugPrint('[OpenRouterService] Stream completed normally');
              return false;
            }
            return line.startsWith('data: ');
          })
          .map((line) {
            try {
              final jsonStr = line.substring(6);
              if (jsonStr.trim().isEmpty) return '';
              final data = jsonDecode(jsonStr);
              final content =
                  data['choices']?[0]?['delta']?['content'] as String? ?? '';
              return content;
            } catch (e) {
              debugPrint(
                  '[OpenRouterService] Stream parse error: $e, line: $line');
              return '';
            }
          })
          .where((content) => content.isNotEmpty)
          .handleError((error) {
            debugPrint('[OpenRouterService] Stream error: $error');
            client.close();
          }, test: (e) => true);
    } catch (e) {
      debugPrint('[OpenRouterService] generateStream error: $e');
      client.close();
      rethrow;
    }
  }

  Future<String> generateWithImage(
    String prompt,
    Uint8List imageBytes, {
    required String model,
    double temperature = 0.7,
    int maxTokens = 4000, // Reduced to avoid credit issues
    String? apiKey,
  }) async {
    final key = apiKey ?? this.apiKey;
    if (key.isEmpty || key == 'your_openrouter_key_here') {
      throw Exception('Missing or invalid OPENROUTER_API_KEY');
    }

    final base64Image = base64Encode(imageBytes);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
          'HTTP-Referer': 'https://notebook-llm.app',
          'X-Title': 'Notebook LLM',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                }
              ]
            }
          ],
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String?;
        if (content != null) return content;
        throw Exception('Empty response content');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
            'OpenRouter API error: ${error['error']?['message'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate with image: $e');
    }
  }
}
