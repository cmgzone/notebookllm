import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../security/global_credentials_service.dart';

final aiTranscriptionServiceProvider = Provider<AITranscriptionService>((ref) {
  return AITranscriptionService(ref);
});

/// AI-powered transcription service using Deepgram for real-time,
/// multi-language speech recognition
class AITranscriptionService {
  final Ref ref;
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _chunkTimer;
  List<int> _audioBuffer = [];
  List<int> _overlapBuffer = [];
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isStopped = true;
  String _currentLanguage = 'multi';

  // Callbacks
  Function(String text, bool isFinal)? onTranscript;
  Function(String error)? onError;

  // Constants for audio processing
  static const int _sampleRate = 16000;
  static const int _bytesPerSample = 2;
  static const int _overlapDurationMs = 200; // Reduced for faster response
  static const int _chunkIntervalMs =
      500; // Send every 500ms for faster transcription
  static const int _minChunkBytes = 4000; // Reduced minimum for faster response

  int get _overlapBytes =>
      (_sampleRate * _bytesPerSample * _overlapDurationMs) ~/ 1000;

  AITranscriptionService(this.ref);

  Future<String?> _getDeepgramKey() async {
    final envKey = dotenv.env['DEEPGRAM_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) return envKey;
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      return await creds.getApiKey('deepgram');
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getGeminiKey() async {
    final envKey = dotenv.env['GEMINI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) return envKey;
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      return await creds.getApiKey('gemini');
    } catch (e) {
      return null;
    }
  }

  Future<bool> initialize() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('AI Transcription init error: $e');
      return false;
    }
  }

  /// Start real-time transcription
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(String error)? onErrorCallback,
    String language = 'multi',
  }) async {
    if (_isRecording) return;

    onTranscript = onResult;
    onError = onErrorCallback;
    _isRecording = true;
    _isProcessing = false;
    _isStopped = false;
    _audioBuffer = [];
    _overlapBuffer = [];
    _currentLanguage = language;

    debugPrint('Starting AI transcription (chunked mode)...');

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      _audioSubscription = stream.listen(
        (data) => _audioBuffer.addAll(data),
        onError: (e) {
          debugPrint('Audio stream error: $e');
          onError?.call('Audio stream error: $e');
        },
      );

      _chunkTimer = Timer.periodic(
        const Duration(milliseconds: _chunkIntervalMs),
        (_) => _processAudioChunk(),
      );

      debugPrint('AI Transcription started');
    } catch (e) {
      debugPrint('Start listening error: $e');
      onError?.call('Failed to start recording: $e');
      _isRecording = false;
    }
  }

  void _processAudioChunk() {
    if (!_isRecording || _audioBuffer.isEmpty || _isProcessing) return;

    final List<int> fullChunk = [..._overlapBuffer, ..._audioBuffer];

    if (_audioBuffer.length > _overlapBytes) {
      _overlapBuffer =
          _audioBuffer.sublist(_audioBuffer.length - _overlapBytes);
    } else {
      _overlapBuffer = List.from(_audioBuffer);
    }
    _audioBuffer = [];

    if (fullChunk.length >= _minChunkBytes) {
      _transcribeChunkAsync(Uint8List.fromList(fullChunk), _currentLanguage);
    }
  }

  Future<void> _transcribeChunkAsync(
      Uint8List audioData, String language) async {
    _isProcessing = true;
    try {
      await _transcribeChunk(audioData, language);
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _transcribeChunk(Uint8List audioData, String language) async {
    if (audioData.length < 1000 || _isStopped) return;

    final deepgramKey = await _getDeepgramKey();
    if (deepgramKey != null && deepgramKey.isNotEmpty) {
      await _transcribeWithDeepgram(audioData, deepgramKey, language);
      return;
    }

    final geminiKey = await _getGeminiKey();
    if (geminiKey != null && geminiKey.isNotEmpty) {
      await _transcribeWithGemini(audioData, geminiKey, language);
      return;
    }

    onError?.call('No transcription API key configured.');
  }

  Uint8List _createWavFile(Uint8List pcmData) {
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;
    final header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);

    // fmt chunk
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, 16000, Endian.little);
    header.setUint32(28, 32000, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);

    // data chunk
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final wavFile = Uint8List(44 + pcmData.length);
    wavFile.setAll(0, header.buffer.asUint8List());
    wavFile.setAll(44, pcmData);
    return wavFile;
  }

  Future<void> _transcribeWithDeepgram(
      Uint8List audioData, String apiKey, String language) async {
    try {
      final wavData = _createWavFile(audioData);
      String url =
          'https://api.deepgram.com/v1/listen?model=nova-2&punctuate=true&smart_format=true&encoding=linear16&sample_rate=16000&channels=1';

      if (language == 'multi') {
        url += '&detect_language=true';
      } else {
        url += '&language=$language';
      }

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Token $apiKey',
              'Content-Type': 'audio/wav',
            },
            body: wavData,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && !_isStopped) {
        final data = jsonDecode(response.body);
        final transcript = data['results']?['channels']?[0]?['alternatives']?[0]
            ?['transcript'] as String?;
        if (transcript != null && transcript.isNotEmpty) {
          onTranscript?.call(transcript, true);
        }
      } else if (response.statusCode != 200) {
        debugPrint('Deepgram error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Deepgram error: $e');
    }
  }

  Future<void> _transcribeWithGemini(
      Uint8List audioData, String apiKey, String language) async {
    try {
      final audioBase64 = base64Encode(audioData);
      final languageHint = language == 'multi'
          ? 'Detect the language automatically and transcribe.'
          : 'Transcribe in $language.';

      final response = await http
          .post(
            Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'inlineData': {
                        'mimeType': 'audio/pcm',
                        'data': audioBase64
                      }
                    },
                    {
                      'text':
                          'Transcribe this audio accurately. $languageHint Return ONLY the transcribed text.'
                    }
                  ]
                }
              ],
              'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 1000}
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && !_isStopped) {
        final data = jsonDecode(response.body);
        final transcript = data['candidates']?[0]?['content']?['parts']?[0]
            ?['text'] as String?;
        if (transcript != null && transcript.isNotEmpty) {
          onTranscript?.call(transcript.trim(), true);
        }
      }
    } catch (e) {
      debugPrint('Gemini error: $e');
    }
  }

  Future<void> stopListening({bool processRemaining = false}) async {
    _isStopped = true;
    _isRecording = false;

    _chunkTimer?.cancel();
    _chunkTimer = null;

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    _audioBuffer = [];
    _overlapBuffer = [];
    _isProcessing = false;
    onTranscript = null;
    onError = null;

    await _recorder.stop();
    debugPrint('AI Transcription stopped');
  }

  bool get isRecording => _isRecording;

  void dispose() {
    stopListening();
    _recorder.dispose();
  }
}

class TranscriptionSettings {
  final String provider;
  final String language;
  final bool punctuate;
  final bool smartFormat;

  TranscriptionSettings({
    this.provider = 'device',
    this.language = 'multi',
    this.punctuate = true,
    this.smartFormat = true,
  });

  static Future<TranscriptionSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return TranscriptionSettings(
      provider: prefs.getString('transcription_provider') ?? 'device',
      language: prefs.getString('transcription_language') ?? 'multi',
      punctuate: prefs.getBool('transcription_punctuate') ?? true,
      smartFormat: prefs.getBool('transcription_smart_format') ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transcription_provider', provider);
    await prefs.setString('transcription_language', language);
    await prefs.setBool('transcription_punctuate', punctuate);
    await prefs.setBool('transcription_smart_format', smartFormat);
  }
}
