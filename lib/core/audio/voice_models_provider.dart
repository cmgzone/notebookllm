import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';

/// Voice model from backend
class VoiceModel {
  final String id;
  final String name;
  final String voiceId;
  final String provider;
  final String gender;
  final String language;
  final String? description;
  final bool isActive;
  final bool isPremium;

  VoiceModel({
    required this.id,
    required this.name,
    required this.voiceId,
    required this.provider,
    this.gender = 'neutral',
    this.language = 'en-US',
    this.description,
    this.isActive = true,
    this.isPremium = false,
  });

  factory VoiceModel.fromMap(Map<String, dynamic> map) {
    return VoiceModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      voiceId: map['voice_id'] ?? '',
      provider: map['provider'] ?? '',
      gender: map['gender'] ?? 'neutral',
      language: map['language'] ?? 'en-US',
      description: map['description'],
      isActive: map['is_active'] ?? true,
      isPremium: map['is_premium'] ?? false,
    );
  }
}

/// Provider for all available voice models from backend
final availableVoiceModelsProvider =
    FutureProvider<Map<String, List<VoiceModel>>>((ref) async {
  try {
    final api = ref.read(apiServiceProvider);
    final voices = await api.getVoiceModels();

    final Map<String, List<VoiceModel>> grouped = {};

    for (final v in voices) {
      final model = VoiceModel.fromMap(v);
      if (!model.isActive) continue;

      grouped.putIfAbsent(model.provider, () => []);
      grouped[model.provider]!.add(model);
    }

    return grouped;
  } catch (e) {
    debugPrint('Failed to load voice models from backend: $e');
    // Return fallback static voices
    return _getFallbackVoices();
  }
});

/// Provider for voices by specific provider
final voicesByProviderProvider =
    FutureProvider.family<List<VoiceModel>, String>((ref, provider) async {
  try {
    final api = ref.read(apiServiceProvider);
    final voices = await api.getVoiceModelsByProvider(provider);
    return voices.map((v) => VoiceModel.fromMap(v)).toList();
  } catch (e) {
    debugPrint('Failed to load $provider voices: $e');
    final fallback = _getFallbackVoices();
    return fallback[provider] ?? [];
  }
});

/// Fallback static voices if backend is unavailable
Map<String, List<VoiceModel>> _getFallbackVoices() {
  return {
    'elevenlabs': [
      VoiceModel(
          id: '1',
          name: 'Sarah',
          voiceId: 'EXAVITQu4vr4xnSDxMaL',
          provider: 'elevenlabs',
          gender: 'female'),
      VoiceModel(
          id: '2',
          name: 'Rachel',
          voiceId: '21m00Tcm4TlvDq8ikWAM',
          provider: 'elevenlabs',
          gender: 'female'),
      VoiceModel(
          id: '3',
          name: 'Antoni',
          voiceId: 'ErXwobaYiN019PkySvjV',
          provider: 'elevenlabs',
          gender: 'male'),
      VoiceModel(
          id: '4',
          name: 'Adam',
          voiceId: 'pNInz6obpgDQGcFmaJgB',
          provider: 'elevenlabs',
          gender: 'male'),
    ],
    'google': [
      VoiceModel(
          id: '5',
          name: 'Standard Female',
          voiceId: 'en-US-Standard-A',
          provider: 'google',
          gender: 'female'),
      VoiceModel(
          id: '6',
          name: 'Standard Male',
          voiceId: 'en-US-Standard-B',
          provider: 'google',
          gender: 'male'),
    ],
    'google_cloud': [
      VoiceModel(
          id: '7',
          name: 'Journey Female',
          voiceId: 'en-US-Journey-F',
          provider: 'google_cloud',
          gender: 'female'),
      VoiceModel(
          id: '8',
          name: 'Journey Male',
          voiceId: 'en-US-Journey-D',
          provider: 'google_cloud',
          gender: 'male'),
    ],
    'murf': [
      VoiceModel(
          id: '9',
          name: 'Natalie',
          voiceId: 'en-US-natalie',
          provider: 'murf',
          gender: 'female'),
      VoiceModel(
          id: '10',
          name: 'Miles',
          voiceId: 'en-US-miles',
          provider: 'murf',
          gender: 'male'),
    ],
  };
}
