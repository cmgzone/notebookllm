import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/global_credentials_service.dart';

/// Secure ElevenLabs configuration that uses encrypted credentials from database
class ElevenLabsConfigSecure {
  final Ref ref;

  ElevenLabsConfigSecure(this.ref);

  static const String baseUrl = 'https://api.elevenlabs.io/v1';

  // Available voices
  static const Map<String, String> voices = {
    'EXAVITQu4vr4xnSDxMaL': 'Sarah (Female)',
    '21m00Tcm4TlvDq8ikWAM': 'Rachel (Female)',
    'AZnzlk1XvdvUeBnXmlld': 'Domi (Female)',
    'ErXwobaYiN019PkySvjV': 'Antoni (Male)',
    'VR6AewLTigWG4xSOukaG': 'Arnold (Male)',
    'pNInz6obpgDQGcFmaJgB': 'Adam (Male)',
  };

  // Default model - most reliable and widely supported
  static const String freeModel = 'eleven_monolingual_v1';

  // Available models (2025) - Verified working model IDs
  // Note: Some models require paid plans or specific access
  static const Map<String, String> models = {
    'eleven_monolingual_v1': 'Monolingual v1 (English, Most Stable)',
    'eleven_multilingual_v1': 'Multilingual v1 (29 Languages)',
    'eleven_multilingual_v2': 'Multilingual v2 (High Quality)',
    'eleven_turbo_v2': 'Turbo v2 (Fast)',
  };

  /// Get API key - first try database (encrypted), then fall back to .env
  Future<String> getApiKey() async {
    try {
      final credService = ref.read(globalCredentialsServiceProvider);
      final dbKey = await credService.getApiKey('elevenlabs');
      if (dbKey != null && dbKey.isNotEmpty) {
        return dbKey;
      }
    } catch (e) {
      // Fall back to .env if database fails
    }

    return dotenv.env['ELEVENLABS_API_KEY'] ?? '';
  }

  /// Get Agent ID from .env or database
  Future<String> getAgentId() async {
    try {
      final credService = ref.read(globalCredentialsServiceProvider);
      final dbAgentId = await credService.getApiKey('elevenlabs_agent_id');
      if (dbAgentId != null && dbAgentId.isNotEmpty) {
        return dbAgentId;
      }
    } catch (e) {
      // Fall back to .env if database fails
    }

    return dotenv.env['ELEVENLABS_AGENT_ID'] ?? '';
  }

  /// Store Agent ID in database (encrypted)
  Future<void> storeAgentId(String agentId) async {
    final credService = ref.read(globalCredentialsServiceProvider);
    await credService.storeApiKey(
      service: 'elevenlabs_agent_id',
      apiKey: agentId,
      description: 'ElevenLabs Agent ID',
    );
  }

  /// Store API key in database (encrypted)
  Future<void> storeApiKey(String apiKey) async {
    final credService = ref.read(globalCredentialsServiceProvider);
    await credService.storeApiKey(
      service: 'elevenlabs',
      apiKey: apiKey,
      description: 'ElevenLabs TTS API Key',
    );
  }

  /// Migrate API key from .env to database
  Future<void> migrateApiKeyToDatabase() async {
    final envKey = dotenv.env['ELEVENLABS_API_KEY'] ?? '';
    if (envKey.isNotEmpty) {
      await storeApiKey(envKey);
    }
  }
}

final elevenLabsConfigSecureProvider = Provider<ElevenLabsConfigSecure>((ref) {
  return ElevenLabsConfigSecure(ref);
});
