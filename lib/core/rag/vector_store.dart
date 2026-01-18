import 'package:flutter/foundation.dart';
import 'chunk.dart';
import '../api/api_service.dart';

class VectorStore {
  final ApiService _api;

  VectorStore(this._api);

  // Deprecated methods that no longer do anything locally
  void setEmbeddingService({dynamic gemini, dynamic openai}) {}
  void addChunks(List<Chunk> chunks) {}
  int get chunkCount => 0;
  void clear() {}

  /// Search using backend RAG
  /// Note: This replaces the synchronous search. Callers must await this.
  Future<List<(Chunk, double)>> search(String query,
      {int topK = 5, String? notebookId}) async {
    try {
      final response = await _api.post('/embeddings/search', {
        'query': query,
        'limit': topK,
        if (notebookId != null) 'notebookId': notebookId,
      });

      if (response['success'] == true) {
        final results =
            List<Map<String, dynamic>>.from(response['results'] ?? []);

        return results.map((r) {
          final chunk = Chunk(
            id: r['id'],
            sourceId: r['source_id'],
            text: r['content'],
            start: 0, // Not preserved in RAG response usually
            end: 0,
            embedding: [], // Embedding not returned for bandwidth
          );
          final score = (r['similarity'] as num).toDouble();
          return (chunk, score);
        }).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VectorStore API search failed: $e');
      }
      return [];
    }
  }

  // Alias for search to maintain compatibility where async was explicitly called
  Future<List<(Chunk, double)>> searchAsync(String query, {int topK = 5}) {
    return search(query, topK: topK);
  }
}
