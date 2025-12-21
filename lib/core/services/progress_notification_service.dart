import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service to show persistent notifications for background AI generation
class ProgressNotificationService {
  static final ProgressNotificationService _instance =
      ProgressNotificationService._internal();
  factory ProgressNotificationService() => _instance;
  ProgressNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  static const int _notificationId = 1001;
  static const String _channelId = 'ai_generation_progress';
  static const String _channelName = 'AI Generation Progress';

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Shows progress of AI ebook generation',
      importance: Importance.low, // Low importance = no sound
      enableVibration: false,
      playSound: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _isInitialized = true;
  }

  /// Show progress notification
  Future<void> showProgress({
    required String title,
    required String status,
    int progress = 0,
    int maxProgress = 100,
  }) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Shows progress of AI ebook generation',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Can't be dismissed by user
      autoCancel: false,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      icon: '@mipmap/ic_launcher',
      enableVibration: false,
      playSound: false,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      title,
      status,
      notificationDetails,
    );
  }

  /// Update notification with indeterminate progress
  Future<void> showIndeterminate({
    required String title,
    required String status,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Shows progress of AI ebook generation',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      indeterminate: true, // Indeterminate progress
      icon: '@mipmap/ic_launcher',
      enableVibration: false,
      playSound: false,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      title,
      status,
      notificationDetails,
    );
  }

  /// Hide/cancel the notification
  Future<void> hide() async {
    await _notifications.cancel(_notificationId);
  }

  /// Show completion notification
  Future<void> showComplete({
    required String title,
    String message = 'Generation complete!',
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      title,
      message,
      notificationDetails,
    );

    // Auto-dismiss after 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    await hide();
  }
}

/// Global instance
final progressNotificationService = ProgressNotificationService();
