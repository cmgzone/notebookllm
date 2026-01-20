import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'real_ingestion_service.dart';
import 'chunk.dart';
import '../../features/sources/source_provider.dart';
import 'rag_provider.dart';

final useRealIngestionProvider =
    StateProvider<bool>((ref) => true); // Enable real ingestion by default

final ingestionProvider =
    FutureProvider.family<List<Chunk>, String>((ref, sourceId) async {
  final sources = ref.watch(sourceProvider);
  final source = sources.firstWhere((s) => s.id == sourceId);
  final real = ref.watch(realIngestionProvider);

  try {
    // Use real embedding service (OpenAI or Gemini)
    final chunks = await real.chunkSource(source);
    ref.read(vectorStoreProvider).addChunks(chunks);
    return chunks;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Ingestion failed for source $sourceId: $e');
    }
    // Fallback to mock ingestion if real ingestion fails
    final service = ref.read(ingestionServiceProvider);
    final chunks = service.chunkSource(source);
    ref.read(vectorStoreProvider).addChunks(chunks);
    return chunks;
  }
});
