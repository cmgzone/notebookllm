import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_service.dart';
import '../../core/audio/voice_service.dart';
import '../../core/services/background_ai_service.dart';
import '../../core/security/global_credentials_service.dart';
import 'gitu_settings_model.dart';

final gituSettingsProvider =
    StateNotifierProvider<GituSettingsNotifier, AsyncValue<GituSettings>>(
  (ref) => GituSettingsNotifier(ref),
);

class GituSettingsNotifier extends StateNotifier<AsyncValue<GituSettings>> {
  final Ref _ref;

  GituSettingsNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      state = const AsyncValue.loading();
      final apiService = _ref.read(apiServiceProvider);
      final response = await apiService.get<Map<String, dynamic>>('/gitu/settings');
      
      final settings = GituSettings.fromJson(response);
      state = AsyncValue.data(settings);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateSettings(GituSettings newSettings) async {
    final previous = state;
    state = AsyncValue.data(newSettings);
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.post('/gitu/settings', newSettings.toJson());
    } catch (_) {
      state = previous;
    }
  }
  
  Future<void> toggleEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    
    await updateSettings(current.copyWith(enabled: enabled));
  }
  
  Future<void> updateModelPreferences(ModelPreferences prefs) async {
    final current = state.value;
    if (current == null) return;
    
    await updateSettings(current.copyWith(modelPreferences: prefs));
  }

  Future<void> updateVoiceSettings(VoiceSettings voice) async {
    final current = state.value;
    if (current == null) return;

    await updateSettings(current.copyWith(voice: voice));

    try {
      final prefs = await SharedPreferences.getInstance();
      final voiceService = _ref.read(voiceServiceProvider);

      switch (voice.provider) {
        case 'google_cloud':
          await voiceService.setTtsProvider(TtsProvider.googleCloud);
          await prefs.setString('google_cloud_tts_voice', voice.voiceId);
          break;
        case 'google':
          await voiceService.setTtsProvider(TtsProvider.google);
          await prefs.setString('google_tts_voice', voice.voiceId);
          break;
        case 'elevenlabs':
          await voiceService.setTtsProvider(TtsProvider.elevenlabs);
          await prefs.setString('tts_voice', voice.voiceId);
          break;
        case 'murf':
        default:
          await voiceService.setTtsProvider(TtsProvider.murf);
          await prefs.setString('tts_murf_voice', voice.voiceId);
          break;
      }
    } catch (_) {
      // Ignore local voice update failures
    }
  }

  Future<void> updateProactiveSettings(ProactiveSettings proactive) async {
    final current = state.value;
    if (current == null) return;

    await updateSettings(current.copyWith(proactive: proactive));
  }

  Future<void> updateAnalyticsSettings(AnalyticsSettings analytics) async {
    final current = state.value;
    if (current == null) return;

    await updateSettings(current.copyWith(analytics: analytics));
  }

  Future<void> updateWakeWord({
    required bool enabled,
    required bool alwaysListening,
    required String phrase,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updatedVoice = current.voice.copyWith(
      wakeWordEnabled: enabled,
      alwaysListening: alwaysListening,
      wakeWordPhrase: phrase,
    );
    await updateSettings(current.copyWith(voice: updatedVoice));

    if (enabled && alwaysListening) {
      String? deepgramKey;
      try {
        final creds = _ref.read(globalCredentialsServiceProvider);
        deepgramKey = await creds.getApiKey('deepgram');
      } catch (_) {
        deepgramKey = null;
      }

      await backgroundAIService.startWakeWordListener(
        phrase: phrase,
        alwaysListening: true,
        deepgramApiKey: deepgramKey,
      );
    } else {
      await backgroundAIService.stopWakeWordListener();
    }
  }
}
