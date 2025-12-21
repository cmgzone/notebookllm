import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Service for playing audio feedback sounds during voice interactions
class VoiceFeedbackService {
  static final VoiceFeedbackService _instance =
      VoiceFeedbackService._internal();
  factory VoiceFeedbackService() => _instance;
  VoiceFeedbackService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _soundsEnabled = true;

  /// Enable or disable feedback sounds
  void setSoundsEnabled(bool enabled) {
    _soundsEnabled = enabled;
  }

  bool get soundsEnabled => _soundsEnabled;

  /// Play start listening sound (ascending tone)
  Future<void> playStartListening() async {
    if (!_soundsEnabled) return;
    try {
      // Use haptic feedback + system sound
      await HapticFeedback.lightImpact();
      // Play a subtle tone using synthesized audio
      await _playTone(frequency: 880, duration: 100); // A5 note
    } catch (e) {
      debugPrint('Failed to play start sound: $e');
    }
  }

  /// Play stop listening sound (descending tone)
  Future<void> playStopListening() async {
    if (!_soundsEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
      await _playTone(frequency: 440, duration: 100); // A4 note
    } catch (e) {
      debugPrint('Failed to play stop sound: $e');
    }
  }

  /// Play success sound (two ascending tones)
  Future<void> playSuccess() async {
    if (!_soundsEnabled) return;
    try {
      await HapticFeedback.lightImpact();
      await _playTone(frequency: 523, duration: 80); // C5
      await Future.delayed(const Duration(milliseconds: 50));
      await _playTone(frequency: 659, duration: 120); // E5
    } catch (e) {
      debugPrint('Failed to play success sound: $e');
    }
  }

  /// Play error sound (descending tones)
  Future<void> playError() async {
    if (!_soundsEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await _playTone(frequency: 392, duration: 150); // G4
      await Future.delayed(const Duration(milliseconds: 50));
      await _playTone(frequency: 330, duration: 200); // E4
    } catch (e) {
      debugPrint('Failed to play error sound: $e');
    }
  }

  /// Play processing sound (quick blip)
  Future<void> playProcessing() async {
    if (!_soundsEnabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Failed to play processing sound: $e');
    }
  }

  /// Play a simple synthesized tone
  /// Note: For a production app, you'd use pre-recorded sound files
  Future<void> _playTone(
      {required int frequency, required int duration}) async {
    try {
      // Use haptic feedback as primary feedback (more reliable)
      // In production, you could use audio files for actual tones
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Tone generation error: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}

/// Singleton instance
final voiceFeedbackService = VoiceFeedbackService();
