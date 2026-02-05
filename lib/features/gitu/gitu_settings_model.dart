
class GituSettings {
  final bool enabled;
  final ModelPreferences modelPreferences;
  final VoiceSettings voice;
  final ProactiveSettings proactive;
  final AnalyticsSettings analytics;

  const GituSettings({
    required this.enabled,
    required this.modelPreferences,
    required this.voice,
    required this.proactive,
    required this.analytics,
  });

  factory GituSettings.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] as Map<String, dynamic>? ?? {};
    return GituSettings(
      enabled: json['enabled'] as bool? ?? false,
      modelPreferences: ModelPreferences.fromJson(
          settings['modelPreferences'] ?? {}),
      voice: VoiceSettings.fromJson(settings['voice'] ?? const {}),
      proactive: ProactiveSettings.fromJson(settings['proactive'] ?? const {}),
      analytics: AnalyticsSettings.fromJson(settings['analytics'] ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'settings': {
        'modelPreferences': modelPreferences.toJson(),
        'voice': voice.toJson(),
        'proactive': proactive.toJson(),
        'analytics': analytics.toJson(),
      },
    };
  }

  GituSettings copyWith({
    bool? enabled,
    ModelPreferences? modelPreferences,
    VoiceSettings? voice,
    ProactiveSettings? proactive,
    AnalyticsSettings? analytics,
  }) {
    return GituSettings(
      enabled: enabled ?? this.enabled,
      modelPreferences: modelPreferences ?? this.modelPreferences,
      voice: voice ?? this.voice,
      proactive: proactive ?? this.proactive,
      analytics: analytics ?? this.analytics,
    );
  }
}

class VoiceSettings {
  final String provider;
  final String voiceId;
  final bool wakeWordEnabled;
  final String wakeWordPhrase;
  final bool alwaysListening;

  const VoiceSettings({
    this.provider = 'murf',
    this.voiceId = 'en-US-natalie',
    this.wakeWordEnabled = false,
    this.wakeWordPhrase = 'hey gitu',
    this.alwaysListening = false,
  });

  factory VoiceSettings.fromJson(Map<String, dynamic> json) {
    return VoiceSettings(
      provider: json['provider'] as String? ?? 'murf',
      voiceId: json['voiceId'] as String? ?? 'en-US-natalie',
      wakeWordEnabled: json['wakeWordEnabled'] as bool? ?? false,
      wakeWordPhrase: json['wakeWordPhrase'] as String? ?? 'hey gitu',
      alwaysListening: json['alwaysListening'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'voiceId': voiceId,
      'wakeWordEnabled': wakeWordEnabled,
      'wakeWordPhrase': wakeWordPhrase,
      'alwaysListening': alwaysListening,
    };
  }

  VoiceSettings copyWith({
    String? provider,
    String? voiceId,
    bool? wakeWordEnabled,
    String? wakeWordPhrase,
    bool? alwaysListening,
  }) {
    return VoiceSettings(
      provider: provider ?? this.provider,
      voiceId: voiceId ?? this.voiceId,
      wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
      wakeWordPhrase: wakeWordPhrase ?? this.wakeWordPhrase,
      alwaysListening: alwaysListening ?? this.alwaysListening,
    );
  }
}

class ProactiveSettings {
  final bool enabled;
  final bool highPriorityOnly;

  const ProactiveSettings({
    this.enabled = true,
    this.highPriorityOnly = false,
  });

  factory ProactiveSettings.fromJson(Map<String, dynamic> json) {
    return ProactiveSettings(
      enabled: json['enabled'] as bool? ?? true,
      highPriorityOnly: json['highPriorityOnly'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'highPriorityOnly': highPriorityOnly,
    };
  }

  ProactiveSettings copyWith({
    bool? enabled,
    bool? highPriorityOnly,
  }) {
    return ProactiveSettings(
      enabled: enabled ?? this.enabled,
      highPriorityOnly: highPriorityOnly ?? this.highPriorityOnly,
    );
  }
}

class AnalyticsSettings {
  final bool enabled;

  const AnalyticsSettings({
    this.enabled = true,
  });

  factory AnalyticsSettings.fromJson(Map<String, dynamic> json) {
    return AnalyticsSettings(
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
    };
  }

  AnalyticsSettings copyWith({
    bool? enabled,
  }) {
    return AnalyticsSettings(
      enabled: enabled ?? this.enabled,
    );
  }
}

class ModelPreferences {
  final String defaultModel;
  final Map<String, String> taskSpecificModels;
  final String apiKeySource; // 'platform' or 'personal'
  final Map<String, String> personalKeys;

  const ModelPreferences({
    this.defaultModel = 'gemini-2.0-flash',
    this.taskSpecificModels = const {},
    this.apiKeySource = 'platform',
    this.personalKeys = const {},
  });

  factory ModelPreferences.fromJson(Map<String, dynamic> json) {
    return ModelPreferences(
      defaultModel: json['defaultModel'] as String? ?? 'gemini-2.0-flash',
      taskSpecificModels: Map<String, String>.from(json['taskSpecificModels'] ?? {}),
      apiKeySource: json['apiKeySource'] as String? ?? 'platform',
      personalKeys: Map<String, String>.from(json['personalKeys'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultModel': defaultModel,
      'taskSpecificModels': taskSpecificModels,
      'apiKeySource': apiKeySource,
      'personalKeys': personalKeys,
    };
  }

  ModelPreferences copyWith({
    String? defaultModel,
    Map<String, String>? taskSpecificModels,
    String? apiKeySource,
    Map<String, String>? personalKeys,
  }) {
    return ModelPreferences(
      defaultModel: defaultModel ?? this.defaultModel,
      taskSpecificModels: taskSpecificModels ?? this.taskSpecificModels,
      apiKeySource: apiKeySource ?? this.apiKeySource,
      personalKeys: personalKeys ?? this.personalKeys,
    );
  }
}
