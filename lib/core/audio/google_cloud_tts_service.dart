import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../security/global_credentials_service.dart';

// Provider for Google Cloud TTS service
final googleCloudTtsServiceProvider = Provider<GoogleCloudTtsService>((ref) {
  return GoogleCloudTtsService(ref);
});

class GoogleCloudTtsService {
  final Ref ref;
  String? _cachedApiKey;

  GoogleCloudTtsService(this.ref);

  static const String baseUrl = 'https://texttospeech.googleapis.com/v1';

  // Premium Voices (Journey, Studio, Neural2)
  static const Map<String, String> voices = {
    // Journey Voices (Best for storytelling)
    'en-US-Journey-D': 'Journey Male (Ultra Premium)',
    'en-US-Journey-F': 'Journey Female (Ultra Premium)',

    // Studio Voices (Professional)
    'en-US-Studio-M': 'Studio Male (Professional)',
    'en-US-Studio-O': 'Studio Female (Professional)',

    // Neural2 Voices (High Quality)
    'en-US-Neural2-A': 'Neural2 Female 1',
    'en-US-Neural2-C': 'Neural2 Female 2',
    'en-US-Neural2-D': 'Neural2 Male 1',
    'en-US-Neural2-F': 'Neural2 Female 3',
    'en-US-Neural2-H': 'Neural2 Female 4',
    'en-US-Neural2-I': 'Neural2 Male 2',
    'en-US-Neural2-J': 'Neural2 Male 3',

    // Wavenet (Standard Premium)
    'en-US-Wavenet-A': 'Wavenet Female 1',
    'en-US-Wavenet-B': 'Wavenet Male 1',
    'en-US-Wavenet-C': 'Wavenet Female 2',
    'en-US-Wavenet-D': 'Wavenet Male 2',
  };

  Future<String> get apiKey async {
    if (_cachedApiKey != null) return _cachedApiKey!;

    try {
      final credService = ref.read(globalCredentialsServiceProvider);
      final dbKey = await credService.getApiKey('google_cloud_tts');
      if (dbKey != null && dbKey.isNotEmpty) {
        _cachedApiKey = dbKey;
        return dbKey;
      }
    } catch (e) {
      // Fallback to env
    }

    _cachedApiKey = dotenv.env['GOOGLE_CLOUD_TTS_API_KEY'] ?? '';
    return _cachedApiKey!;
  }

  Future<Uint8List> synthesize(
    String text, {
    String voiceId = 'en-US-Journey-F',
    double speed = 1.0,
    double pitch = 0.0,
  }) async {
    final key = await apiKey;
    if (key.isEmpty) {
      throw Exception('Missing Google Cloud TTS API Key');
    }

    // Determine voice type based on ID
    // Journey voices require specific config
    // final isJourney = voiceId.contains('Journey');

    final Map<String, dynamic> voiceConfig = {
      'languageCode': 'en-US',
      'name': voiceId,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/text:synthesize?key=$key'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'input': {'text': text},
        'voice': voiceConfig,
        'audioConfig': {
          'audioEncoding': 'MP3',
          'speakingRate': speed,
          'pitch': pitch,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['audioContent'] != null) {
        return base64Decode(data['audioContent']);
      }
      throw Exception('No audio content in response');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
          'Google Cloud TTS Error: ${error['error']?['message'] ?? response.body}');
    }
  }
}
