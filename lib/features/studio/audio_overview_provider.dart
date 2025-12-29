import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_overview.dart';

import '../../core/ai/gemini_service.dart';
import '../../core/ai/openrouter_service.dart';
import '../../core/audio/elevenlabs_service.dart';
import '../../core/audio/google_cloud_tts_service.dart';
import '../../core/audio/murf_service.dart';
import '../../core/ai/ai_settings_service.dart';
import '../../core/security/global_credentials_service.dart';
import '../../core/services/wakelock_service.dart';
import '../../core/services/overlay_bubble_service.dart';
import '../../core/api/api_service.dart';
import '../sources/source_provider.dart';

// Timeouts and retry settings
const Duration _aiTimeout = Duration(seconds: 90);
const Duration _ttsTimeout = Duration(seconds: 60);
const int _maxRetries = 3;
const Duration _retryDelay = Duration(seconds: 2);

// State class to track overviews and generation progress
class AudioStudioState {
  final List<AudioOverview> overviews;
  final bool isGenerating;
  final String progressMessage;
  final double progressValue; // 0 to 100
  final bool isCancelled;

  const AudioStudioState({
    this.overviews = const [],
    this.isGenerating = false,
    this.progressMessage = '',
    this.progressValue = 0,
    this.isCancelled = false,
  });

  AudioStudioState copyWith({
    List<AudioOverview>? overviews,
    bool? isGenerating,
    String? progressMessage,
    double? progressValue,
    bool? isCancelled,
  }) {
    return AudioStudioState(
      overviews: overviews ?? this.overviews,
      isGenerating: isGenerating ?? this.isGenerating,
      progressMessage: progressMessage ?? this.progressMessage,
      progressValue: progressValue ?? this.progressValue,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }
}

class AudioOverviewNotifier extends StateNotifier<AudioStudioState> {
  AudioOverviewNotifier(this.ref) : super(const AudioStudioState()) {
    _loadOverviews();
  }
  final Ref ref;

