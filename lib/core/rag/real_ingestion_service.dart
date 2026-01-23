import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chunk.dart';
import '../../features/sources/source.dart';
import '../api/api_service.dart';

class RealIngestionService {
  final ApiService _api;

  RealIngestionService(this._api);

  Future<List<Chunk>> chunkSource(Source source) async {
    try {
      // Call backend to process source (chunk + embed + store)
      await _api.post('/rag/ingestion/process', {
        'sourceId': source.id,
      });

      // We don't need to return actual chunks with embeddings to the client anymore
      // as search will happen on backend. We return empty list to satisfy signature
      // or we could fetch chunks without embeddings if UI needs snippet display.
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Ingestion failed: $e');
      }
      rethrow;
    }
  }
}

final realIngestionProvider = Provider((ref) {
  final api = ref.read(apiServiceProvider);
  return RealIngestionService(api);
});
