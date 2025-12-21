import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';

class MediaAsset {
  MediaAsset({
    required this.id,
    required this.userId,
    required this.filename,
    required this.type,
    required this.mime,
    required this.sizeBytes,
    this.url,
  });
  final String id;
  final String userId;
  final String filename;
  final String type; // image | video
  final String mime;
  final int sizeBytes;
  final String? url;
}

final mediaServiceProvider = Provider<MediaService>((ref) => MediaService(ref));

class MediaService {
  MediaService(this.ref);
  final Ref ref;

  ApiService get _api => ref.read(apiServiceProvider);

  /// Get media bytes from API
  /// [id] should be the Source ID (UUID)
  Future<Uint8List?> getMediaBytes(String id) async {
    // Handle media:// prefix
    final cleanId =
        id.startsWith('media://') ? id.substring('media://'.length) : id;

    return await _api.getMediaBytes(cleanId);
  }

  Future<MediaAsset> uploadBytes(Uint8List bytes,
      {required String filename, required String type}) async {
    throw UnimplementedError(
        'Use sourceProvider.addSource to upload media to backend');
  }

  Future<MediaAsset> generateImage(String prompt,
      {String size = '1024'}) async {
    throw UnimplementedError('Use GeminiImageService to generate images');
  }

  Future<MediaAsset> visualizeMindmap(
      {required String userId,
      required String title,
      required List<String> outline,
      List<String> tags = const [],
      String format = 'png'}) async {
    throw UnimplementedError('Mindmap visualization not yet ported to backend');
  }

  String storageUri(MediaAsset asset) => 'media://${asset.id}';

  MediaAsset? mediaAssetFromUri(String uri) {
    if (!uri.startsWith('media://')) {
      return null;
    }
    final id = uri.substring('media://'.length);
    return MediaAsset(
      id: id,
      userId: '',
      filename: '',
      type: 'unknown',
      mime: 'application/octet-stream',
      sizeBytes: 0,
    );
  }
}
