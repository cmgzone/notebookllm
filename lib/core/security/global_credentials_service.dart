import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final globalCredentialsServiceProvider =
    Provider<GlobalCredentialsService>((ref) {
  return GlobalCredentialsService(ref);
});

/// Service for managing global API keys - now uses .env and secure storage
/// API keys are no longer stored in database, they're managed by backend
class GlobalCredentialsService {
  final Ref ref;
  static const _storage = FlutterSecureStorage();

  // Fixed encryption key for global credentials
  static const String _encryptionSecret = 'notebook_llm_global_secret_key_2024';

  GlobalCredentialsService(this.ref);

  // Generate encryption key from fixed secret
  encrypt.Key _getEncryptionKey() {
    final hash = sha256.convert(utf8.encode(_encryptionSecret));
    return encrypt.Key(Uint8List.fromList(hash.bytes));
  }

  // Encrypt API key for local storage
  String _encryptValue(String value) {
    final key = _getEncryptionKey();
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(value, iv: iv);
    return base64Encode(iv.bytes + encrypted.bytes);
  }

  // Decrypt API key
  String _decryptValue(String encryptedValue) {
    try {
      final key = _getEncryptionKey();

      if (!_isValidBase64(encryptedValue) || encryptedValue.length < 32) {
        return encryptedValue;
      }

      final combined = base64Decode(encryptedValue);
      if (combined.length < 17) {
        return encryptedValue;
      }

      final iv = encrypt.IV(Uint8List.fromList(combined.sublist(0, 16)));
      final encryptedBytes = Uint8List.fromList(combined.sublist(16));

      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted =
          encrypter.decrypt(encrypt.Encrypted(encryptedBytes), iv: iv);

      return decrypted;
    } catch (e) {
      return encryptedValue;
    }
  }

  bool _isValidBase64(String value) {
    try {
      if (value.length % 4 != 0) return false;
      base64Decode(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Store encrypted API key in secure storage
  Future<void> storeApiKey({
    required String service,
    required String apiKey,
    String? description,
  }) async {
    final encryptedKey = _encryptValue(apiKey);
    await _storage.write(key: 'api_key_$service', value: encryptedKey);
  }

  // Retrieve API key - try .env first, then secure storage
  Future<String?> getApiKey(String service) async {
    // Map service name to .env key format
    final envKey = _getEnvKeyName(service);

    // Try secure storage first (User override)
    final stored = await _storage.read(key: 'api_key_$service');
    if (stored != null && stored.isNotEmpty) {
      return _decryptValue(stored);
    }

    // Try .env file fallback
    final envValue = dotenv.env[envKey];
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }

    return null;
  }

  String _getEnvKeyName(String service) {
    switch (service.toLowerCase()) {
      case 'gemini':
        return 'GEMINI_API_KEY';
      case 'openrouter':
        return 'OPENROUTER_API_KEY';
      case 'elevenlabs':
        return 'ELEVENLABS_API_KEY';
      case 'serper':
        return 'SERPER_API_KEY';
      case 'murf':
        return 'MURF_API_KEY';
      default:
        return '${service.toUpperCase()}_API_KEY';
    }
  }

  // Delete API key from secure storage
  Future<void> deleteApiKey(String service) async {
    await _storage.delete(key: 'api_key_$service');
  }

  // List all stored services
  Future<List<Map<String, dynamic>>> listServices() async {
    // Return list of known services
    return [
      {'service_name': 'gemini', 'description': 'Gemini API Key'},
      {'service_name': 'openrouter', 'description': 'OpenRouter API Key'},
      {'service_name': 'elevenlabs', 'description': 'ElevenLabs API Key'},
      {'service_name': 'serper', 'description': 'Serper API Key'},
      {'service_name': 'murf', 'description': 'Murf API Key'},
    ];
  }

  // Migrate all API keys from .env to secure storage
  Future<void> migrateFromEnv(Map<String, String> envKeys) async {
    for (final entry in envKeys.entries) {
      if (entry.value.isNotEmpty) {
        await storeApiKey(
          service: entry.key.toLowerCase().replaceAll('_api_key', ''),
          apiKey: entry.value,
          description: '${entry.key} API Key',
        );
      }
    }
  }
}
