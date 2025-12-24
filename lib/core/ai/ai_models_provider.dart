import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/admin/services/ai_model_service.dart';
import 'gemini_config.dart';
import 'openrouter_service.dart';

final availableModelsProvider =
    FutureProvider<Map<String, List<AIModelOption>>>((ref) async {
  // Get base models with default context windows
  final baseGemini = GeminiConfig.availableModels.entries
      .map((e) => AIModelOption(
            id: e.key,
            name: e.value,
            provider: 'gemini',
            isPremium: false,
            contextWindow: _getDefaultContextWindow(e.key),
          ))
      .toList();

  final baseOpenRouter = OpenRouterService.allModels.entries
      .map((e) => AIModelOption(
            id: e.key,
            name: e.value.replaceAll(' (Paid)', '').replaceAll(' (Free)', ''),
            provider: 'openrouter',
            isPremium: e.value.contains('(Paid)'),
            contextWindow: _getDefaultContextWindow(e.key),
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
        contextWindow: m.contextWindow > 0
            ? m.contextWindow
            : _getDefaultContextWindow(m.modelId),
      );

      if (m.provider == 'gemini') {
        // Replace if exists, otherwise add
        final existingIndex = baseGemini.indexWhere((o) => o.id == m.modelId);
        if (existingIndex >= 0) {
          baseGemini[existingIndex] = option;
        } else {
          baseGemini.add(option);
        }
      } else if (m.provider == 'openrouter') {
        final existingIndex =
            baseOpenRouter.indexWhere((o) => o.id == m.modelId);
        if (existingIndex >= 0) {
          baseOpenRouter[existingIndex] = option;
        } else {
          baseOpenRouter.add(option);
        }
      } else {
        // Handle custom providers or map to existing ones
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

/// Get default context window for known models
int _getDefaultContextWindow(String modelId) {
  // Gemini models
  if (modelId.contains('gemini-2.0') || modelId.contains('gemini-2.5')) {
    return 1000000; // 1M tokens
  }
  if (modelId.contains('gemini-1.5-pro')) {
    return 2000000; // 2M tokens
  }
  if (modelId.contains('gemini-1.5-flash')) {
    return 1000000; // 1M tokens
  }

  // OpenRouter / Claude models
  if (modelId.contains('claude-3')) {
    return 200000; // 200K tokens
  }
  if (modelId.contains('gpt-4')) {
    return 128000; // 128K tokens
  }
  if (modelId.contains('nova')) {
    return 300000; // 300K tokens
  }

  // Default fallback
  return 8192;
}

class AIModelOption {
  final String id;
  final String name;
  final String provider;
  final bool isPremium;
  final int contextWindow;

  AIModelOption({
    required this.id,
    required this.name,
    required this.provider,
    required this.isPremium,
    this.contextWindow = 8192,
  });
}
