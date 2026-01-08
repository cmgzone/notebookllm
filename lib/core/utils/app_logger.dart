import 'dart:developer' as developer;

/// Simple logging utility for the app
/// Uses Flutter's developer.log for better debugging and production logging
class AppLogger {
  final String name;

  const AppLogger(this.name);

  /// Log an error message
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: name,
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a warning message
  void warning(String message) {
    developer.log(
      message,
      name: name,
      level: 900, // Warning level
    );
  }

  /// Log an info message
  void info(String message) {
    developer.log(
      message,
      name: name,
      level: 800, // Info level
    );
  }

  /// Log a debug message
  void debug(String message) {
    developer.log(
      message,
      name: name,
      level: 500, // Debug level
    );
  }
}
