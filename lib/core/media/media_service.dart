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
    this.cdnUrl,
  });
  final String id;
  final String userId;
  final String filename;
  final String type; // image | video | audio | pdf
  final String mime;
  final int sizeBytes;
  final String? url;
  final String? cdnUrl;

  /// Returns the best URL to use (CDN preferred)
  String? get bestUrl => cdnUrl ?? url;
}

class MediaStats {
  MediaStats({
    required this.totalSize,
    required this.dbSize,
    required this.cdnSize,
    required this.cdnCount,
    required this.dbCount,
    required this.useCdn,
  });

  final int totalSize;
  final int dbSize;
  final int cdnSize;
  final int cdnCount;
  final int dbCount;
  final bool useCdn;

  factory MediaStats.fromJson(Map<String, dynamic> json) {
    return MediaStats(
      totalSize: json['size'] ?? 0,
      dbSize: json['dbSize'] ?? 0,
      cdnSize: json['cdnSize'] ?? 0,
      cdnCount: json['cdnCount'] ?? 0,
      dbCount: json['dbCount'] ?? 0,
      useCdn: json['useCdn'] ?? false,
    );
  }
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

  /// Get the CDN URL for a media source (if available)
  Future<String?> getMediaUrl(String sourceId) async {
    try {
      final response = await _api.get('/media/$sourceId/url');
      if (response['success'] == true && response['url'] != null) {
        return response['url'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting media URL: $e');
      return null;
    }
  }

  /// Get media storage statistics
  Future<MediaStats?> getMediaStats() async {
    try {
      final response = await _api.get('/media/stats/size');
      if (response['success'] == true) {
        return MediaStats.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting media stats: $e');
      return null;
    }
  }

  /// Upload media directly to CDN
  Future<String?> uploadDirect({
    required Uint8List bytes,
    required String filename,
    required String type,
  }) async {
    try {
      final base64Data = base64Encode(bytes);
      final response = await _api.post('/media/upload-direct', {
        'mediaData': base64Data,
        'filename': filename,
        'type': type,
      });

      if (response['success'] == true) {
        return response['url'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading to CDN: $e');
      return null;
    }
  }

  /// Migrate user's media from database to CDN
  Future<Map<String, int>> migrateToCdn() async {
    try {
      final response = await _api.post('/media/migrate-to-cdn', {});
      return {
        'migrated': response['migrated'] ?? 0,
        'failed': response['failed'] ?? 0,
        'remaining': response['remaining'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error migrating to CDN: $e');
      return {'migrated': 0, 'failed': 0, 'remaining': 0};
    }
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

/// Helper function for base64 encoding
String base64Encode(Uint8List bytes) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final buffer = StringBuffer();
  int i = 0;

  while (i < bytes.length) {
    final b1 = bytes[i++];
    final b2 = i < bytes.length ? bytes[i++] : 0;
    final b3 = i < bytes.length ? bytes[i++] : 0;

    buffer.write(chars[(b1 >> 2) & 0x3F]);
    buffer.write(chars[((b1 << 4) | (b2 >> 4)) & 0x3F]);
    buffer.write(
        i > bytes.length + 1 ? '=' : chars[((b2 << 2) | (b3 >> 6)) & 0x3F]);
    buffer.write(i > bytes.length ? '=' : chars[b3 & 0x3F]);
  }

  return buffer.toString();
}
