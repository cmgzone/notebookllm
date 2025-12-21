import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/global_credentials_service.dart';
import '../models/ebook_project.dart';

class EbookAudiobookService {
  final Ref ref;

  EbookAudiobookService(this.ref);

  Future<List<String>> generateAudiobook(EbookProject project) async {
    final creds = ref.read(globalCredentialsServiceProvider);
    final apiKey = await creds.getApiKey('elevenlabs');
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('ElevenLabs API key not found');
    }

    // Stub implementation - TTS will be implemented in future iteration
    // For now, return empty list as audiobook generation is a planned feature
    List<String> audioUrls = [];

    for (var _ in project.chapters) {
      audioUrls.add(''); // Placeholder
    }

    return audioUrls;
  }
}

final ebookAudiobookServiceProvider =
    Provider<EbookAudiobookService>((ref) => EbookAudiobookService(ref));
