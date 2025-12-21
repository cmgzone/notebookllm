import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/global_credentials_service.dart';

/// Secure Gemini configuration that can use encrypted credentials from database
class GeminiConfigSecure {
  final Ref ref;

  GeminiConfigSecure(this.ref);

  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  // Use gemini-1.5-flash as default - guaranteed free tier
  static const String defaultModel = 'gemini-1.5-flash';
  static const String visionModel = 'gemini-1.5-flash';
  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 8192;
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

  /// Get API key - first try database (encrypted), then fall back to .env
  Future<String> getApiKey() async {
    try {
      final credService = ref.read(globalCredentialsServiceProvider);
      final dbKey = await credService.getApiKey('gemini');
      if (dbKey != null && dbKey.isNotEmpty) {
        return dbKey;
      }
    } catch (e) {
      // Fall back to .env if database fails
    }

    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  /// Store API key in database (encrypted)
  Future<void> storeApiKey(String apiKey) async {
    final credService = ref.read(globalCredentialsServiceProvider);
    await credService.storeApiKey(
      service: 'gemini',
      apiKey: apiKey,
      description: 'Gemini AI API Key',
    );
  }

  /// Migrate API key from .env to database
  Future<void> migrateApiKeyToDatabase() async {
    final envKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (envKey.isNotEmpty) {
      await storeApiKey(envKey);
    }
  }
}

final geminiConfigSecureProvider = Provider<GeminiConfigSecure>((ref) {
  return GeminiConfigSecure(ref);
});
