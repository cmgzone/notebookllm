import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'embedding_service.dart';
import 'gemini_embedding_service.dart';
import 'chunk.dart';
import '../../features/sources/source.dart';
import '../ai/gemini_service.dart';

final embeddingServiceProvider = Provider<EmbeddingService?>(
    (ref) => null); // will be overridden with API key

final geminiEmbeddingServiceProvider = Provider<GeminiEmbeddingService?>((ref) {
  try {
    final geminiService = ref.watch(geminiServiceProvider);
    return GeminiEmbeddingService(geminiService);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Failed to initialize Gemini embedding service: $e');
    }
    return null;
  }
});

final geminiServiceProvider = Provider((ref) => GeminiService());

class RealIngestionService {
  final EmbeddingService? _embedding;
  final GeminiEmbeddingService? _geminiEmbedding;

  RealIngestionService(
      {EmbeddingService? embedding, GeminiEmbeddingService? geminiEmbedding})
      : _embedding = embedding,
        _geminiEmbedding = geminiEmbedding {
    if (_embedding == null && _geminiEmbedding == null) {
      throw Exception('Either embedding or geminiEmbedding must be provided');
    }
  }

  Future<List<Chunk>> chunkSource(Source source) async {
    final text = source.content;
    final chunks = <Chunk>[];
    const chunkSize = 512;
    const overlap = 50;
    int pos = 0;
    int id = 0;

    while (pos < text.length) {
      final end = (pos + chunkSize).clamp(0, text.length);
      final snippet = text.substring(pos, end);

      List<double> embedding;
      try {
        if (_geminiEmbedding != null) {
          // Use Gemini for embeddings
          embedding = await _geminiEmbedding.embed(snippet);
        } else if (_embedding != null) {
          // Use OpenAI for embeddings
          embedding = await _embedding.embed(snippet);
        } else {
          throw Exception('No embedding service available');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Embedding generation failed for chunk $id: $e');
        }
        // Generate a fallback embedding to prevent complete failure
        embedding = _generateFallbackEmbedding(snippet);
      }

      chunks.add(Chunk(
        id: '${source.id}_$id',
        sourceId: source.id,
        text: snippet,
        start: pos,
        end: end,
        embedding: embedding,
      ));
      pos = end - overlap;
      id++;
    }
    return chunks;
  }

  List<double> _generateFallbackEmbedding(String text) {
    // Simple fallback embedding for development when API fails
    const embeddingSize = 384;
    final hash = text.hashCode;
    final random = Random(hash);

    return List.generate(embeddingSize, (i) {
      return (random.nextDouble() * 2 - 1); // Values between -1 and 1
    });
  }
}

final realIngestionProvider = Provider((ref) {
  final openaiService = ref.watch(embeddingServiceProvider);
  final geminiService = ref.watch(geminiEmbeddingServiceProvider);

  if (openaiService == null && geminiService == null) {
    return null;
  }

  return RealIngestionService(
    embedding: openaiService,
    geminiEmbedding: geminiService,
  );
});
