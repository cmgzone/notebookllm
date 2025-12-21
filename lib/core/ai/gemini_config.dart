import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiConfig {
  static String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  // Use gemini-1.5-flash as default - guaranteed free tier
  static const String defaultModel = 'gemini-1.5-flash';
  static const String visionModel = 'gemini-1.5-flash';

  // All available Gemini models (December 2025 - Free Tier Compatible)
  static const Map<String, String> availableModels = {
    // Gemini 2.0 Models (Latest)
    'gemini-2.0-flash-exp': 'Gemini 2.0 Flash (Experimental)',
    'gemini-2.0-flash-lite': 'Gemini 2.0 Flash Lite (Fastest)',

    // Gemini 1.5 Models (Stable - Free Tier)
    'gemini-1.5-pro': 'Gemini 1.5 Pro',
    'gemini-1.5-flash': 'Gemini 1.5 Flash',
    'gemini-1.5-flash-8b': 'Gemini 1.5 Flash 8B',
  };
  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens =
      8192; // Maximum for most Gemini models - no limit for long outputs
  static const double defaultTopP = 0.8;
  static const int defaultTopK = 40;
  static const int requestsPerMinute = 60;
  static const int requestsPerDay = 1000;
  static const Map<String, String> safetySettings = {
    'HARM_CATEGORY_HARASSMENT': 'BLOCK_MEDIUM_AND_ABOVE',
    'HARM_CATEGORY_HATE_SPEECH': 'BLOCK_MEDIUM_AND_ABOVE',
    'HARM_CATEGORY_SEXUALLY_EXPLICIT': 'BLOCK_MEDIUM_AND_ABOVE',
    'HARM_CATEGORY_DANGEROUS_CONTENT': 'BLOCK_MEDIUM_AND_ABOVE',
  };
}