  Future<void> _loadOverviews() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getAudioOverviews();
      final overviews = data.map((raw) {
        return AudioOverview(
          id: raw['id'] ?? '',
          title: raw['title'] ?? '',
          url: raw['audio_path'] ?? '',
          duration: Duration(seconds: raw['duration_seconds'] ?? 0),
          createdAt:
              DateTime.tryParse(raw['created_at'] ?? '') ?? DateTime.now(),
        );
      }).toList();
      state = state.copyWith(overviews: overviews);
    } catch (e) {
      debugPrint('Error loading audio overviews: $e');
    }
  }

  Future<void> _saveOverview(AudioOverview overview) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.saveAudioOverview({
        'id': overview.id,
        'title': overview.title,
        'audioPath': overview.url,
        'durationSeconds': overview.duration.inSeconds,
        'format': overview.url.endsWith('.wav') ? 'podcast' : 'monologue',
      });
    } catch (e) {
      debugPrint('Error saving audio overview: $e');
    }
  }

  Future<void> deleteOverview(String id) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteAudioOverview(id);
      state = state.copyWith(
        overviews: state.overviews.where((o) => o.id != id).toList(),
      );
    } catch (e) {
      debugPrint('Error deleting audio overview: $e');
    }
  }

  Future<String> _callAI(String prompt) async {
    final settings = await AISettingsService.getSettings();
    final model = settings.model;

    if (model == null || model.isEmpty) {
      throw Exception(
          'No AI model selected. Please configure a model in settings.');
    }

    final creds = ref.read(globalCredentialsServiceProvider);

    debugPrint(
        '[AudioOverviewProvider] Using AI provider: ${settings.provider}, model: $model');

    try {
      if (settings.provider == 'openrouter') {
        final apiKey = await creds.getApiKey('openrouter');
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception(
              'OpenRouter API key not found. Please configure it in Settings.');
        }
        final openRouter = OpenRouterService();
        return await openRouter
            .generateContent(prompt,
                model: model, apiKey: apiKey, maxTokens: 8192)
            .timeout(_aiTimeout);
      } else {
        final apiKey = await creds.getApiKey('gemini');
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception(
              'Gemini API key not found. Please configure it in Settings.');
        }
        final gemini = GeminiService(apiKey: apiKey);
        return await gemini
            .generateContent(prompt, model: model, maxTokens: 8192)
            .timeout(_aiTimeout);
      }
    } on TimeoutException {
      throw Exception(
          'AI generation timed out after ${_aiTimeout.inSeconds}s. Try again with shorter content.');
    }
  }

  /// Cancel ongoing generation
  void cancelGeneration() {
    if (state.isGenerating) {
      state = state.copyWith(
        isCancelled: true,
        progressMessage: 'Cancelling...',
      );
      debugPrint('[AudioOverviewProvider] Generation cancelled by user');
    }
  }

  /// Check if we should abort due to cancellation
  bool get _shouldAbort => state.isCancelled;

  void _updateStatus(String message, [double progress = -1]) {
    if (_shouldAbort) return; // Don't update if cancelled

    state = state.copyWith(
      isGenerating: true,
      progressMessage: message,
      progressValue: progress >= 0 ? progress : state.progressValue,
    );
    // Also update global bubble for background consistency
    if (progress >= 0) {
      overlayBubbleService.updateStatus(message, progress: progress.round());
    } else {
      overlayBubbleService.updateStatus(message);
    }
  }

  /// TTS with retry logic and timeout
  Future<Uint8List> _generateTTSWithRetry({
    required Future<Uint8List> Function() primaryGen,
    required Future<Uint8List> Function() fallback1,
    required Future<Uint8List> Function() fallback2,
    required String segmentInfo,
  }) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      if (_shouldAbort) throw Exception('Cancelled');

      try {
        debugPrint(
            '[TTS] $segmentInfo - Attempt $attempt/$_maxRetries (primary)');
        return await primaryGen().timeout(_ttsTimeout);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('[TTS] Primary failed: $e');

        // Try fallback 1
        try {
          debugPrint('[TTS] $segmentInfo - Trying fallback 1');
          return await fallback1().timeout(_ttsTimeout);
        } catch (e2) {
          debugPrint('[TTS] Fallback 1 failed: $e2');

          // Try fallback 2
          try {
            debugPrint('[TTS] $segmentInfo - Trying fallback 2');
            return await fallback2().timeout(_ttsTimeout);
          } catch (e3) {
            debugPrint('[TTS] Fallback 2 failed: $e3');
            lastError = e3 is Exception ? e3 : Exception(e3.toString());
          }
        }
      }

      // Wait before retry (exponential backoff)
      if (attempt < _maxRetries) {
        final delay = _retryDelay * attempt;
        debugPrint('[TTS] Waiting ${delay.inSeconds}s before retry...');
        await Future.delayed(delay);
      }
    }

    throw lastError ?? Exception('All TTS attempts failed for $segmentInfo');
  }

  Future<void> generate(
    String title, {
    bool isPodcast = false,
    String? topic,
    List<String> hosts = const ['Sarah', 'Adam'],
  }) async {
    // Keep screen awake during audio generation
    await wakelockService.acquire();

    // Start generation state (reset cancellation flag)
    state = state.copyWith(
      isGenerating: true,
      isCancelled: false,
      progressMessage: 'Preparing...',
      progressValue: 0,
    );

    try {
      final sources = ref.read(sourceProvider);
      if (sources.isEmpty) throw Exception('No sources available');

      // 1. Generate Script using configured AI provider
      // Limit content to avoid token limits (approx 30k chars for safety)
      String context = sources.map((s) => s.content).join('\n\n');
      if (context.length > 30000) {
        debugPrint(
            '[AudioOverview] Content too long (${context.length} chars), truncating to 30k');
        context = context.substring(0, 30000);
      }

      String script;
      List<Map<String, String>> podcastSegments = [];

      if (_shouldAbort) throw Exception('Cancelled');
      _updateStatus('Writing Script...', 10);

      if (isPodcast) {
        if (_shouldAbort) throw Exception('Cancelled');

        // Podcast prompt
        final topicInstruction = topic != null && topic.isNotEmpty
            ? 'Focus specifically on this topic: "$topic".'
            : '';

        final host1 = hosts.isNotEmpty ? hosts[0] : 'Sarah';
        final host2 = hosts.length > 1 ? hosts[1] : 'Adam';

        final prompt = '''
Create an engaging "Deep Dive" podcast script based on the following content.
Two hosts: "$host1" (enthusiastic, curious) and "$host2" (analytical, expert).
They should discuss the material naturally, asking each other questions and summarizing key points.
$topicInstruction
Keep it conversational and insightful. Max length: 4 minutes (about 15-20 exchanges).

Content:
$context

IMPORTANT: Return ONLY a valid JSON array. No markdown, no code blocks, no intro text.
Format:
[
  {"speaker": "$host1", "text": "Welcome back to the Deep Dive! Today we're looking at..."},
  {"speaker": "$host2", "text": "That's right, $host1. It's a fascinating topic because..."}
]
''';
        final response = await _callAI(prompt);

        if (_shouldAbort) throw Exception('Cancelled');

        podcastSegments = _parsePodcastJson(response);

        if (podcastSegments.isEmpty) {
          throw Exception(
              'Failed to generate podcast script. AI returned invalid format.');
        }

        script = 'Podcast generated with ${podcastSegments.length} segments.';
        debugPrint(
            '[AudioOverview] Generated ${podcastSegments.length} podcast segments');
      } else {
        if (_shouldAbort) throw Exception('Cancelled');

        // Monologue prompt (legacy)
        final prompt = '''
Create a concise, engaging audio summary script for a podcast about the following content.
The script should be read by a single narrator.
Keep it conversational, insightful, and under 3 minutes reading time.
Do not include speaker labels or sound effects, just the spoken text.

Content:
$context
''';
        script = await _callAI(prompt);

        if (script.isEmpty) {
          throw Exception(
              'Failed to generate script. AI returned empty response.');
        }
      }

      // 2. Generate Audio with Preference & Fallback Strategy
      final elevenLabs = ref.read(elevenLabsServiceProvider);
      final googleTts = ref.read(googleCloudTtsServiceProvider);
      final murfTts = ref.read(murfServiceProvider);

      final prefs = await SharedPreferences.getInstance();
      final ttsProvider = prefs.getString('tts_provider') ?? 'elevenlabs';
      // Load user selected voices for podcast hosts
      final murfVoiceUser =
          prefs.getString('tts_murf_voice') ?? 'en-US-natalie';
      // Load secondary host voice (male counterpart for podcasts)
      final murfVoiceMale =
          prefs.getString('tts_murf_voice_male') ?? 'en-US-miles';

      Uint8List finalAudioBytes;

      if (isPodcast && podcastSegments.isNotEmpty) {
        _updateStatus('Recording Podcast...', 30);

        final builder = BytesBuilder();
        final totalSegments = podcastSegments.length;
        int successfulSegments = 0;

        // Use PCM format when Murf is primary (allows proper concatenation)
        final usePCM = ttsProvider == 'murf';

        // Voice IDs (ElevenLabs)
        const elVoiceSarah = 'EXAVITQu4vr4xnSDxMaL';
        const elVoiceAdam = 'pNInz6obpgDQGcFmaJgB';

        // Voice IDs (Murf) - Use user-configured voices
        final murfVoiceSarah = murfVoiceUser;
        final murfVoiceAdam = murfVoiceMale;

        // Voice IDs (Google Cloud)
        const gcVoiceSarah = 'en-US-Journey-F';
        const gcVoiceAdam = 'en-US-Journey-D';

        // Map configured hosts
        final host1Name = hosts.isNotEmpty ? hosts[0] : 'Sarah';
        final host2Name = hosts.length > 1 ? hosts[1] : 'Adam';

        for (int i = 0; i < totalSegments; i++) {
          // Check for cancellation before each segment
          if (_shouldAbort) {
            debugPrint(
                '[AudioOverview] Cancelled at segment ${i + 1}/$totalSegments');
            throw Exception('Cancelled');
          }

          final segment = podcastSegments[i];
          final speaker = segment['speaker'] ?? host1Name;
          final text = segment['text'] ?? '';

          if (text.isEmpty) continue;

          // Calculate progress
          final progress = 30 + ((i / totalSegments) * 60).toDouble();
          _updateStatus(
              'Recording ${i + 1}/$totalSegments ($speaker)...', progress);

          // Determine Voice Preference (Gender detection logic)
          bool useMaleVoice = false;
          if (speaker == host2Name) {
            useMaleVoice = true;
          } else if (speaker != host1Name) {
            final lower = speaker.toLowerCase();
            if (lower.contains('adam') ||
                lower.contains('mike') ||
                lower.contains('male') ||
                lower.contains('expert')) {
              useMaleVoice = true;
            }
          }

          // GENERATION FUNCTION HELPERS
          // Use PCM for Murf to allow proper concatenation
          Future<Uint8List> generateElevenLabs() async {
            final voiceId = useMaleVoice ? elVoiceAdam : elVoiceSarah;
            if (usePCM) {
              return await elevenLabs.textToSpeechPCM(text,
                  voiceId: voiceId, stability: 0.4, similarityBoost: 0.8);
            }
            return await elevenLabs.textToSpeech(text,
                voiceId: voiceId, stability: 0.4, similarityBoost: 0.8);
          }

          Future<Uint8List> generateMurf() async {
            final voiceId = useMaleVoice ? murfVoiceAdam : murfVoiceSarah;
            debugPrint(
                '[Podcast] Using Murf voice: $voiceId for $speaker (PCM: $usePCM)');
            if (usePCM) {
              return await murfTts.generateSpeechPCM(
                text,
                voiceId: voiceId,
                style: 'Conversational',
              );
            }
            return await murfTts.generateSpeech(
              text,
              voiceId: voiceId,
              style: 'Conversational',
            );
          }

          Future<Uint8List> generateGoogle() async {
            final voiceId = useMaleVoice ? gcVoiceAdam : gcVoiceSarah;
            return await googleTts.synthesize(text, voiceId: voiceId);
          }

          try {
            // PRIORITY: Use the retry helper with proper fallback order
            Future<Uint8List> Function() primaryGen;
            Future<Uint8List> Function() fallback1;
            Future<Uint8List> Function() fallback2;

            if (ttsProvider == 'murf') {
              primaryGen = generateMurf;
              fallback1 = generateElevenLabs;
              fallback2 = generateGoogle;
            } else if (ttsProvider == 'google_cloud') {
              primaryGen = generateGoogle;
              fallback1 = generateMurf;
              fallback2 = generateElevenLabs;
            } else {
              // Default to ElevenLabs
              primaryGen = generateElevenLabs;
              fallback1 = generateMurf;
              fallback2 = generateGoogle;
            }

            final chunk = await _generateTTSWithRetry(
              primaryGen: primaryGen,
              fallback1: fallback1,
              fallback2: fallback2,
              segmentInfo: 'Segment ${i + 1}/$totalSegments',
            );

            builder.add(chunk);
            successfulSegments++;
          } catch (e) {
            if (e.toString().contains('Cancelled')) rethrow;
            debugPrint(
                '[AudioOverview] Failed segment ${i + 1}: $e - skipping');
            // Continue with next segment instead of failing entire podcast
            continue;
          }
        }

        if (successfulSegments == 0) {
          throw Exception('All podcast segments failed to generate audio');
        }

        debugPrint(
            '[AudioOverview] Generated $successfulSegments/$totalSegments segments successfully');

        // If using PCM, wrap with WAV header to make it playable
        if (usePCM) {
          debugPrint('[AudioOverview] Wrapping PCM data with WAV header');
          finalAudioBytes =
              MurfService.wrapPCMWithWavHeader(builder.takeBytes());
        } else {
          finalAudioBytes = builder.takeBytes();
        }
      } else {
        // Monologue generation
        if (_shouldAbort) throw Exception('Cancelled');
        _updateStatus('Recording Summary...', 50);

        // Helper wrappers for monologue
        Future<Uint8List> genMonoEL() => elevenLabs.textToSpeech(script);
        Future<Uint8List> genMonoMurf() =>
            murfTts.generateSpeech(script, voiceId: murfVoiceUser);
        Future<Uint8List> genMonoGoogle() =>
            googleTts.synthesize(script, voiceId: 'en-US-Journey-F');

        // Determine fallback order based on user preference
        Future<Uint8List> Function() primaryGen;
        Future<Uint8List> Function() fallback1;
        Future<Uint8List> Function() fallback2;

        if (ttsProvider == 'murf') {
          primaryGen = genMonoMurf;
          fallback1 = genMonoEL;
          fallback2 = genMonoGoogle;
        } else if (ttsProvider == 'google_cloud') {
          primaryGen = genMonoGoogle;
          fallback1 = genMonoMurf;
          fallback2 = genMonoEL;
        } else {
          primaryGen = genMonoEL;
          fallback1 = genMonoMurf;
          fallback2 = genMonoGoogle;
        }

        finalAudioBytes = await _generateTTSWithRetry(
          primaryGen: primaryGen,
          fallback1: fallback1,
          fallback2: fallback2,
          segmentInfo: 'Monologue',
        );
      }

      // 3. Save to file
      _updateStatus('Finalizing Audio...', 95);
      final dir = await getApplicationDocumentsDirectory();
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      // Use .wav extension for PCM-based podcasts (Murf), .mp3 otherwise
      final extension = (isPodcast && ttsProvider == 'murf') ? 'wav' : 'mp3';
      final file = File('${dir.path}/audio_overview_$id.$extension');
      await file.writeAsBytes(finalAudioBytes);

      // 4. Create Overview object
      int wordCount = 0;
      if (isPodcast) {
        wordCount = podcastSegments.fold(
            0, (sum, seg) => sum + (seg['text']?.split(' ').length ?? 0));
      } else {
        wordCount = script.split(' ').length;
      }

      final duration = Duration(seconds: (wordCount / 2.5).round()); // ~150 wpm

      final overview = AudioOverview(
        id: id,
        title: title,
        url: file.path,
        duration: duration,
        createdAt: DateTime.now(),
      );

      // Add to list and clear generating state
      state = state.copyWith(
        overviews: [...state.overviews, overview],
        isGenerating: false,
        isCancelled: false,
        progressMessage: '',
        progressValue: 0,
      );

      // Save to backend
      await _saveOverview(overview);

      _updateStatus('Podcast Ready! 🎧', 100);
      await Future.delayed(const Duration(seconds: 1));
      await overlayBubbleService.hide();

      // Reset generating state cleanly
      state = state.copyWith(isGenerating: false, isCancelled: false);
    } catch (e) {
      final isCancelled = e.toString().contains('Cancelled');
      debugPrint('[AudioOverview] ${isCancelled ? "Cancelled" : "Error"}: $e');

      if (isCancelled) {
        overlayBubbleService.updateStatus('Generation cancelled');
      } else {
        // Show friendly error message
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        overlayBubbleService.updateStatus('Failed: $errorMsg');
      }

      await Future.delayed(Duration(seconds: isCancelled ? 1 : 3));
      await overlayBubbleService.hide();
      state = state.copyWith(isGenerating: false, isCancelled: false);
    } finally {
      await wakelockService.release();
    }
  }

  List<Map<String, String>> _parsePodcastJson(String response) {
    debugPrint(
        '[AudioOverview] Parsing podcast response (${response.length} chars)');

    // Pre-process: Remove markdown code blocks if present
    String cleaned = response;

    // Remove ```json ... ``` or ``` ... ``` wrappers
    final codeBlockRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final codeBlockMatch = codeBlockRegex.firstMatch(cleaned);
    if (codeBlockMatch != null) {
      cleaned = codeBlockMatch.group(1) ?? cleaned;
      debugPrint('[AudioOverview] Stripped code block wrapper');
    }

    // Remove common AI intro text before the JSON
    final jsonStartPatterns = [
      RegExp(r'^[^[]*\[', dotAll: true), // Everything before first [
    ];
    for (final pattern in jsonStartPatterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null && match.start < 100) {
        // Only if intro is short
        cleaned = cleaned.substring(match.end - 1);
        break;
      }
    }

    try {
      // 1. Try to find JSON array [ ... ]
      final start = cleaned.indexOf('[');
      final end = cleaned.lastIndexOf(']');

      if (start != -1 && end != -1 && end > start) {
        String jsonStr = cleaned.substring(start, end + 1);

        // Clean up common JSON issues
        // Fix trailing commas before ]
        jsonStr = jsonStr.replaceAll(RegExp(r',\s*\]'), ']');
        // Fix trailing commas before }
        jsonStr = jsonStr.replaceAll(RegExp(r',\s*\}'), '}');
        // Fix single quotes (some models use them)
        // Be careful not to break apostrophes in text

        final List<dynamic> data = jsonDecode(jsonStr);

        final segments = <Map<String, String>>[];
        for (final item in data) {
          if (item is Map) {
            final speaker = item['speaker']?.toString() ?? 'Host';
            final text = item['text']?.toString() ?? '';
            if (text.isNotEmpty) {
              segments.add({'speaker': speaker, 'text': text});
            }
          }
        }

        if (segments.isNotEmpty) {
          debugPrint(
              '[AudioOverview] Successfully parsed ${segments.length} segments from JSON');
          return segments;
        }
      }
    } catch (e) {
      debugPrint('[AudioOverview] JSON parsing failed: $e');
      debugPrint(
          '[AudioOverview] First 200 chars: ${cleaned.substring(0, cleaned.length < 200 ? cleaned.length : 200)}');
    }

    // 2. Fallback: Parse using Regex if JSON failed or wasn't found
    debugPrint('[AudioOverview] Falling back to Regex parsing...');
    return _parseScriptRegex(response);
  }

  List<Map<String, String>> _parseScriptRegex(String text) {
    final segments = <Map<String, String>>[];

    // Matches lines like:
    // **Sarah**: Hello world
    // Adam: That's interesting
    // Start of line, optional *, Name, optional *, :, text
    final regex =
        RegExp(r'^[\*\-\s]*([A-Za-z0-9 ]+?)[\*\s]*:(.+)$', multiLine: true);

    final matches = regex.allMatches(text);
    for (final match in matches) {
      final speaker = match.group(1)?.trim() ?? 'Host';
      final content = match.group(2)?.trim() ?? '';
      if (content.isNotEmpty) {
        segments.add({'speaker': speaker, 'text': content});
      }
    }

    if (segments.isEmpty) {
      // Last resort: Treat whole text as Sarah, but try to strip common "Here is..." prefixes
      debugPrint('[AudioOverview] Regex parsing failed. Using raw text.');
      var cleanText = text;
      // Strip "Here is the script:" type intros
      if (cleanText.length > 50 &&
          cleanText.substring(0, 50).toLowerCase().contains('json')) {
        cleanText = cleanText.substring(
            cleanText.indexOf('[')); // Try to salvage if it was partial
      }

      return [
        {'speaker': 'Sarah', 'text': cleanText}
      ];
    }

    return segments;
  }

  Future<void> toggleOffline(AudioOverview overview) async {
    final updatedList = state.overviews
        .map((a) =>
            a.id == overview.id ? a.copyWith(isOffline: !a.isOffline) : a)
        .toList();
    state = state.copyWith(overviews: updatedList);
  }
}

final audioOverviewProvider =
    StateNotifierProvider<AudioOverviewNotifier, AudioStudioState>(
        (ref) => AudioOverviewNotifier(ref));
