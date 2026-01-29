
class GituSettings {
  final bool enabled;
  final ModelPreferences modelPreferences;

  const GituSettings({
    required this.enabled,
    required this.modelPreferences,
  });

  factory GituSettings.fromJson(Map<String, dynamic> json) {
    return GituSettings(
      enabled: json['enabled'] as bool? ?? false,
      modelPreferences: ModelPreferences.fromJson(
          json['settings']?['modelPreferences'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'settings': {
        'modelPreferences': modelPreferences.toJson(),
      },
    };
  }

  GituSettings copyWith({
    bool? enabled,
    ModelPreferences? modelPreferences,
  }) {
    return GituSettings(
      enabled: enabled ?? this.enabled,
      modelPreferences: modelPreferences ?? this.modelPreferences,
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
