import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/global_credentials_service.dart';

/// Secure OpenRouter configuration that uses encrypted credentials from database
class OpenRouterConfigSecure {
  final Ref ref;

  OpenRouterConfigSecure(this.ref);

  /// Get API key - first try database (encrypted), then fall back to .env
  Future<String> getApiKey() async {
    try {
      final credService = ref.read(globalCredentialsServiceProvider);
      final dbKey = await credService.getApiKey('openrouter');
      if (dbKey != null && dbKey.isNotEmpty) {
        return dbKey;
      }
    } catch (e) {
      // Fall back to .env if database fails
    }

    return dotenv.env['OPENROUTER_API_KEY'] ?? '';
  }

  /// Store API key in database (encrypted)
  Future<void> storeApiKey(String apiKey) async {
    final credService = ref.read(globalCredentialsServiceProvider);
    await credService.storeApiKey(
      service: 'openrouter',
      apiKey: apiKey,
      description: 'OpenRouter API Key',
    );
  }

  /// Migrate API key from .env to database
  Future<void> migrateApiKeyToDatabase() async {
    final envKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
    if (envKey.isNotEmpty) {
      await storeApiKey(envKey);
    }
  }
}

final openRouterConfigSecureProvider = Provider<OpenRouterConfigSecure>((ref) {
  return OpenRouterConfigSecure(ref);
});
