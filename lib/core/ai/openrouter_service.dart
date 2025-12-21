import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenRouterService {
  final String? _apiKey;

  OpenRouterService({String? apiKey}) : _apiKey = apiKey;

  String get apiKey => _apiKey ?? dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static const String baseUrl = 'https://openrouter.ai/api/v1';

  // Free models available on OpenRouter (December 2025)
  // Note: Model IDs must match exactly what OpenRouter provides
  static const Map<String, String> freeModels = {
    // Amazon Nova (Free)
    'amazon/nova-2-lite-v1:free': 'Amazon Nova 2 Lite (Free)',
    // Google Models
    'google/gemini-2.0-flash-exp:free': 'Gemini 2.0 Flash Exp (Free)',
    'google/gemini-2.0-flash-thinking-exp:free':
        'Gemini 2.0 Flash Thinking (Free)',
    'google/gemini-exp-1206:free': 'Gemini 2.0 Flash (Free)',
    'google/gemma-2-9b-it:free': 'Gemma 2 9B (Free)',
    // Meta Llama
    'meta-llama/llama-3.2-3b-instruct:free': 'Llama 3.2 3B (Free)',
    'meta-llama/llama-3.2-1b-instruct:free': 'Llama 3.2 1B (Free)',
    'meta-llama/llama-3.1-8b-instruct:free': 'Llama 3.1 8B (Free)',
    // Microsoft
    'microsoft/phi-3-mini-128k-instruct:free': 'Phi-3 Mini 128K (Free)',
    'microsoft/phi-3-medium-128k-instruct:free': 'Phi-3 Medium 128K (Free)',
    // Others
    'mistralai/mistral-7b-instruct:free': 'Mistral 7B (Free)',
    'qwen/qwen-2-7b-instruct:free': 'Qwen 2 7B (Free)',
    'huggingfaceh4/zephyr-7b-beta:free': 'Zephyr 7B (Free)',
    'openchat/openchat-7b:free': 'OpenChat 7B (Free)',
    'nousresearch/nous-capybara-7b:free': 'Nous Capybara 7B (Free)',
  };

  // Paid/Premium models
  static const Map<String, String> paidModels = {
    // OpenAI
    'openai/gpt-4o': 'GPT-4o (Paid)',
    'openai/gpt-4o-mini': 'GPT-4o Mini (Paid)',
    // Anthropic
    'anthropic/claude-3.5-sonnet': 'Claude 3.5 Sonnet (Paid)',
    'anthropic/claude-3-haiku': 'Claude 3 Haiku (Paid)',
    // Google
    'google/gemini-3-pro-image-preview': 'Gemini 3 Pro Image Preview (Paid)',
    'google/gemini-pro-1.5': 'Gemini 1.5 Pro (Paid)',
    'google/gemini-flash-1.5': 'Gemini 1.5 Flash (Paid)',
    // Meta
    'meta-llama/llama-3.1-405b-instruct': 'Llama 3.1 405B (Paid)',
    // Perplexity
    'perplexity/llama-3.1-sonar-large-128k-online':
        'Perplexity Llama 3.1 Sonar Online (Paid)',
    // DeepSeek
    'deepseek/deepseek-chat': 'DeepSeek v3 (Paid)',
  };

  static Map<String, String> get allModels => {...freeModels, ...paidModels};

  Future<String> generateContent(
    String prompt, {
    String model = 'amazon/nova-2-lite-v1:free',
    double temperature = 0.7,
    int maxTokens =
        8192, // Increased for long outputs (will be capped by model if needed)
    String? apiKey,
  }) async {
    try {
      final key = apiKey ?? this.apiKey;
      if (key.isEmpty || key == 'your_openrouter_key_here') {
        throw Exception(
            'Missing or invalid OPENROUTER_API_KEY. Please set a valid key in .env or deploy it to the database.');
      }

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
            {'role': 'user', 'content': prompt}
          ],
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[OpenRouterService] Response data: ${response.body}');

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
    String model = 'amazon/nova-2-lite-v1:free',
    double temperature = 0.7,
    int maxTokens = 8192, // Increased for long outputs
    String? apiKey,
  }) async {
    final key = apiKey ?? this.apiKey;
    if (key.isEmpty || key == 'your_openrouter_key_here') {
      throw Exception('Missing or invalid OPENROUTER_API_KEY');
    }

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

    final streamedResponse = await request.send();

    return streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data: ') && line != 'data: [DONE]')
        .map((line) {
      final jsonStr = line.substring(6);
      final data = jsonDecode(jsonStr);
      return data['choices'][0]['delta']['content'] as String? ?? '';
    }).where((content) => content.isNotEmpty);
  }

  Future<String> generateWithImage(
    String prompt,
    Uint8List imageBytes, {
    String model = 'google/gemini-2.0-flash-exp:free',
    double temperature = 0.7,
    int maxTokens = 8192,
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
