import 'dart:math' as math;
import 'chunk.dart';
import '../../features/sources/source.dart';

class IngestionService {
  static const chunkSize = 512;
  static const overlap = 50;

  List<Chunk> chunkSource(Source source) {
    final text = source.content;
    final chunks = <Chunk>[];
    int pos = 0;
    int id = 0;
    while (pos < text.length) {
      final end = math.min(pos + chunkSize, text.length);
      final snippet = text.substring(pos, end);
      chunks.add(Chunk(
        id: '${source.id}_$id',
        sourceId: source.id,
        text: snippet,
        start: pos,
        end: end,
        embedding: _fakeEmbedding(snippet),
      ));
      pos = end - overlap;
      id++;
    }
    return chunks;
  }

  List<double> _fakeEmbedding(String text) {
    return List.generate(384, (i) => math.Random().nextDouble() * 2 - 1);
  }
}