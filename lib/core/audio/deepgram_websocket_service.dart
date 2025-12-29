import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../security/global_credentials_service.dart';

final deepgramWebSocketProvider = Provider<DeepgramWebSocketService>((ref) {
  return DeepgramWebSocketService(ref);
});

/// Real-time streaming transcription using Deepgram WebSocket API
/// Much faster than REST API - provides instant transcription as you speak
class DeepgramWebSocketService {
  final Ref ref;
  final AudioRecorder _recorder = AudioRecorder();

  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription? _wsSubscription;

  bool _isListening = false;
  String _interimTranscript = '';
  String _finalTranscript = '';

  // Callbacks
  Function(String text, bool isFinal)? onTranscript;
  Function(String error)? onError;
  Function()? onReady;

  // Audio settings optimized for Deepgram
  static const int _sampleRate = 16000;
  static const int _channels = 1;
  static const String _encoding = 'linear16';

  DeepgramWebSocketService(this.ref);

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

  Future<bool> initialize() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Deepgram WebSocket init error: $e');
      return false;
    }
  }

  /// Start real-time streaming transcription via WebSocket
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(String error)? onErrorCallback,
    Function()? onReadyCallback,
    String language = 'en',
    bool detectLanguage = false,
    bool punctuate = true,
    bool smartFormat = true,
    bool interimResults = true,
    bool utteranceEndMs = true,
    String model = 'nova-2',
  }) async {
    if (_isListening) {
      debugPrint('Already listening');
      return;
    }

    final apiKey = await _getDeepgramKey();
    if (apiKey == null || apiKey.isEmpty) {
      onErrorCallback?.call('Deepgram API key not configured');
      return;
    }

    onTranscript = onResult;
    onError = onErrorCallback;
    onReady = onReadyCallback;
    _isListening = true;
    _interimTranscript = '';
    _finalTranscript = '';

    try {
      // Build WebSocket URL with parameters
      final params = <String, String>{
        'model': model,
        'encoding': _encoding,
        'sample_rate': _sampleRate.toString(),
        'channels': _channels.toString(),
        'punctuate': punctuate.toString(),
        'smart_format': smartFormat.toString(),
        'interim_results': interimResults.toString(),
        'vad_events': 'true',
        'endpointing': '300', // 300ms silence triggers utterance end
      };

      if (detectLanguage) {
        params['detect_language'] = 'true';
      } else {
        params['language'] = language;
      }

      if (utteranceEndMs) {
        params['utterance_end_ms'] = '1000'; // 1 second silence = utterance end
      }

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');

      final wsUrl = 'wss://api.deepgram.com/v1/listen?$queryString';

      debugPrint('Connecting to Deepgram WebSocket...');

      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['token', apiKey],
      );

      // Alternative: Use headers for auth (some implementations)
      // For Deepgram, we use the token protocol

      // Listen for WebSocket messages
      _wsSubscription = _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          debugPrint('WebSocket error: $error');
          onError?.call('WebSocket error: $error');
          stopListening();
        },
        onDone: () {
          debugPrint('WebSocket closed');
          if (_isListening) {
            stopListening();
          }
        },
      );

      // Start audio recording and stream to WebSocket
      await _startAudioStream();

      debugPrint('Deepgram WebSocket transcription started');
      onReady?.call();
    } catch (e) {
      debugPrint('Failed to start Deepgram WebSocket: $e');
      onError?.call('Failed to connect: $e');
      _isListening = false;
      await _cleanup();
    }
  }

  Future<void> _startAudioStream() async {
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: _channels,
        ),
      );

      _audioSubscription = stream.listen(
        (data) {
          if (_channel != null && _isListening) {
            // Send raw PCM audio directly to WebSocket
            _channel!.sink.add(data);
          }
        },
        onError: (e) {
          debugPrint('Audio stream error: $e');
          onError?.call('Audio error: $e');
        },
      );
    } catch (e) {
      debugPrint('Failed to start audio stream: $e');
      throw Exception('Microphone access failed: $e');
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final type = data['type'] as String?;

      switch (type) {
        case 'Results':
          _handleTranscriptResult(data);
          break;
        case 'Metadata':
          debugPrint('Deepgram metadata: ${data['request_id']}');
          break;
        case 'SpeechStarted':
          debugPrint('Speech started detected');
          break;
        case 'UtteranceEnd':
          debugPrint('Utterance end detected');
          // Finalize any pending interim transcript
          if (_interimTranscript.isNotEmpty) {
            onTranscript?.call(_interimTranscript, true);
            _finalTranscript += ' $_interimTranscript';
            _interimTranscript = '';
          }
          break;
        case 'Error':
          final errorMsg = data['message'] ?? 'Unknown error';
          debugPrint('Deepgram error: $errorMsg');
          onError?.call(errorMsg);
          break;
        default:
          debugPrint('Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  void _handleTranscriptResult(Map<String, dynamic> data) {
    try {
      final channel = data['channel'] as Map<String, dynamic>?;
      final alternatives = channel?['alternatives'] as List?;

      if (alternatives == null || alternatives.isEmpty) return;

      final firstAlt = alternatives[0] as Map<String, dynamic>;
      final transcript = firstAlt['transcript'] as String? ?? '';
      final isFinal = data['is_final'] as bool? ?? false;
      final speechFinal = data['speech_final'] as bool? ?? false;

      if (transcript.isEmpty) return;

      if (isFinal || speechFinal) {
        // Final result - append to final transcript
        _finalTranscript += ' $transcript';
        _interimTranscript = '';
        onTranscript?.call(transcript, true);
      } else {
        // Interim result - update interim transcript
        _interimTranscript = transcript;
        onTranscript?.call(transcript, false);
      }

      // Log confidence if available
      final confidence = firstAlt['confidence'] as double?;
      if (confidence != null) {
        debugPrint(
            'Transcript (${isFinal ? "final" : "interim"}): "$transcript" [${(confidence * 100).toStringAsFixed(1)}%]');
      }
    } catch (e) {
      debugPrint('Error handling transcript result: $e');
    }
  }

  /// Stop listening and close connections
  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;
    debugPrint('Stopping Deepgram WebSocket transcription...');

    // Send close message to Deepgram
    try {
      _channel?.sink.add(jsonEncode({'type': 'CloseStream'}));
    } catch (e) {
      debugPrint('Error sending close message: $e');
    }

    await _cleanup();
    debugPrint('Deepgram WebSocket transcription stopped');
  }

  Future<void> _cleanup() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    await _wsSubscription?.cancel();
    _wsSubscription = null;

    await _channel?.sink.close();
    _channel = null;

    await _recorder.stop();

    onTranscript = null;
    onError = null;
    onReady = null;
  }

  /// Get the full transcript accumulated so far
  String get fullTranscript => _finalTranscript.trim();

  /// Get the current interim (not yet finalized) transcript
  String get interimTranscript => _interimTranscript;

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Dispose resources
  void dispose() {
    stopListening();
    _recorder.dispose();
  }
}

