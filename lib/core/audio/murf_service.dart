import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../security/global_credentials_service.dart';

final murfServiceProvider = Provider<MurfService>((ref) {
  return MurfService(ref);
});

class MurfService {
  final Ref ref;
  String? _cachedApiKey;

  MurfService(this.ref);

  static const String baseUrl = 'https://api.murf.ai/v1';

  // Common Voices (Gen 2) - Expanded list for podcast support
  static const Map<String, String> voices = {
    // Female voices (great for podcast hosts)
    'en-US-natalie': 'Natalie (Female - Conversational)',
    'en-US-iris': 'Iris (Female - Professional)',
    'en-US-brianna': 'Brianna (Female - Friendly)',
    'en-US-hazel': 'Hazel (Female - Warm)',
    'en-US-daisy': 'Daisy (Female - Upbeat)',
    'en-US-julia': 'Julia (Female - Clear)',
    'en-US-alison': 'Alison (Female - Calm)',
    // Male voices (great for podcast co-hosts)
    'en-US-miles': 'Miles (Male - Authoritative)',
    'en-US-michael': 'Michael (Male - Friendly)',
    'en-US-cooper': 'Cooper (Male - Professional)',
    'en-US-terrell': 'Terrell (Male - Engaging)',
    'en-US-marcus': 'Marcus (Male - Deep)',
    'en-US-lucas': 'Lucas (Male - Conversational)',
    'en-US-ken': 'Ken (Male - Warm)',
  };

  // Separate lists for easier podcast host selection
  static const List<String> femaleVoices = [
    'en-US-natalie',
    'en-US-iris',
    'en-US-brianna',
    'en-US-hazel',
    'en-US-daisy',
    'en-US-julia',
    'en-US-alison',
  ];

  static const List<String> maleVoices = [
    'en-US-miles',
    'en-US-michael',
    'en-US-cooper',
    'en-US-terrell',
    'en-US-marcus',
    'en-US-lucas',
    'en-US-ken',
  ];

  // Available voice styles
  static const List<String> styles = [
    'General',
    'Conversational',
    'Narration',
    'Newscast',
    'Promo',
  ];

  Future<String> get apiKey async {
    if (_cachedApiKey != null) return _cachedApiKey!;

    try {
      final credService = ref.read(globalCredentialsServiceProvider);
      final dbKey = await credService.getApiKey('murf');
      if (dbKey != null && dbKey.isNotEmpty) {
        _cachedApiKey = dbKey;
        return dbKey;
      }
    } catch (e) {
      // Fallback
    }

    _cachedApiKey = dotenv.env['MURF_API_KEY'] ?? '';
    return _cachedApiKey!;
  }

  Future<Uint8List> generateSpeech(
    String text, {
    String voiceId = 'en-US-natalie',
    String style = 'General',
    int rate = 0,
    int pitch = 0,
    String format = 'MP3',
    int sampleRate = 44100,
  }) async {
    final key = await apiKey;
    if (key.isEmpty) {
      throw Exception('Missing MURF_API_KEY');
    }

    final url = Uri.parse('$baseUrl/speech/generate');

    debugPrint(
        '[Murf] Generating speech for: "${text.substring(0, min(20, text.length))}..."');
    debugPrint('[Murf] Voice: $voiceId, Format: $format');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'api-key': key,
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'voiceId': voiceId,
        'style': style,
        'text': text,
        'rate': rate,
        'pitch': pitch,
        'sampleRate': sampleRate,
        'format': format,
        'channelType': 'MONO',
        'modelVersion': 'GEN2',
        'multiNativeLocale': 'en-US',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Check for encoded audio first (for PCM format)
      if (data['encodedAudio'] != null) {
        debugPrint('[Murf] Got encoded audio data');
        return base64Decode(data['encodedAudio']);
      }

      // Fall back to audio URL
      final audioUrl = data['audioFile'];
      if (audioUrl == null) {
        throw Exception('Murf API did not return audio data or URL.');
      }

      debugPrint('[Murf] Downloading audio from: $audioUrl');
      final audioResponse = await http.get(Uri.parse(audioUrl));
      if (audioResponse.statusCode == 200) {
        return audioResponse.bodyBytes;
      } else {
        throw Exception(
            'Failed to download audio file from Murf: ${audioResponse.statusCode}');
      }
    } else {
      debugPrint('[Murf] API Error: ${response.body}');
      throw Exception(
          'Murf API failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// Generate PCM audio that can be concatenated with other PCM chunks
  /// Returns raw PCM data (16-bit signed little-endian, 44100Hz mono)
  static const int pcmSampleRate = 44100;

  Future<Uint8List> generateSpeechPCM(
    String text, {
    String voiceId = 'en-US-natalie',
    String style = 'Conversational',
    int rate = 0,
    int pitch = 0,
  }) async {
    return await generateSpeech(
      text,
      voiceId: voiceId,
      style: style,
      rate: rate,
      pitch: pitch,
      format: 'PCM',
      sampleRate: pcmSampleRate,
    );
  }

  /// Wrap raw PCM data with a WAV header to create a playable file
  static Uint8List wrapPCMWithWavHeader(Uint8List pcmData,
      {int sampleRate = pcmSampleRate}) {
    final byteRate = sampleRate * 2; // 16-bit mono = 2 bytes per sample
    final dataSize = pcmData.length;
    final fileSize =
        dataSize + 36; // Header is 44 bytes, but we exclude RIFF+size (8 bytes)

    final header = ByteData(44);

    // RIFF header
    header.setUint32(0, 0x46464952, Endian.little); // "RIFF"
    header.setUint32(4, fileSize, Endian.little); // File size - 8
    header.setUint32(8, 0x45564157, Endian.little); // "WAVE"

    // fmt sub-chunk
    header.setUint32(12, 0x20746D66, Endian.little); // "fmt "
    header.setUint32(16, 16, Endian.little); // Sub-chunk size (16 for PCM)
    header.setUint16(20, 1, Endian.little); // Audio format (1 = PCM)
    header.setUint16(22, 1, Endian.little); // Num channels (1 = mono)
    header.setUint32(24, sampleRate, Endian.little); // Sample rate
    header.setUint32(28, byteRate, Endian.little); // Byte rate
    header.setUint16(32, 2, Endian.little); // Block align (2 for 16-bit mono)
    header.setUint16(34, 16, Endian.little); // Bits per sample

    // data sub-chunk
    header.setUint32(36, 0x61746164, Endian.little); // "data"
    header.setUint32(40, dataSize, Endian.little); // Data size

    // Combine header and PCM data
    final result = BytesBuilder();
    result.add(header.buffer.asUint8List());
    result.add(pcmData);

    return result.takeBytes();
  }

  int min(int a, int b) => a < b ? a : b;
}
