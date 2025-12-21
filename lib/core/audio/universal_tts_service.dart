import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'elevenlabs_service.dart';
import 'google_tts_service.dart';

/// Universal Text-to-Speech Provider
final ttsServiceProvider = Provider<UniversalTTSService>((ref) {
  return UniversalTTSService(ref);
});

/// State for TTS playback
class TTSPlaybackState {
  final bool isPlaying;
  final bool isLoading;
  final String? error;
  final String? currentText;

  TTSPlaybackState({
    this.isPlaying = false,
    this.isLoading = false,
    this.error,
    this.currentText,
  });

  TTSPlaybackState copyWith({
    bool? isPlaying,
    bool? isLoading,
    String? error,
    String? currentText,
  }) {
    return TTSPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentText: currentText ?? this.currentText,
    );
  }
}

/// TTS Playback Notifier
class TTSPlaybackNotifier extends StateNotifier<TTSPlaybackState> {
  final UniversalTTSService _ttsService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Track if we are currently using Google/Device TTS which handles its own playback
  bool _usingDeviceTTS = false;

  TTSPlaybackNotifier(this._ttsService) : super(TTSPlaybackState()) {
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!_usingDeviceTTS) {
        state = state.copyWith(isPlaying: false);
      }
    });
  }

  Future<void> speak(String text, {TTSProvider? provider}) async {
    // Stop any current playback
    await stop();

    state = state.copyWith(isLoading: true, error: null, currentText: text);

    try {
      final selectedProvider =
          provider ?? await _ttsService._detectBestProvider();

      if (selectedProvider == TTSProvider.elevenLabs) {
        _usingDeviceTTS = false;
        final audioBytes =
            await _ttsService.generateAudio(text, provider: selectedProvider);
        await _audioPlayer.play(BytesSource(audioBytes));
        state = state.copyWith(isPlaying: true, isLoading: false);
      } else {
        // Google/Device TTS handles its own playback
        _usingDeviceTTS = true;
        // We need to hook into the completion of the device TTS
        // This is a bit tricky since GoogleTtsService doesn't expose a stream/callback easily here
        // For now, we'll set playing to true, and rely on the service to work
        await _ttsService.speakDirectly(text, provider: selectedProvider);
        state = state.copyWith(isPlaying: true, isLoading: false);

        // Note: In a perfect world, we'd listen to GoogleTtsService completion
        // For now, we assume it plays. The state might get out of sync if it finishes
        // without us knowing, but the user can press stop/play to reset.
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isPlaying: false,
      );
    }
  }

  Future<void> pause() async {
    if (_usingDeviceTTS) {
      await _ttsService.pauseDirectly();
    } else {
      await _audioPlayer.pause();
    }
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    if (_usingDeviceTTS) {
      // Device TTS often doesn't support resume well, so we might need to re-speak
      // But let's try to just set state for now, or re-speak if needed
      // GoogleTtsService has a pause but maybe not resume? It relies on flutter_tts which has pause/start
      // For simplicity, we might just re-speak if it was paused
      if (state.currentText != null) {
        await speak(state.currentText!, provider: TTSProvider.googleDevice);
      }
    } else {
      await _audioPlayer.resume();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<void> stop() async {
    if (_usingDeviceTTS) {
      await _ttsService.stopDirectly();
    } else {
      await _audioPlayer.stop();
    }
    state = state.copyWith(isPlaying: false, currentText: null);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

final ttsPlaybackProvider =
    StateNotifierProvider<TTSPlaybackNotifier, TTSPlaybackState>((ref) {
  final service = ref.read(ttsServiceProvider);
  return TTSPlaybackNotifier(service);
});

enum TTSProvider { elevenLabs, googleDevice }

/// Universal Text-to-Speech Service
class UniversalTTSService {
  final Ref ref;
  late final ElevenLabsService _elevenLabs;
  late final GoogleTtsService _googleTTS;

  UniversalTTSService(this.ref) {
    _elevenLabs = ref.read(elevenLabsServiceProvider);
    _googleTTS = ref.read(googleTtsServiceProvider);
  }

  /// Generate audio bytes (only for providers that support it, like ElevenLabs)
  Future<Uint8List> generateAudio(
    String text, {
    TTSProvider? provider,
    String? voiceId,
  }) async {
    provider ??= await _detectBestProvider();

    if (provider == TTSProvider.elevenLabs) {
      return await _elevenLabs.textToSpeech(
        text,
        voiceId: voiceId ?? 'EXAVITQu4vr4xnSDxMaL', // Default voice
      );
    }

    throw UnimplementedError('Audio generation not supported for $provider');
  }

  /// Speak directly using device TTS
  Future<void> speakDirectly(
    String text, {
    TTSProvider? provider,
  }) async {
    // Default to Google/Device TTS for direct speaking if not ElevenLabs
    await _googleTTS.speak(text);
  }

  Future<void> stopDirectly() async {
    await _googleTTS.stop();
  }

  Future<void> pauseDirectly() async {
    await _googleTTS.pause();
  }

  /// Detect the best available TTS provider
  Future<TTSProvider> _detectBestProvider() async {
    // Try ElevenLabs first (best quality)
    try {
      final elevenKey = await _elevenLabs.apiKey;
      if (elevenKey.isNotEmpty) {
        return TTSProvider.elevenLabs;
      }
    } catch (e) {
      // Continue to next provider
    }

    // Fallback to Google/Device TTS
    return TTSProvider.googleDevice;
  }

  /// Get available voices for a provider
  Future<List<Map<String, dynamic>>> getVoices(TTSProvider provider) async {
    switch (provider) {
      case TTSProvider.elevenLabs:
        return await _elevenLabs.getAvailableVoices();

      case TTSProvider.googleDevice:
        final voices = await _googleTTS.getAvailableVoices();
        return voices
            .map((v) => {'voice_id': v['name'], 'name': v['name']})
            .toList();
    }
  }
}

/// Interactive TTS Button Widget
class TTSButton extends ConsumerWidget {
  final String text;
  final IconData? icon;
  final String? tooltip;
  final Color? color;
  final TTSProvider? preferredProvider;
  final bool mini;

  const TTSButton({
    super.key,
    required this.text,
    this.icon,
    this.tooltip,
    this.color,
    this.preferredProvider,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsPlaybackProvider);
    final isCurrentText = ttsState.currentText == text;
    final isPlaying = isCurrentText && ttsState.isPlaying;
    final isLoading = isCurrentText && ttsState.isLoading;

    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    if (mini) {
      return IconButton(
        onPressed: isLoading
            ? null
            : () {
                if (isPlaying) {
                  ref.read(ttsPlaybackProvider.notifier).pause();
                } else if (isCurrentText && !isPlaying) {
                  ref.read(ttsPlaybackProvider.notifier).resume();
                } else {
                  ref.read(ttsPlaybackProvider.notifier).speak(
                        text,
                        provider: preferredProvider,
                      );
                }
              },
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(effectiveColor),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause : (icon ?? Icons.volume_up),
                color: color,
              ),
        tooltip: tooltip ?? (isPlaying ? 'Pause' : 'Listen'),
      );
    }

    return FloatingActionButton(
      onPressed: isLoading
          ? null
          : () {
              if (isPlaying) {
                ref.read(ttsPlaybackProvider.notifier).pause();
              } else if (isCurrentText && !isPlaying) {
                ref.read(ttsPlaybackProvider.notifier).resume();
              } else {
                ref.read(ttsPlaybackProvider.notifier).speak(
                      text,
                      provider: preferredProvider,
                    );
              }
            },
      tooltip: tooltip ?? (isPlaying ? 'Pause' : 'Listen'),
      backgroundColor: effectiveColor,
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Icon(
              isPlaying ? Icons.pause : (icon ?? Icons.volume_up),
              color: Colors.white,
            ),
    );
  }
}

/// TTS Inline Control Widget
class TTSInlineControl extends ConsumerWidget {
  final String text;
  final TTSProvider? preferredProvider;
  final Color? color;

  const TTSInlineControl({
    super.key,
    required this.text,
    this.preferredProvider,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsPlaybackProvider);
    final isCurrentText = ttsState.currentText == text;
    final isPlaying = isCurrentText && ttsState.isPlaying;
    final isLoading = isCurrentText && ttsState.isLoading;
    final effectiveColor = color ?? const Color(0xFF6C5CE7);

    return GestureDetector(
      onTap: () {
        if (isLoading) return;

        if (isPlaying) {
          ref.read(ttsPlaybackProvider.notifier).pause();
        } else if (isCurrentText && !isPlaying) {
          ref.read(ttsPlaybackProvider.notifier).resume();
        } else {
          ref.read(ttsPlaybackProvider.notifier).speak(
                text,
                provider: preferredProvider,
              );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: effectiveColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(effectiveColor),
                ),
              )
            else
              Icon(
                isPlaying ? Icons.pause : Icons.volume_up,
                size: 18,
                color: effectiveColor,
              ),
            const SizedBox(width: 8),
            Text(
              isPlaying ? 'Pause' : 'Listen',
              style: TextStyle(
                color: effectiveColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// TTS Error Display Widget
class TTSErrorWidget extends ConsumerWidget {
  const TTSErrorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsPlaybackProvider);

    if (ttsState.error == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TTS Error',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ttsState.error!,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(ttsPlaybackProvider.notifier).stop();
            },
          ),
        ],
      ),
    );
  }
}

/// TTS Floating Control (like music player)
class TTSFloatingControl extends ConsumerWidget {
  const TTSFloatingControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsPlaybackProvider);

    if (ttsState.currentText == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A1F3A),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                const Color(0xFF1A1F3A),
              ],
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_stories,
                color: Color(0xFF6C5CE7),
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Now Playing',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ttsState.currentText!.length > 50
                          ? '${ttsState.currentText!.substring(0, 50)}...'
                          : ttsState.currentText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  if (ttsState.isPlaying) {
                    ref.read(ttsPlaybackProvider.notifier).pause();
                  } else {
                    ref.read(ttsPlaybackProvider.notifier).resume();
                  }
                },
                icon: Icon(
                  ttsState.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(ttsPlaybackProvider.notifier).stop();
                },
                icon: const Icon(
                  Icons.stop,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