/// Supported Deepgram models
class DeepgramModels {
  static const String nova2 = 'nova-2'; // Best accuracy, fastest
  static const String nova2General = 'nova-2-general';
  static const String nova2Meeting = 'nova-2-meeting';
  static const String nova2Phonecall = 'nova-2-phonecall';
  static const String nova2Medical = 'nova-2-medical';
  static const String enhanced = 'enhanced'; // Legacy enhanced
  static const String base = 'base'; // Fastest, lower accuracy

  static const Map<String, String> displayNames = {
    nova2: 'Nova-2 (Best)',
    nova2General: 'Nova-2 General',
    nova2Meeting: 'Nova-2 Meeting',
    nova2Phonecall: 'Nova-2 Phone',
    nova2Medical: 'Nova-2 Medical',
    enhanced: 'Enhanced',
    base: 'Base (Fastest)',
  };
}

/// Supported languages for Deepgram
class DeepgramLanguages {
  static const Map<String, String> supported = {
    'en': 'English',
    'en-US': 'English (US)',
    'en-GB': 'English (UK)',
    'en-AU': 'English (Australia)',
    'en-IN': 'English (India)',
    'sw': 'Swahili',
    'es': 'Spanish',
    'es-419': 'Spanish (Latin America)',
    'fr': 'French',
    'fr-CA': 'French (Canada)',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'pt-BR': 'Portuguese (Brazil)',
    'nl': 'Dutch',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese (Mandarin)',
    'zh-TW': 'Chinese (Taiwan)',
    'hi': 'Hindi',
    'ru': 'Russian',
    'uk': 'Ukrainian',
    'pl': 'Polish',
    'tr': 'Turkish',
    'sv': 'Swedish',
    'da': 'Danish',
    'no': 'Norwegian',
    'fi': 'Finnish',
    'id': 'Indonesian',
    'ms': 'Malay',
    'th': 'Thai',
    'vi': 'Vietnamese',
    'ta': 'Tamil',
    'te': 'Telugu',
  };
}
