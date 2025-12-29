import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'gemini_config.dart';

class GeminiService {
  final String apiKey;

  GeminiService({String? apiKey}) : apiKey = apiKey ?? GeminiConfig.apiKey;

  Future<String> generateContent(
    String prompt, {
    required String model,
    double temperature = GeminiConfig.defaultTemperature,
    int maxTokens = GeminiConfig.defaultMaxTokens,
    String? apiKey,
  }) async {
    try {
      final key = apiKey ?? this.apiKey;
      if (key.isEmpty) {
        throw Exception(
            'Missing GEMINI_API_KEY. Set it in .env or deploy to database.');
      }

      final genModel = GenerativeModel(
        model: model,
        apiKey: key,
        generationConfig: GenerationConfig(
          temperature: temperature,
          maxOutputTokens: maxTokens,
          topP: GeminiConfig.defaultTopP,
          topK: GeminiConfig.defaultTopK,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          SafetySetting(
              HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
          SafetySetting(
              HarmCategory.dangerousContent, HarmBlockThreshold.medium),
        ],
      );

      final content = [Content.text(prompt)];
      final response = await genModel.generateContent(content);

      debugPrint('[GeminiService] Response: ${response.text}');

      if (response.text == null || response.text!.isEmpty) {
        final reason = response.candidates.firstOrNull?.finishReason;
        throw Exception('Empty response from Gemini. Finish reason: $reason');
      }

      return response.text!;
    } on GenerativeAIException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('quota') || msg.contains('rate')) {
        throw Exception(
            'API quota exceeded. Try: 1) Wait a minute, 2) Use a different model, 3) Check billing at console.cloud.google.com');
      }
      if (msg.contains('not found') || msg.contains('invalid')) {
        throw Exception(
            'Model "$model" not available. Try a different model instead.');
      }
      throw Exception('Gemini API error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to generate content: $e');
    }
  }

  Future<String> generateContentWithContext(
    String prompt,
    List<String> context, {
    required String model,
    double temperature = GeminiConfig.defaultTemperature,
    int maxTokens = GeminiConfig.defaultMaxTokens,
    String? apiKey,
  }) async {
    final contextText = context.join('\n\n');
    final enhancedPrompt = '''
Context:
$contextText

Based on the above context, please respond to the following:
$prompt

Please provide a comprehensive and accurate response based on the given context.
''';

    return generateContent(enhancedPrompt,
        model: model,
        temperature: temperature,
        maxTokens: maxTokens,
        apiKey: apiKey);
  }

  /// Stream content generation - returns chunks as they arrive
  Stream<String> streamContent(
    String prompt, {
    required String model,
    double temperature = GeminiConfig.defaultTemperature,
    int maxTokens = GeminiConfig.defaultMaxTokens,
    String? apiKey,
  }) async* {
    final key = apiKey ?? this.apiKey;
    if (key.isEmpty) {
      throw Exception('Missing GEMINI_API_KEY');
    }

    final genModel = GenerativeModel(
      model: model,
      apiKey: key,
      generationConfig: GenerationConfig(
        temperature: temperature,
        maxOutputTokens: maxTokens,
        topP: GeminiConfig.defaultTopP,
        topK: GeminiConfig.defaultTopK,
      ),
    );

    final content = [Content.text(prompt)];
    final response = genModel.generateContentStream(content);

    await for (final chunk in response) {
      if (chunk.text != null) {
        yield chunk.text!;
      }
    }
  }

  /// Legacy method for compatibility - now uses streaming internally
  Future<String> generateStream(
    String prompt, {
    required String model,
    double temperature = GeminiConfig.defaultTemperature,
    int maxTokens = GeminiConfig.defaultMaxTokens,
    String? apiKey,
  }) async {
    return await generateContent(
      prompt,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      apiKey: apiKey,
    );
  }

  /// Generate content with an image (vision capability)
  Future<String> generateContentWithImage(
    String prompt,
    Uint8List imageBytes, {
    required String model,
    double temperature = GeminiConfig.defaultTemperature,
    int maxTokens = GeminiConfig.defaultMaxTokens,
    String? apiKey,
  }) async {
    try {
      final key = apiKey ?? this.apiKey;
      if (key.isEmpty) {
        throw Exception('Missing GEMINI_API_KEY');
      }

      final genModel = GenerativeModel(
        model: model,
        apiKey: key,
        generationConfig: GenerationConfig(
          temperature: temperature,
          maxOutputTokens: maxTokens,
          topP: GeminiConfig.defaultTopP,
          topK: GeminiConfig.defaultTopK,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          SafetySetting(
              HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
          SafetySetting(
              HarmCategory.dangerousContent, HarmBlockThreshold.medium),
        ],
      );

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await genModel.generateContent(content);

      debugPrint('[GeminiService] Image response: ${response.text}');

      if (response.text == null || response.text!.isEmpty) {
        final reason = response.candidates.firstOrNull?.finishReason;
        throw Exception(
            'Empty response from Gemini vision. Finish reason: $reason');
      }

      return response.text!;
    } on GenerativeAIException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('quota') || msg.contains('rate')) {
        throw Exception('API quota exceeded. Please wait and try again.');
      }
      throw Exception('Gemini vision error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }
}
