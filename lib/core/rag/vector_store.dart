import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'chunk.dart';
import 'gemini_embedding_service.dart';
import 'embedding_service.dart';

class VectorStore {
  final List<Chunk> _chunks = [];
  GeminiEmbeddingService? _geminiEmbedding;
  EmbeddingService? _openaiEmbedding;

  void setEmbeddingService(
      {GeminiEmbeddingService? gemini, EmbeddingService? openai}) {
    _geminiEmbedding = gemini;
    _openaiEmbedding = openai;
  }

  void addChunks(List<Chunk> chunks) => _chunks.addAll(chunks);

  List<(Chunk, double)> search(String query, {int topK = 5}) {
    if (_chunks.isEmpty) {
      if (kDebugMode) {
        debugPrint('VectorStore: No chunks available for search');
      }
      return [];
    }

    // Use text-based similarity as fallback if no embedding service
    if (_geminiEmbedding == null && _openaiEmbedding == null) {
      if (kDebugMode) {
        debugPrint(
            'VectorStore: Using text-based similarity (no embedding service)');
      }
      return _textBasedSearch(query, topK);
    }

    // For synchronous search, use text-based similarity
    // Real embedding search should be done asynchronously
    return _textBasedSearch(query, topK);
  }

  Future<List<(Chunk, double)>> searchAsync(String query,
      {int topK = 5}) async {
    if (_chunks.isEmpty) {
      if (kDebugMode) {
        debugPrint('VectorStore: No chunks available for search');
      }
      return [];
    }

    List<double> queryEmbedding;
    try {
      if (_geminiEmbedding != null) {
        queryEmbedding = await _geminiEmbedding!.embed(query);
      } else if (_openaiEmbedding != null) {
        queryEmbedding = await _openaiEmbedding!.embed(query);
      } else {
        // Fallback to text-based search
        return _textBasedSearch(query, topK);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'VectorStore: Embedding generation failed, using text-based search: $e');
      }
      return _textBasedSearch(query, topK);
    }

    final scored = _chunks
        .map((c) => (c, _cosineSimilarity(queryEmbedding, c.embedding)))
        .toList();
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(topK).toList();
  }

  List<(Chunk, double)> _textBasedSearch(String query, int topK) {
    final queryLower = query.toLowerCase();
    final scored = _chunks.map((c) {
      final textLower = c.text.toLowerCase();
      // Simple text similarity: count matching words
      final queryWords = queryLower.split(RegExp(r'\s+'));
      final matchCount =
          queryWords.where((word) => textLower.contains(word)).length;
      final score = matchCount / queryWords.length;
      return (c, score);
    }).toList();

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.where((s) => s.$2 > 0).take(topK).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denominator = math.sqrt(normA) * math.sqrt(normB);
    return denominator > 0 ? dot / denominator : 0.0;
  }

  int get chunkCount => _chunks.length;

  void clear() => _chunks.clear();
}
