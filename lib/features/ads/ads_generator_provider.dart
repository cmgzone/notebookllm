import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/ai/gemini_image_service.dart';
import '../../core/ai/ai_settings_service.dart';
import '../../core/api/api_service.dart';

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
      final settings = await AISettingsService.getSettings();
      final provider = settings.provider;
      final model = settings.model;

      if (model == null || model.isEmpty) {
        throw Exception(
            'No AI model selected. Please configure a model in settings.');
      }

      String content;

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
        // Multimodal generation (with image) - uses client side for now
        final imageService = GeminiImageService();
        content = await imageService.analyzeImage(
          state.selectedImageBytes!,
          fullPrompt,
          model: model,
        );
      } else {
        // Text-only generation - Use Backend Proxy (Admin's API keys)
        final apiService = ref.read(apiServiceProvider);
        final messages = [
          {'role': 'user', 'content': fullPrompt}
        ];

        content = await apiService.chatWithAI(
          messages: messages,
          provider: provider,
          model: model,
        );
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
