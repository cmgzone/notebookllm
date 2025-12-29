import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/admin/services/ai_model_service.dart';

/// Centralized AI settings service - no hardcoded models
/// All model defaults come from user settings or are fetched dynamically
class AISettingsService {
  static const String _providerKey = 'ai_provider';
  static const String _modelKey = 'ai_model';

  /// Get the user's selected AI provider
  static Future<String> getProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_providerKey) ?? 'gemini';
  }

  /// Get the user's selected AI model
  static Future<String?> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelKey);
  }

  /// Get the actual provider for a specific model by looking it up in the database
  /// This ensures custom models added via admin panel use the correct service
  static Future<String> getProviderForModel(String modelId, Ref ref) async {
    try {
      final service = ref.read(aiModelServiceProvider);
      final models = await service.listModels();

      // Find the model in the database
      final model = models.where((m) => m.modelId == modelId).firstOrNull;

      if (model != null) {
        // Map the provider field to the correct service
        // openai, anthropic, and openrouter all use OpenRouterService
        if (model.provider == 'openrouter' ||
            model.provider == 'openai' ||
            model.provider == 'anthropic') {
          return 'openrouter';
        }
        return model.provider; // 'gemini' or other
      }
    } catch (e) {
      // If lookup fails, fall back to SharedPreferences
    }

    // Fallback to SharedPreferences if model not found
    return await getProvider();
  }

  /// Get provider and model together
  static Future<AISettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AISettings(
      provider: prefs.getString(_providerKey) ?? 'gemini',
      model: prefs.getString(_modelKey),
    );
  }

  /// Get settings with provider auto-detected from the model
  static Future<AISettings> getSettingsWithProviderDetection(Ref ref) async {
    final prefs = await SharedPreferences.getInstance();
    final modelId = prefs.getString(_modelKey);

    String provider;
    if (modelId != null && modelId.isNotEmpty) {
      // Auto-detect provider from model
      provider = await getProviderForModel(modelId, ref);
    } else {
      // No model selected, use saved provider
      provider = prefs.getString(_providerKey) ?? 'gemini';
    }

    return AISettings(
      provider: provider,
      model: modelId,
    );
  }

  /// Save AI provider
  static Future<void> setProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, provider);
  }

  /// Save AI model
  static Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, model);
  }

  /// Check if a model supports vision (image input)
  static bool isVisionCapable(String modelId) {
    final lower = modelId.toLowerCase();
    return lower.contains('gemini') ||
        lower.contains('gpt-4') ||
        lower.contains('claude') ||
        lower.contains('vision');
  }

  /// Get a vision-capable model fallback if current model doesn't support it
  static String getVisionModel(String currentModel, String provider) {
    if (isVisionCapable(currentModel)) {
      return currentModel;
    }
    // No hardcoded fallbacks - return current and let service/API handle error
    return currentModel;
  }
}

/// Provider for AI settings
final aiSettingsProvider = FutureProvider<AISettings>((ref) async {
  final settings = await AISettingsService.getSettings();
  return AISettings(
    provider: settings.provider,
    model: settings.model,
  );
});

/// Selected AI model state provider (for UI)
final selectedAIModelIdProvider = StateProvider<String?>((ref) => null);

/// Selected AI provider state provider (for UI)
final selectedAIProviderProvider = StateProvider<String>((ref) => 'gemini');

class AISettings {
  final String provider;
  final String? model;

  AISettings({required this.provider, this.model});

  /// Get the effective model (with fallback if none set)
  String getEffectiveModel({String? fallback}) {
    if (model != null && model!.isNotEmpty) {
      return model!;
    }
    if (fallback != null) {
      return fallback;
    }
    // No hardcoded fallback - user must select a model
    throw Exception(
        'No AI model selected. Please configure a model in settings.');
  }
}
