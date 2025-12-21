import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../ai/gemini_service.dart';

class GeminiEmbeddingService {
  final GeminiService _geminiService;

  GeminiEmbeddingService(this._geminiService);

  Future<List<double>> embed(String text) async {
    try {
      // Use Gemini to generate embeddings
      // Since Gemini doesn't have a direct embedding API, we'll generate a semantic representation
      final embedding = await _geminiService.generateEmbedding(text);
      return embedding;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Gemini embedding error: $e');
      }
      
      // Fallback: generate a simple hash-based embedding for development
      return _generateFallbackEmbedding(text);
    }
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

// Extension to add embedding generation to GeminiService
extension GeminiEmbeddingExtension on GeminiService {
  Future<List<double>> generateEmbedding(String text) async {
    // Use Gemini to create a semantic representation
    final prompt = '''Generate a semantic embedding vector for the following text.
    Return only a JSON array of 384 floating point numbers between -1 and 1.
    Text: "$text"''';
    
    try {
      final response = await generateContent(prompt);
      
      // Try to parse the response as JSON array
      if (response.trim().startsWith('[') && response.trim().endsWith(']')) {
        final jsonList = jsonDecode(response.trim()) as List;
        return jsonList.map((e) => (e as num).toDouble()).toList();
      }
      
      // Fallback: convert response to embedding
      return _textToEmbedding(response);
    } catch (e) {
      return _textToEmbedding(text);
    }
  }

  List<double> _textToEmbedding(String text) {
    // Convert text to a fixed-size embedding using character codes
    const size = 384;
    final embedding = List<double>.filled(size, 0.0);
    
    for (int i = 0; i < text.length && i < size; i++) {
      embedding[i] = (text.codeUnitAt(i) % 256) / 128.0 - 1.0; // Normalize to [-1, 1]
    }
    
    return embedding;
  }
}