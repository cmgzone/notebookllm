import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/admin/services/ai_model_service.dart';
import 'gemini_config.dart';
import 'openrouter_service.dart';

final availableModelsProvider =
    FutureProvider<Map<String, List<AIModelOption>>>((ref) async {
  // Get base models
  final baseGemini = GeminiConfig.availableModels.entries
      .map((e) => AIModelOption(
            id: e.key,
            name: e.value,
            provider: 'gemini',
            isPremium: false,
          ))
      .toList();

  final baseOpenRouter = OpenRouterService.allModels.entries
      .map((e) => AIModelOption(
            id: e.key,
            name: e.value.replaceAll(' (Paid)', '').replaceAll(' (Free)', ''),
            provider: 'openrouter',
            isPremium: e.value.contains('(Paid)'),
          ))
      .toList();

  // Get dynamic models from DB (if table exists)
  try {
    final service = ref.read(aiModelServiceProvider);
    // ensureTableExists is lightweight
    await service.ensureTableExists();
    final dbModels = await service.listModels();

    for (final m in dbModels) {
      if (!m.isActive) continue;

      final option = AIModelOption(
        id: m.modelId,
        name: m.name,
        provider: m.provider,
        isPremium: m.isPremium,
      );

      if (m.provider == 'gemini') {
        baseGemini.add(option);
      } else if (m.provider == 'openrouter') {
        baseOpenRouter.add(option);
      } else {
        // Handle custom providers or map to existing ones
        // For now, treat others as OpenRouter-compatible or separate?
        if (m.provider == 'openai' || m.provider == 'anthropic') {
          baseOpenRouter.add(option);
        }
      }
    }
  } catch (e) {
    // Fallback to static lists if DB fails
    debugPrint('Failed to load dynamic AI models: $e');
  }

  return {
    'gemini': baseGemini,
    'openrouter': baseOpenRouter,
  };
});

class AIModelOption {
  final String id;
  final String name;
  final String provider;
  final bool isPremium;

  AIModelOption({
    required this.id,
    required this.name,
    required this.provider,
    required this.isPremium,
  });
}
