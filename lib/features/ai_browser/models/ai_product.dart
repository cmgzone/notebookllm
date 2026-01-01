import 'dart:typed_data';

class AIProduct {
  final String title;
  final String price;
  final String description;
  final String? imageUrl;
  final String? url;
  final Uint8List? screenshotBytes;

  AIProduct({
    required this.title,
    required this.price,
    required this.description,
    this.imageUrl,
    this.url,
    this.screenshotBytes,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'price': price,
        'description': description,
        'imageUrl': imageUrl,
        'url': url,
        // Note: screenshotBytes not included in JSON as it's binary
      };
}
