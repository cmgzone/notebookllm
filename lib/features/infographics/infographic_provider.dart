import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uuid/uuid.dart';
import 'infographic.dart';
import '../sources/source_provider.dart';
import '../../core/api/api_service.dart';
import '../../core/ai/ai_settings_service.dart';
import '../../core/services/activity_logger_service.dart';

/// Provider for managing infographics
class InfographicNotifier extends StateNotifier<List<Infographic>> {
  final Ref ref;

  InfographicNotifier(this.ref) : super([]) {
    _loadInfographics();
  }

  Future<void> _loadInfographics() async {
    try {
      final api = ref.read(apiServiceProvider);
      final infoData = await api.getInfographics();
      state = infoData.map((j) => Infographic.fromBackendJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading infographics: $e');
      state = [];
    }
  }

  /// Get infographics for a specific source
  List<Infographic> getInfographicsForSource(String sourceId) {
    return state.where((info) => info.sourceId == sourceId).toList();
  }

  /// Get infographics for a specific notebook
  List<Infographic> getInfographicsForNotebook(String notebookId) {
    return state.where((info) => info.notebookId == notebookId).toList();
  }

  /// Add a new infographic
  Future<void> addInfographic(Infographic infographic) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.saveInfographic(
        title: infographic.title,
        notebookId: infographic.notebookId,
        sourceId: infographic.sourceId,
        imageUrl: infographic.imageUrl,
        imageBase64: infographic.imageBase64,
        style: infographic.style.name,
      );
      // Immediately add to state for instant UI update
      state = [infographic, ...state];
      // Then reload from backend to get server-generated IDs
      await _loadInfographics();
    } catch (e) {
      debugPrint('Error adding infographic: $e');
      rethrow; // Rethrow so the UI can show the error
    }
  }

  /// Delete an infographic
  Future<void> deleteInfographic(String id) async {
    // Current backend doesn't have deleteInfographic yet
    // state = state.where((info) => info.id != id).toList();
    await _loadInfographics();
  }

  /// Generate infographic description from source using AI
  /// This generates a description that can be used with an image generation API
  Future<String> generateInfographicPrompt({
    required String sourceId,
    InfographicStyle style = InfographicStyle.modern,
  }) async {
    // Get source
    final sources = ref.read(sourceProvider);
    final source = sources.firstWhere(
      (s) => s.id == sourceId,
      orElse: () => throw Exception('Source not found'),
    );

    final styleDescriptions = {
      InfographicStyle.modern:
          'Clean, modern design with gradients and rounded shapes',
      InfographicStyle.minimal:
          'Minimalist design with simple icons and lots of whitespace',
      InfographicStyle.colorful:
          'Vibrant, colorful design with bold graphics and contrasts',
      InfographicStyle.professional:
          'Corporate, professional design with charts and data visualization',
      InfographicStyle.playful:
          'Fun, playful design with illustrations and hand-drawn elements',
    };

    final prompt = '''
Create a detailed image generation prompt for an infographic.
The infographic should summarize the key concepts from the following content:

CONTENT:
${source.title}
${source.content}

STYLE: ${styleDescriptions[style]}

Generate a prompt suitable for DALL-E or similar image generation AI.
The prompt should describe:
1. Layout (vertical/horizontal sections)
2. Key data points or concepts to visualize
3. Icons and graphics to include
4. Color scheme
5. Typography style

Return ONLY the image generation prompt, no other text.
''';

    return await _callAI(prompt);
  }

  /// Create infographic with generated or provided image
  Future<Infographic> createInfographic({
    required String sourceId,
    required String notebookId,
    required String title,
    String? imageUrl,
    String? imageBase64,
    InfographicStyle style = InfographicStyle.modern,
  }) async {
    final infographic = Infographic(
      id: const Uuid().v4(),
      title: title,
      sourceId: sourceId,
      notebookId: notebookId,
      imageUrl: imageUrl,
      imageBase64: imageBase64,
      style: style,
      createdAt: DateTime.now(),
    );

    await addInfographic(infographic);

    // Log activity to social feed
    ref.read(activityLoggerProvider).logInfographicCreated(
          title,
          infographic.id,
        );

    return infographic;
  }

  Future<String> _callAI(String prompt) async {
    try {
      final settings = await AISettingsService.getSettings();
      final model = settings.model;

      if (model == null || model.isEmpty) {
        throw Exception(
            'No AI model selected. Please configure a model in settings.');
      }

      debugPrint(
          '[InfographicProvider] Using AI provider: ${settings.provider}, model: $model');

      // Use Backend Proxy (Admin's API keys)
      final apiService = ref.read(apiServiceProvider);
      final messages = [
        {'role': 'user', 'content': prompt}
      ];

      return await apiService.chatWithAI(
        messages: messages,
        provider: settings.provider,
        model: model,
      );
    } catch (e) {
      debugPrint('[InfographicProvider] AI call failed: $e');
      rethrow;
    }
  }
}

final infographicProvider =
    StateNotifierProvider<InfographicNotifier, List<Infographic>>((ref) {
  return InfographicNotifier(ref);
});
