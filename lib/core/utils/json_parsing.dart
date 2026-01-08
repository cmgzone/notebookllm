/// Reusable JSON parsing utilities for safe type conversion
/// Handles snake_case/camelCase field names and type coercion
library;

/// Extension methods for safe JSON parsing on Map<String, dynamic>
extension JsonParsing on Map<String, dynamic> {
  /// Get a string field with snake_case/camelCase fallback
  String? getString(String snakeKey, [String? camelKey]) {
    final value = this[snakeKey] ?? (camelKey != null ? this[camelKey] : null);
    return value?.toString();
  }

  /// Get a required string field with fallback
  String getStringOrDefault(String snakeKey,
      [String? camelKey, String fallback = '']) {
    return getString(snakeKey, camelKey) ?? fallback;
  }

  /// Get an int field with safe parsing
  int getInt(String snakeKey, [String? camelKey, int fallback = 0]) {
    final value = this[snakeKey] ?? (camelKey != null ? this[camelKey] : null);
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? fallback;
    if (value is double) return value.toInt();
    return fallback;
  }

  /// Get a double field with safe parsing
  double getDouble(String snakeKey, [String? camelKey, double fallback = 0.0]) {
    final value = this[snakeKey] ?? (camelKey != null ? this[camelKey] : null);
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Get a bool field with safe parsing
  bool getBool(String snakeKey, [String? camelKey, bool fallback = false]) {
    final value = this[snakeKey] ?? (camelKey != null ? this[camelKey] : null);
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value != 0;
    return fallback;
  }

  /// Get a DateTime field with safe parsing
  /// Returns null if parsing fails (safer than returning DateTime.now())
  DateTime? getDateTime(String snakeKey, [String? camelKey]) {
    final value = this[snakeKey] ?? (camelKey != null ? this[camelKey] : null);
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Get a DateTime field with fallback (use when field is required)
  DateTime getDateTimeOrNow(String snakeKey, [String? camelKey]) {
    return getDateTime(snakeKey, camelKey) ?? DateTime.now();
  }

  /// Get a DateTime field with explicit fallback
  DateTime getDateTimeOrDefault(
      String snakeKey, String? camelKey, DateTime fallback) {
    return getDateTime(snakeKey, camelKey) ?? fallback;
  }

  /// Get a list field with type casting
  List<T> getList<T>(String snakeKey, [String? camelKey]) {
    final value = this[snakeKey] ?? (camelKey != null ? this[camelKey] : null);
    if (value == null) return <T>[];
    if (value is List) {
      return value.whereType<T>().toList();
    }
    return <T>[];
  }

  /// Get a nested map field
  Map<String, dynamic>? getMap(String snakeKey, [String? camelKey]) {
    final value = this[snakeKey] ?? (camelKey != null ? this[camelKey] : null);
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}

/// Standalone parsing functions for use outside of extension context
class JsonParser {
  JsonParser._();

  /// Safely parse int from dynamic value
  static int parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? fallback;
    if (value is double) return value.toInt();
    return fallback;
  }

  /// Safely parse double from dynamic value
  static double parseDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Safely parse bool from dynamic value
  static bool parseBool(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value != 0;
    return fallback;
  }

  /// Safely parse DateTime from dynamic value
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Parse DateTime with fallback to current time
  static DateTime parseDateTimeOrNow(dynamic value) {
    return parseDateTime(value) ?? DateTime.now();
  }
}
