import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceState {
  final String? voiceId;
  VoiceState({this.voiceId});
  VoiceState copyWith({String? voiceId}) => VoiceState(voiceId: voiceId ?? this.voiceId);
}

class VoiceNotifier extends StateNotifier<VoiceState> {
  VoiceNotifier() : super(VoiceState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('voice_id');
    state = state.copyWith(voiceId: id);
  }

  Future<void> setVoice(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_id', id);
    state = state.copyWith(voiceId: id);
  }
}

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>((ref) => VoiceNotifier());