import 'package:freezed_annotation/freezed_annotation.dart';
import 'ebook_image.dart';

part 'ebook_chapter.freezed.dart';
part 'ebook_chapter.g.dart';

@freezed
class EbookChapter with _$EbookChapter {
  const factory EbookChapter({
    required String id,
    required String title,
    required String content, // Markdown content
    @Default([]) List<EbookImage> images,
    required int orderIndex,
    @Default(false) bool isGenerating,
  }) = _EbookChapter;

  const EbookChapter._();

  factory EbookChapter.fromBackendJson(Map<String, dynamic> json) =>
      EbookChapter(
        id: json['id'],
        title: json['title'],
        content: json['content'] ?? '',
        images: (json['images'] as List? ?? [])
            .map((img) => EbookImage.fromBackendJson(img))
            .toList(),
        orderIndex: json['order_index'] ?? 0,
        isGenerating: json['is_generating'] ?? false,
      );

  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'title': title,
        'content': content,
        'images': images.map((img) => img.toBackendJson()).toList(),
        'order_index': orderIndex,
        'is_generating': isGenerating,
      };

  factory EbookChapter.fromJson(Map<String, dynamic> json) =>
      _$EbookChapterFromJson(json);
}
