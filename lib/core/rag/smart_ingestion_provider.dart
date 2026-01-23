import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'real_ingestion_service.dart';
import 'chunk.dart';
import '../../features/sources/source.dart';
import 'rag_provider.dart';

final useRealIngestionProvider =
    StateProvider<bool>((ref) => true); // Enable real ingestion by default

final ingestionProvider =
    FutureProvider.family<List<Chunk>, Source>((ref, source) async {
  final real = ref.watch(realIngestionProvider);

  try {
    // Use real embedding service (OpenAI or Gemini)
    final chunks = await real.chunkSource(source);
    ref.read(vectorStoreProvider).addChunks(chunks);
    return chunks;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Ingestion failed for source ${source.id}: $e');
    }
    // Fallback to mock ingestion if real ingestion fails
    final service = ref.read(ingestionServiceProvider);
    final chunks = service.chunkSource(source);
    ref.read(vectorStoreProvider).addChunks(chunks);
    return chunks;
  }
});
