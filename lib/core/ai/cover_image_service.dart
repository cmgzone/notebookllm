import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final coverImageServiceProvider = Provider<CoverImageService>((ref) {
  return CoverImageService(ref);
});

class CoverImageService {
  final Ref ref;

  CoverImageService(this.ref);

  /// Generate a cover image using AI based on notebook title and description
  /// Returns base64 encoded image data
  Future<String> generateCoverImage({
    required String notebookTitle,
    String? description,
  }) async {
    try {
      // Create a prompt for the cover image
      final prompt = _buildImagePrompt(notebookTitle, description);
      debugPrint('[CoverImage] Generating with prompt: $prompt');

      // Try different image generation APIs
      // Option 1: Use Pollinations.ai (free, no API key required)
      final imageUrl = await _generateWithPollinations(prompt);

      // Download the image and convert to base64
      final imageBytes = await _downloadImage(imageUrl);
      final base64Image = base64Encode(imageBytes);

      debugPrint(
          '[CoverImage] Generated successfully, size: ${imageBytes.length} bytes');
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      debugPrint('[CoverImage] Error generating: $e');
      rethrow;
    }
  }

  String _buildImagePrompt(String title, String? description) {
    final basePrompt =
        'Create a beautiful, modern book cover design for a notebook titled "$title"';

    if (description != null && description.isNotEmpty) {
      return '$basePrompt. The content is about: $description. '
          'Style: premium, minimalist, professional, gradient colors, abstract shapes. '
          'No text on the image.';
    }

    return '$basePrompt. '
        'Style: premium, minimalist, professional, gradient colors, abstract geometric patterns. '
        'No text on the image.';
  }

  /// Generate image using Pollinations.ai (free, no API key)
  Future<String> _generateWithPollinations(String prompt) async {
    // Pollinations.ai provides free image generation
    final encodedPrompt = Uri.encodeComponent(prompt);
    final url =
        'https://image.pollinations.ai/prompt/$encodedPrompt?width=512&height=512&nologo=true';

    debugPrint('[CoverImage] Pollinations URL: $url');
    return url;
  }

  /// Download image from URL and return bytes
  Future<Uint8List> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 60),
          );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[CoverImage] Download error: $e');
      rethrow;
    }
  }

  /// Convert image file bytes to base64 data URL
  String bytesToBase64DataUrl(Uint8List bytes, String mimeType) {
    final base64 = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64';
  }

  /// Extract bytes from base64 data URL
  Uint8List? base64DataUrlToBytes(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:')) return null;

    try {
      final base64Part = dataUrl.split(',').last;
      return base64Decode(base64Part);
    } catch (e) {
      debugPrint('[CoverImage] Error decoding base64: $e');
      return null;
    }
  }

  /// Generate a simple gradient cover as fallback
  Future<String> generateSimpleCover(String title) async {
    // Generate a unique color based on the title
    final hash = title.hashCode.abs();
    final hue = (hash % 360).toDouble();

    // Create an SVG gradient as a simple cover
    final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:hsl($hue, 70%, 50%);stop-opacity:1" />
      <stop offset="100%" style="stop-color:hsl(${(hue + 60) % 360}, 70%, 30%);stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="512" height="512" fill="url(#grad)"/>
  <circle cx="400" cy="100" r="80" fill="rgba(255,255,255,0.1)"/>
  <circle cx="100" cy="400" r="120" fill="rgba(255,255,255,0.08)"/>
  <circle cx="256" cy="256" r="60" fill="rgba(255,255,255,0.05)"/>
</svg>
''';

    final base64Svg = base64Encode(utf8.encode(svg));
    return 'data:image/svg+xml;base64,$base64Svg';
  }
}
