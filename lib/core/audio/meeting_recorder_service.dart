import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../security/global_credentials_service.dart';

final meetingRecorderProvider = Provider<MeetingRecorderService>((ref) {
  return MeetingRecorderService(ref);
});

/// Meeting recording service that saves playable audio files
/// with optional noise reduction and AI transcription
class MeetingRecorderService {
  final Ref ref;
  final AudioRecorder _recorder = AudioRecorder();

  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  bool _isRecording = false;
  bool _isPaused = false;

  // Recording settings
  final int _sampleRate = 44100;
  final int _bitRate = 128000;

  // Saved recordings
  final List<MeetingRecording> _recordings = [];

  MeetingRecorderService(this.ref);

  /// Initialize and check permissions
  Future<bool> initialize() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Meeting recorder init error: $e');
      return false;
    }
  }

  /// Start recording audio to a file
  Future<String?> startRecording({
    String? title,
    bool noiseReduction = true,
  }) async {
    if (_isRecording) {
      debugPrint('Already recording');
      return _currentRecordingPath;
    }

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      // Create recordings directory
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/meeting_recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Generate filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final safeTitle = (title ?? 'meeting')
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final filename = '${safeTitle}_$timestamp.m4a';
      _currentRecordingPath = '${recordingsDir.path}/$filename';

      _recordingStartTime = DateTime.now();

      // Configure recording with noise suppression
      // AAC encoder produces high-quality, playable audio
      final config = RecordConfig(
        encoder: AudioEncoder.aacLc, // High quality AAC
        sampleRate: _sampleRate,
        bitRate: _bitRate,
        numChannels: 1, // Mono for speech
        // Enable noise suppression if available
        androidConfig: AndroidRecordConfig(
          audioSource: noiseReduction
              ? AndroidAudioSource
                  .voiceRecognition // Has built-in noise suppression
              : AndroidAudioSource.mic,
        ),
        // iOS uses voice processing for noise reduction
        autoGain: noiseReduction,
        echoCancel: noiseReduction,
        noiseSuppress: noiseReduction,
      );

      debugPrint(
          'Starting recording with config: encoder=${config.encoder}, sampleRate=${config.sampleRate}');
      debugPrint('Recording path: $_currentRecordingPath');

      await _recorder.start(config, path: _currentRecordingPath!);

      _isRecording = true;
      _isPaused = false;

      debugPrint('Started recording to: $_currentRecordingPath');
      return _currentRecordingPath;
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      _currentRecordingPath = null;
      rethrow;
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;

    try {
      await _recorder.pause();
      _isPaused = true;
      debugPrint('Recording paused');
    } catch (e) {
      debugPrint('Failed to pause recording: $e');
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;

    try {
      await _recorder.resume();
      _isPaused = false;
      debugPrint('Recording resumed');
    } catch (e) {
      debugPrint('Failed to resume recording: $e');
    }
  }

  /// Stop recording and return the file path
  Future<MeetingRecording?> stopRecording({String? title}) async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _isPaused = false;

      if (path == null || path.isEmpty) {
        debugPrint('No recording path returned');
        return null;
      }

      final file = File(path);
      if (!await file.exists()) {
        debugPrint('Recording file does not exist: $path');
        return null;
      }

      final fileSize = await file.length();
      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;

      final recording = MeetingRecording(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title ??
            'Meeting ${DateFormat('MMM d, HH:mm').format(_recordingStartTime ?? DateTime.now())}',
        filePath: path,
        duration: duration,
        fileSize: fileSize,
        createdAt: _recordingStartTime ?? DateTime.now(),
        isTranscribed: false,
      );

      _recordings.add(recording);
      _currentRecordingPath = null;
      _recordingStartTime = null;

      debugPrint(
          'Recording saved: $path (${_formatFileSize(fileSize)}, ${_formatDuration(duration)})');
      return recording;
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.stop();

      // Delete the partial file
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    } finally {
      _isRecording = false;
      _isPaused = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;
    }
  }

  /// Transcribe a recorded audio file using AI
  Future<String> transcribeRecording(
    MeetingRecording recording, {
    String language = 'en',
    bool detectLanguage = false,
    Function(double progress)? onProgress,
  }) async {
    final file = File(recording.filePath);
    if (!await file.exists()) {
      throw Exception('Recording file not found: ${recording.filePath}');
    }

    onProgress?.call(0.1);

    // Try Deepgram first (best for audio files)
    final deepgramKey = await _getDeepgramKey();
    if (deepgramKey != null && deepgramKey.isNotEmpty) {
      return await _transcribeWithDeepgram(
          file, deepgramKey, language, detectLanguage, onProgress);
    }

    // Fallback to Gemini
    final geminiKey = await _getGeminiKey();
    if (geminiKey != null && geminiKey.isNotEmpty) {
      return await _transcribeWithGemini(file, geminiKey, language, onProgress);
    }

    throw Exception(
        'No transcription API key configured. Please add Deepgram or Gemini API key in settings.');
  }

  Future<String> _transcribeWithDeepgram(
    File file,
    String apiKey,
    String language,
    bool detectLanguage,
    Function(double)? onProgress,
  ) async {
    try {
      onProgress?.call(0.2);

      final audioBytes = await file.readAsBytes();
      debugPrint('Transcribing ${audioBytes.length} bytes with Deepgram...');

      // Determine file type from extension
      final extension = file.path.split('.').last.toLowerCase();
      String contentType = 'audio/mp4'; // Default for m4a
      if (extension == 'wav') contentType = 'audio/wav';
      if (extension == 'mp3') contentType = 'audio/mpeg';
      if (extension == 'ogg') contentType = 'audio/ogg';
      if (extension == 'flac') contentType = 'audio/flac';

      onProgress?.call(0.3);

      // Build URL with parameters
      String url = 'https://api.deepgram.com/v1/listen?'
          'model=nova-2&'
          'punctuate=true&'
          'smart_format=true&'
          'paragraphs=true&'
          'diarize=true&' // Speaker detection
          'utterances=true';

      // For WAV files from AI transcription (16kHz mono PCM), add encoding params
      if (extension == 'wav') {
        url += '&encoding=linear16&sample_rate=16000&channels=1';
      }

      if (detectLanguage) {
        url += '&detect_language=true';
      } else {
        url += '&language=$language';
      }

      onProgress?.call(0.4);
      debugPrint('Deepgram URL: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Token $apiKey',
              'Content-Type': contentType,
            },
            body: audioBytes,
          )
          .timeout(const Duration(minutes: 10)); // Long timeout for large files

      onProgress?.call(0.8);
      debugPrint('Deepgram response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract transcript with speaker labels if available
        final results = data['results'];
        if (results != null) {
          // Try to get utterances with speaker labels
          final utterances = results['utterances'] as List?;
          if (utterances != null && utterances.isNotEmpty) {
            final buffer = StringBuffer();
            for (final utterance in utterances) {
              final speaker = utterance['speaker'] ?? 0;
              final text = utterance['transcript'] ?? '';
              final start = utterance['start'] ?? 0.0;
              buffer.writeln(
                  '[Speaker $speaker @ ${_formatSeconds(start)}] $text');
            }
            onProgress?.call(1.0);
            return buffer.toString().trim();
          }

          // Fallback to simple transcript
          final transcript = results['channels']?[0]?['alternatives']?[0]
              ?['transcript'] as String?;
          if (transcript != null && transcript.isNotEmpty) {
            onProgress?.call(1.0);
            return transcript;
          }
        }

        throw Exception('No speech detected in the audio');
      } else {
        debugPrint('Deepgram error response: ${response.body}');
        final error = jsonDecode(response.body);
        final errMsg = error['err_msg'] ??
            error['error'] ??
            'Status ${response.statusCode}';
        throw Exception('Deepgram API error: $errMsg');
      }
    } catch (e) {
      debugPrint('Deepgram transcription error: $e');
      rethrow;
    }
  }

  Future<String> _transcribeWithGemini(
    File file,
    String apiKey,
    String language,
    Function(double)? onProgress,
  ) async {
    try {
      onProgress?.call(0.2);

      final audioBytes = await file.readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      // Determine MIME type
      final extension = file.path.split('.').last.toLowerCase();
      String mimeType = 'audio/mp4';
      if (extension == 'wav') mimeType = 'audio/wav';
      if (extension == 'mp3') mimeType = 'audio/mpeg';
      if (extension == 'ogg') mimeType = 'audio/ogg';

      onProgress?.call(0.4);

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
                        'mimeType': mimeType,
                        'data': audioBase64,
                      }
                    },
                    {
                      'text':
                          '''Transcribe this audio recording accurately and completely.
                  
Instructions:
- Transcribe all spoken words exactly as heard
- Include timestamps at natural breaks (every 30-60 seconds)
- If multiple speakers are detected, label them as Speaker 1, Speaker 2, etc.
- Include punctuation and paragraph breaks for readability
- Note any significant non-speech sounds like [laughter], [applause], [pause]
- Language: ${language == 'en' ? 'English' : 'Auto-detect'}

Return ONLY the transcription, no additional commentary.'''
                    }
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.1,
                'maxOutputTokens': 8192,
              }
            }),
          )
          .timeout(const Duration(minutes: 10));

      onProgress?.call(0.9);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transcript = data['candidates']?[0]?['content']?['parts']?[0]
            ?['text'] as String?;

        if (transcript != null && transcript.isNotEmpty) {
          onProgress?.call(1.0);
          return transcript.trim();
        }

        throw Exception('No transcript in Gemini response');
      } else {
        throw Exception('Gemini error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Gemini transcription error: $e');
      rethrow;
    }
  }

  /// Get all saved recordings
  Future<List<MeetingRecording>> getRecordings() async {
    // Load from disk if not already loaded
    if (_recordings.isEmpty) {
      await _loadRecordingsFromDisk();
    }
    return List.from(_recordings);
  }

  Future<void> _loadRecordingsFromDisk() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/meeting_recordings');

      if (!await recordingsDir.exists()) return;

      final files = await recordingsDir.list().toList();
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.m4a')) {
          final stat = await entity.stat();
          final filename = entity.path.split('/').last;

          // Check if already in list
          if (_recordings.any((r) => r.filePath == entity.path)) continue;

          _recordings.add(MeetingRecording(
            id: stat.modified.millisecondsSinceEpoch.toString(),
            title: filename.replaceAll('.m4a', '').replaceAll('_', ' '),
            filePath: entity.path,
            duration: Duration.zero, // Unknown without metadata
            fileSize: stat.size,
            createdAt: stat.modified,
            isTranscribed: false,
          ));
        }
      }

      // Sort by date, newest first
      _recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Error loading recordings: $e');
    }
  }

  /// Delete a recording
  Future<bool> deleteRecording(MeetingRecording recording) async {
    try {
      final file = File(recording.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      _recordings.removeWhere((r) => r.id == recording.id);
      return true;
    } catch (e) {
      debugPrint('Error deleting recording: $e');
      return false;
    }
  }

  /// Get API keys
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

  // Helpers
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatSeconds(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  // Getters
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String? get currentRecordingPath => _currentRecordingPath;
  Duration get recordingDuration => _recordingStartTime != null
      ? DateTime.now().difference(_recordingStartTime!)
      : Duration.zero;

  void dispose() {
    if (_isRecording) {
      _recorder.stop();
    }
    _recorder.dispose();
  }
}

/// Model for a meeting recording
class MeetingRecording {
  final String id;
  final String title;
  final String filePath;
  final Duration duration;
  final int fileSize;
  final DateTime createdAt;
  final bool isTranscribed;
  final String? transcript;

  MeetingRecording({
    required this.id,
    required this.title,
    required this.filePath,
    required this.duration,
    required this.fileSize,
    required this.createdAt,
    this.isTranscribed = false,
    this.transcript,
  });

  MeetingRecording copyWith({
    String? title,
    bool? isTranscribed,
    String? transcript,
  }) {
    return MeetingRecording(
      id: id,
      title: title ?? this.title,
      filePath: filePath,
      duration: duration,
      fileSize: fileSize,
      createdAt: createdAt,
      isTranscribed: isTranscribed ?? this.isTranscribed,
      transcript: transcript ?? this.transcript,
    );
  }

  String get formattedDuration {
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
