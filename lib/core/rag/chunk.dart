import 'package:freezed_annotation/freezed_annotation.dart';

part 'chunk.freezed.dart';
part 'chunk.g.dart';

@freezed
class Chunk with _$Chunk {
  const factory Chunk({
    required String id,
    required String sourceId,
    required String text,
    required int start,
    required int end,
    required List<double> embedding,
  }) = _Chunk;

  factory Chunk.fromJson(Map<String, dynamic> json) => _$ChunkFromJson(json);
}