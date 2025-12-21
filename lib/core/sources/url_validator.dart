/// URL validation utilities for different source types
class UrlValidator {
  /// Validate YouTube URL
  static bool isValidYouTubeUrl(String url) {
    final patterns = [
      RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/embed\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/v\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})'),
    ];

    return patterns.any((pattern) => pattern.hasMatch(url));
  }

  /// Extract YouTube video ID
  static String? extractYouTubeVideoId(String url) {
    final patterns = [
      RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/embed\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/v\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Get YouTube thumbnail URL
  static String getYouTubeThumbnail(String videoId,
      {String quality = 'hqdefault'}) {
    // Quality options: default, mqdefault, hqdefault, sddefault, maxresdefault
    return 'https://img.youtube.com/vi/$videoId/$quality.jpg';
  }

  /// Validate Google Drive URL
  static bool isValidGoogleDriveUrl(String url) {
    final patterns = [
      RegExp(r'drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)'),
      RegExp(r'drive\.google\.com\/open\?id=([a-zA-Z0-9_-]+)'),
      RegExp(
          r'docs\.google\.com\/(document|spreadsheets|presentation)\/d\/([a-zA-Z0-9_-]+)'),
    ];

    return patterns.any((pattern) => pattern.hasMatch(url));
  }

  /// Extract Google Drive file ID
  static String? extractGoogleDriveFileId(String url) {
    final patterns = [
      RegExp(r'drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)'),
      RegExp(r'drive\.google\.com\/open\?id=([a-zA-Z0-9_-]+)'),
      RegExp(
          r'docs\.google\.com\/(?:document|spreadsheets|presentation)\/d\/([a-zA-Z0-9_-]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        return match.group(match.groupCount);
      }
    }

    return null;
  }

  /// Get Google Drive file type from URL
  static String getGoogleDriveFileType(String url) {
    if (url.contains('docs.google.com/document')) return 'document';
    if (url.contains('docs.google.com/spreadsheets')) return 'spreadsheet';
    if (url.contains('docs.google.com/presentation')) return 'presentation';
    return 'file';
  }

  /// Get display name for Google Drive file type
  static String getGoogleDriveDisplayName(String url) {
    final type = getGoogleDriveFileType(url);
    switch (type) {
      case 'document':
        return 'Google Doc';
      case 'spreadsheet':
        return 'Google Sheet';
      case 'presentation':
        return 'Google Slides';
      default:
        return 'Google Drive File';
    }
  }

  /// Validate general web URL
  static bool isValidWebUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }

  /// Get domain from URL
  static String? getDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return null;
    }
  }

  /// Check if URL is from a specific domain
  static bool isFromDomain(String url, String domain) {
    final urlDomain = getDomain(url);
    return urlDomain != null && urlDomain.contains(domain);
  }

  /// Detect source type from URL
  static String detectSourceType(String url) {
    if (isValidYouTubeUrl(url)) return 'youtube';
    if (isValidGoogleDriveUrl(url)) return 'drive';
    if (isValidWebUrl(url)) return 'url';
    return 'unknown';
  }

  /// Get user-friendly error message for invalid URL
  static String getErrorMessage(String url, String expectedType) {
    if (url.isEmpty) {
      return 'Please enter a URL';
    }

    switch (expectedType) {
      case 'youtube':
        return 'Please enter a valid YouTube URL (e.g., youtube.com/watch?v=...)';
      case 'drive':
        return 'Please enter a valid Google Drive URL (e.g., drive.google.com/file/d/...)';
      case 'url':
        return 'Please enter a valid web URL (e.g., https://example.com)';
      default:
        return 'Invalid URL format';
    }
  }
}
