import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service to manage wake lock during long-running AI operations
/// Prevents the screen from sleeping and keeps CPU active
class WakelockService {
  static final WakelockService _instance = WakelockService._internal();
  factory WakelockService() => _instance;
  WakelockService._internal();

  int _activeOperations = 0;

  /// Enable wake lock for a long-running operation
  /// Call [release] when the operation completes
  Future<void> acquire() async {
    _activeOperations++;
    if (_activeOperations == 1) {
      try {
        await WakelockPlus.enable();
        debugPrint('[WakelockService] Wake lock enabled');
      } catch (e) {
        debugPrint('[WakelockService] Failed to enable wake lock: $e');
      }
    }
  }

  /// Release wake lock after operation completes
  Future<void> release() async {
    _activeOperations--;
    if (_activeOperations <= 0) {
      _activeOperations = 0;
      try {
        await WakelockPlus.disable();
        debugPrint('[WakelockService] Wake lock disabled');
      } catch (e) {
        debugPrint('[WakelockService] Failed to disable wake lock: $e');
      }
    }
  }

  /// Run an async operation with wake lock protection
  Future<T> withWakeLock<T>(Future<T> Function() operation) async {
    await acquire();
    try {
      return await operation();
    } finally {
      await release();
    }
  }

  /// Check if wake lock is currently enabled
  Future<bool> get isEnabled => WakelockPlus.enabled;
}

/// Global instance for easy access
final wakelockService = WakelockService();
