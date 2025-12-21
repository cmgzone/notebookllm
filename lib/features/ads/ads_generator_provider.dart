import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/ai/gemini_service.dart';
import '../../core/ai/gemini_image_service.dart';
import '../../core/ai/openrouter_service.dart';
import '../../core/security/global_credentials_service.dart';

class AdsGeneratorState {
  final bool isGenerating;
  final String? generatedAd;
  final String? error;
  final Uint8List? selectedImageBytes;
  final String? selectedImageName;

  const AdsGeneratorState({
    this.isGenerating = false,
    this.generatedAd,
    this.error,
    this.selectedImageBytes,
    this.selectedImageName,
  });

  AdsGeneratorState copyWith({
    bool? isGenerating,
    String? generatedAd,
    String? error,
    Uint8List? selectedImageBytes,
    String? selectedImageName,
  }) {
    return AdsGeneratorState(
      isGenerating: isGenerating ?? this.isGenerating,
      generatedAd: generatedAd ?? this.generatedAd,
      error: error,
      selectedImageBytes: selectedImageBytes ?? this.selectedImageBytes,
      selectedImageName: selectedImageName ?? this.selectedImageName,
    );
  }
}

class AdsGeneratorNotifier extends StateNotifier<AdsGeneratorState> {
  final Ref ref;

  AdsGeneratorNotifier(this.ref) : super(const AdsGeneratorState());

  Future<void> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        state = state.copyWith(
          selectedImageBytes: file.bytes,
          selectedImageName: file.name,
          error: null,
        );
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick image: $e');
    }
  }

  void clearImage() {
    state = AdsGeneratorState(
      isGenerating: state.isGenerating,
      generatedAd: state.generatedAd,
      error: state.error,
      selectedImageBytes: null,
      selectedImageName: null,
    );
  }

  Future<void> generateAd(String prompt) async {
    if (prompt.trim().isEmpty && state.selectedImageBytes == null) {
      state = state.copyWith(error: 'Please enter a prompt or select an image');
      return;
    }

    state = state.copyWith(isGenerating: true, error: null, generatedAd: null);

    try {
      final prefs = await SharedPreferences.getInstance();
      final provider = prefs.getString('ai_provider') ?? 'gemini';
      final model = prefs.getString('ai_model') ?? 'gemini-2.5-flash';
      final creds = ref.read(globalCredentialsServiceProvider);

      String content;

      if (provider == 'openrouter') {
        final apiKey = await creds.getApiKey('openrouter');
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception('OpenRouter API key not found');
        }

        final openRouterService = OpenRouterService(apiKey: apiKey);

        final fullPrompt = '''
You are an expert marketing copywriter. Create a compelling advertisement based on the user's requirements.

User Requirements:
$prompt

Please generate:
1. A Catchy Headline
2. Engaging Ad Body Copy (2-3 paragraphs)
3. Call to Action (CTA)
4. Suggested Hashtags
${state.selectedImageBytes != null ? '\nTarget Audience Analysis: Briefly analyze who this ad would appeal to based on the image.' : ''}
''';

        if (state.selectedImageBytes != null) {
          // Multimodal generation with OpenRouter
          // Use a vision-capable model if the selected model is free/default
          // or use the user's selected model if they know what they are doing.
          // For safety, we default to a known vision model if the default text model is selected.
          var visionModel = model;
          if (model.contains('amazon/nova')) {
            visionModel = 'google/gemini-2.0-flash-exp:free';
          }

          content = await openRouterService.generateWithImage(
            fullPrompt,
            state.selectedImageBytes!,
            model: visionModel,
          );
        } else {
          // Text-only generation with OpenRouter
          content = await openRouterService.generateContent(
            fullPrompt,
            model: model,
          );
        }
      } else {
        // Default to Gemini
        final apiKey = await creds.getApiKey('gemini');
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception('Gemini API key not found');
        }

        if (state.selectedImageBytes != null) {
          // Multimodal generation with Gemini
          final imageService = GeminiImageService(apiKey: apiKey);

          final fullPrompt = '''
You are an expert marketing copywriter. Create a compelling advertisement based on this image and the user's requirements.

User Requirements:
$prompt

Please generate:
1. A Catchy Headline
2. Engaging Ad Body Copy (2-3 paragraphs)
3. Call to Action (CTA)
4. Suggested Hashtags

Target Audience Analysis: Briefly analyze who this ad would appeal to based on the image/prompt.
''';

          content = await imageService.analyzeImage(
            state.selectedImageBytes!,
            fullPrompt,
          );
        } else {
          // Text-only generation with Gemini
          final geminiService = GeminiService(apiKey: apiKey);

          final fullPrompt = '''
You are an expert marketing copywriter. Create a compelling advertisement based on the user's requirements.

User Requirements:
$prompt

Please generate:
1. A Catchy Headline
2. Engaging Ad Body Copy (2-3 paragraphs)
3. Call to Action (CTA)
4. Suggested Hashtags
''';

          content = await geminiService.generateContent(fullPrompt);
        }
      }

      state = state.copyWith(
        isGenerating: false,
        generatedAd: content,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: 'Generation failed: $e',
      );
    }
  }
}

final adsGeneratorProvider =
    StateNotifierProvider<AdsGeneratorNotifier, AdsGeneratorState>((ref) {
  return AdsGeneratorNotifier(ref);
});
