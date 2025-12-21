import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'progress_notification_service.dart';

/// Service to manage floating bubble overlay during AI generation
/// Falls back to notifications if overlay is unavailable
class OverlayBubbleService {
  static final OverlayBubbleService _instance =
      OverlayBubbleService._internal();
  factory OverlayBubbleService() => _instance;
  OverlayBubbleService._internal();

  bool _isShowing = false;
  bool _useNotificationFallback = false;
  String _status = 'Generating...';
  int _progress = 0;

  /// Check if overlay permission is granted
  Future<bool> checkPermission() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      // Overlay not supported, use notification fallback
      _useNotificationFallback = true;
      return true; // Return true to continue with notifications
    }
  }

  /// Request overlay permission
  Future<bool> requestPermission() async {
    try {
      final result = await FlutterOverlayWindow.requestPermission();
      if (result != true) {
        _useNotificationFallback = true;
      }
      return result ?? false;
    } catch (e) {
      _useNotificationFallback = true;
      return true; // Use notifications instead
    }
  }

  /// Show the floating bubble or notification
  Future<void> show({String status = 'AI Generating...'}) async {
    if (_isShowing) return;

    _status = status;
    _isShowing = true;

    // Try overlay first, fall back to notification
    if (!_useNotificationFallback) {
      try {
        final hasPermission = await checkPermission();
        if (hasPermission && !_useNotificationFallback) {
          await FlutterOverlayWindow.showOverlay(
            enableDrag: true,
            overlayTitle: "NotebookLLM",
            overlayContent: status,
            flag: OverlayFlag.defaultFlag,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.auto,
            height: 160,
            width: 160,
          );
          return; // Overlay shown successfully
        }
      } catch (e) {
        // Overlay failed, fall back to notification
        _useNotificationFallback = true;
      }
    }

    // Fallback to notification
    await progressNotificationService.showIndeterminate(
      title: 'Ebook Generation',
      status: status,
    );
  }

  /// Update bubble status or notification
  Future<void> updateStatus(String status, {int? progress}) async {
    _status = status;
    if (progress != null) _progress = progress;

    if (_isShowing) {
      if (!_useNotificationFallback) {
        try {
          // Send data to overlay
          await FlutterOverlayWindow.shareData({
            'status': status,
            'progress': _progress,
          });
          return;
        } catch (e) {
          // Overlay update failed, switch to notification
          _useNotificationFallback = true;
          // Close overlay and switch to notification
          try {
            await FlutterOverlayWindow.closeOverlay();
          } catch (_) {}
        }
      }

      // Update notification
      if (progress != null && progress > 0) {
        await progressNotificationService.showProgress(
          title: 'Ebook Generation',
          status: status,
          progress: progress,
          maxProgress: 100,
        );
      } else {
        await progressNotificationService.showIndeterminate(
          title: 'Ebook Generation',
          status: status,
        );
      }
    }
  }

  /// Hide the floating bubble or notification
  Future<void> hide() async {
    if (!_isShowing) return;
    _isShowing = false;

    if (!_useNotificationFallback) {
      try {
        await FlutterOverlayWindow.closeOverlay();
      } catch (e) {
        // Error closing overlay, ignore
      }
    }

    await progressNotificationService.hide();
  }

  /// Check if bubble is currently showing
  bool get isShowing => _isShowing;
  String get status => _status;
  int get progress => _progress;
}

/// Global instance
final overlayBubbleService = OverlayBubbleService();

/// Provider for overlay service
final overlayBubbleServiceProvider = Provider((ref) => overlayBubbleService);
