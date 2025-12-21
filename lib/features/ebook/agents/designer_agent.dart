import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/gemini_image_service.dart';
import '../../../core/security/global_credentials_service.dart';
import '../models/ebook_project.dart';
import '../models/ebook_chapter.dart';

class DesignerAgent {
  final Ref ref;

  DesignerAgent(this.ref);

  Future<GeminiImageService> _getImageService() async {
    final creds = ref.read(globalCredentialsServiceProvider);
    final apiKey = await creds.getApiKey('gemini');
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key not found');
    }
    return GeminiImageService(apiKey: apiKey);
  }

  Future<String> generateCoverArt(EbookProject project) async {
    final imageService = await _getImageService();

    final prompt = '''
Book cover design for a book titled "${project.title}".
Topic: ${project.topic}
Style: Professional, modern, minimalist, high quality, 4k.
Primary color: ${project.branding.primaryColorValue.toRadixString(16)}
''';

    return await imageService.generateImage(prompt);
  }

  Future<String> generateChapterIllustration(
      EbookChapter chapter, String style) async {
    final imageService = await _getImageService();

    // Safely get content preview
    final contentPreview = chapter.content.isEmpty
        ? chapter.title
        : chapter.content.substring(0, chapter.content.length.clamp(0, 100));

    final prompt = '''
Illustration for a book chapter titled "${chapter.title}".
Context: $contentPreview...
Style: $style, consistent, professional.
''';

    return await imageService.generateImage(prompt);
  }
}

final designerAgentProvider =
    Provider<DesignerAgent>((ref) => DesignerAgent(ref));
