import 'package:freezed_annotation/freezed_annotation.dart';

part 'ebook_image.freezed.dart';
part 'ebook_image.g.dart';

@freezed
class EbookImage with _$EbookImage {
  const factory EbookImage({
    required String id,
    required String prompt,
    required String url,
    @Default('') String caption,
    @Default('generated') String type, // generated, uploaded
  }) = _EbookImage;

  const EbookImage._();

  factory EbookImage.fromBackendJson(Map<String, dynamic> json) => EbookImage(
        id: json['id'],
        prompt: json['prompt'],
        url: json['url'],
        caption: json['caption'] ?? '',
        type: json['type'] ?? 'generated',
      );

  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'prompt': prompt,
        'url': url,
        'caption': caption,
        'type': type,
      };

  factory EbookImage.fromJson(Map<String, dynamic> json) =>
      _$EbookImageFromJson(json);
}
