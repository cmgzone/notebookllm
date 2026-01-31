class GituException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  GituException(this.message, {this.code, this.originalError});

  factory GituException.from(dynamic error) {
    if (error is GituException) return error;

    final String msg = error.toString();

    // Network/Connection errors
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection timed out') ||
        msg.contains('XMLHttpRequest')) {
      return GituException(
        'Unable to connect to Gitu server. Please check your internet connection.',
        code: 'CONNECTION_ERROR',
        originalError: error,
      );
    }

    // WebSocket specific
    if (msg.contains('WebSocket') ||
        msg.contains('closed without a status code')) {
      return GituException(
        'Connection to Gitu was lost. Reconnecting...',
        code: 'WEBSOCKET_ERROR',
        originalError: error,
      );
    }

    // Authentication
    if (msg.contains('401') ||
        msg.contains('Unauthorized') ||
        msg.contains('token')) {
      return GituException(
        'Authentication failed. Please try logging in again.',
        code: 'AUTH_ERROR',
        originalError: error,
      );
    }

    // Timeout
    if (msg.contains('TimeoutException')) {
      return GituException(
        'The operation timed out. Please try again.',
        code: 'TIMEOUT_ERROR',
        originalError: error,
      );
    }

    // Generic fallback for user-friendly display
    // Strip "Exception:" prefix if present for cleaner UI
    final cleanMsg = msg.replaceAll(RegExp(r'^Exception:\s*'), '');
    return GituException(cleanMsg, code: 'UNKNOWN_ERROR', originalError: error);
  }

  @override
  String toString() => message;
}
