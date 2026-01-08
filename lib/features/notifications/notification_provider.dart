import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import 'notification_model.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final int total;
  final bool isLoading;
  final String? error;
  final NotificationSettings? settings;

  NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.total = 0,
    this.isLoading = false,
    this.error,
    this.settings,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    int? total,
    bool? isLoading,
    String? error,
    NotificationSettings? settings,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      settings: settings ?? this.settings,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final ApiService _api;
  Timer? _pollTimer;

  NotificationNotifier(this._api) : super(NotificationState()) {
    _startPolling();
  }

  void _startPolling() {
    // Poll for unread count every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchUnreadCount();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/notifications');
      final notifications = (response['notifications'] as List)
          .map((n) => AppNotification.fromJson(n))
          .toList();

      state = state.copyWith(
        notifications: notifications,
        unreadCount: response['unreadCount'] ?? 0,
        total: response['total'] ?? 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final response = await _api.get('/notifications/unread-count');
      state = state.copyWith(unreadCount: response['unreadCount'] ?? 0);
    } catch (e) {
      // Silently fail for polling
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _api.patch('/notifications/$notificationId/read', {});

      final updated = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true, readAt: DateTime.now());
        }
        return n;
      }).toList();

      state = state.copyWith(
        notifications: updated,
        unreadCount: (state.unreadCount - 1).clamp(0, state.total),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.post('/notifications/mark-all-read', {});

      final updated = state.notifications.map((n) {
        return n.copyWith(isRead: true, readAt: DateTime.now());
      }).toList();

      state = state.copyWith(notifications: updated, unreadCount: 0);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _api.delete('/notifications/$notificationId');

      final wasUnread = state.notifications
              .firstWhere((n) => n.id == notificationId,
                  orElse: () => state.notifications.first)
              .isRead ==
          false;

      final updated =
          state.notifications.where((n) => n.id != notificationId).toList();

      state = state.copyWith(
        notifications: updated,
        total: state.total - 1,
        unreadCount: wasUnread ? state.unreadCount - 1 : state.unreadCount,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> fetchSettings() async {
    try {
      final response = await _api.get('/notifications/settings');
      final settings = NotificationSettings.fromJson(response['settings']);
      state = state.copyWith(settings: settings);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    try {
      final response = await _api.patch('/notifications/settings', updates);
      final settings = NotificationSettings.fromJson(response['settings']);
      state = state.copyWith(settings: settings);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref.watch(apiServiceProvider));
});

// Simple unread count provider for badge display
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).unreadCount;
});
