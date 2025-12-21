import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Deprecated: Use ElevenLabsConfigSecure instead for secure, encrypted storage
  static String get elevenLabsApiKey {
    return dotenv.env['ELEVENLABS_API_KEY'] ?? '';
  }

  static String get geminiApiKey {
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  static String get openRouterApiKey {
    return dotenv.env['OPENROUTER_API_KEY'] ?? '';
  }

  static String get serperApiKey {
    return dotenv.env['SERPER_API_KEY'] ?? '';
  }
}
