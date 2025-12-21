import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'ingestion_service.dart';
import 'vector_store.dart';
import 'gemini_embedding_service.dart';
import '../ai/gemini_service.dart';

final ingestionServiceProvider = Provider((ref) => IngestionService());

final vectorStoreProvider = Provider((ref) {
  final vectorStore = VectorStore();

  // Try to initialize with Gemini embedding service
  try {
    final geminiService = GeminiService();
    final geminiEmbedding = GeminiEmbeddingService(geminiService);
    vectorStore.setEmbeddingService(gemini: geminiEmbedding);
    if (kDebugMode) {
      debugPrint('VectorStore: Initialized with Gemini embedding service');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('VectorStore: Failed to initialize embedding service: $e');
    }
  }

  return vectorStore;
});
