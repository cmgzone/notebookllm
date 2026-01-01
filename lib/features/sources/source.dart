import 'package:freezed_annotation/freezed_annotation.dart';

part 'source.freezed.dart';
part 'source.g.dart';

@freezed
class Source with _$Source {
  const factory Source({
    required String id,
    required String notebookId,
    required String title,
    required String type, // drive, file, url, youtube, audio, text, image
    required DateTime addedAt,
    required String content, // raw text or transcript
    String? summary,
    DateTime? summaryGeneratedAt,
    String? imageUrl, // URL or base64 data URL for image sources
    String? thumbnailUrl, // Optional thumbnail for previews
    @Default([]) List<String> tagIds,
  }) = _Source;

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);
}
