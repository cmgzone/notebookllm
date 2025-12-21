import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Background AI Service for continuing generation when app is closed
class BackgroundAIService {
  static final BackgroundAIService _instance = BackgroundAIService._internal();
  factory BackgroundAIService() => _instance;
  BackgroundAIService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _isEnabled = true;

  // Settings keys
  static const String _enabledKey = 'background_service_enabled';
  static const String _taskStatusKey = 'background_task_status';
  static const String _taskResultKey = 'background_task_result';
  static const String _taskProgressKey = 'background_task_progress';
  static const String _taskErrorKey = 'background_task_error';

  /// Check if background execution is enabled
  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  /// Set whether background execution is enabled
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    _isEnabled = enabled;

    if (!enabled && await _service.isRunning()) {
      await stop();
    }

    debugPrint(
        '[BackgroundAI] Background execution ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if enabled
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_enabledKey) ?? true;

      if (!_isEnabled) {
        debugPrint('[BackgroundAI] Background service disabled by user');
        return;
      }

      // Initialize notifications
      await _initializeNotifications();

      // Configure the background service
      await _service.configure(
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
        androidConfiguration: AndroidConfiguration(
          autoStart: false,
          onStart: onStart,
          isForegroundMode: true,
          autoStartOnBoot: false,
          notificationChannelId: 'notebook_llm_background',
          initialNotificationTitle: 'Notebook LLM',
          initialNotificationContent: 'AI processing in background',
          foregroundServiceNotificationId: 888,
          foregroundServiceTypes: [AndroidForegroundType.dataSync],
        ),
      );

      _isInitialized = true;
      debugPrint('[BackgroundAI] Background service initialized successfully');
    } catch (e) {
      debugPrint('[BackgroundAI] Error initializing: $e');
      _logError('initialization', e.toString());
    }
  }

  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('[BackgroundAI] Notification tapped: ${details.payload}');
      },
    );

    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'notebook_llm_background',
      'Background Processing',
      description: 'Notifications for AI processing tasks',
      importance: Importance.low,
      showBadge: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Start background generation task
  Future<bool> startGeneration({
    required String taskType,
    required String taskId,
    required Map<String, dynamic> params,
  }) async {
    if (!_isEnabled) {
      debugPrint('[BackgroundAI] Background execution disabled');
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear previous task data
      await _clearTaskData(prefs);

      // Save task parameters
      await prefs.setString('background_task_type', taskType);
      await prefs.setString('background_task_id', taskId);
      await prefs.setString('background_task_params', jsonEncode(params));
      await prefs.setString(_taskStatusKey, 'starting');
      await prefs.setInt(_taskProgressKey, 0);

      // Start the service
      final started = await _service.startService();

      if (started) {
        debugPrint('[BackgroundAI] Started $taskType task: $taskId');
        await _updateNotification('Starting...', 0);
      } else {
        _logError(taskType, 'Failed to start background service');
      }

      return started;
    } catch (e) {
      debugPrint('[BackgroundAI] Error starting task: $e');
      _logError(taskType, e.toString());
      return false;
    }
  }

  Future<void> _clearTaskData(SharedPreferences prefs) async {
    await prefs.remove(_taskStatusKey);
    await prefs.remove(_taskResultKey);
    await prefs.remove(_taskProgressKey);
    await prefs.remove(_taskErrorKey);
  }

  Future<void> _logError(String taskType, String error) async {
    final prefs = await SharedPreferences.getInstance();
    final errors = prefs.getStringList('background_errors') ?? [];
    errors.add('${DateTime.now().toIso8601String()}|$taskType|$error');

    // Keep only last 10 errors
    if (errors.length > 10) {
      errors.removeRange(0, errors.length - 10);
    }

    await prefs.setStringList('background_errors', errors);
    await prefs.setString(_taskErrorKey, error);
    await prefs.setString(_taskStatusKey, 'error');
  }

  Future<void> _updateNotification(String content, int progress) async {
    await _notifications.show(
      888,
      'Notebook LLM - Processing',
      content,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'notebook_llm_background',
          'Background Processing',
          channelDescription: 'AI processing tasks',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  /// Stop the background service
  Future<void> stop() async {
    try {
      _service.invoke('stopService');
      await _notifications.cancel(888);
      debugPrint('[BackgroundAI] Service stopped');
    } catch (e) {
      debugPrint('[BackgroundAI] Error stopping service: $e');
    }
  }

  /// Get task status
  Future<Map<String, dynamic>> getTaskStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'status': prefs.getString(_taskStatusKey) ?? 'idle',
      'progress': prefs.getInt(_taskProgressKey) ?? 0,
      'error': prefs.getString(_taskErrorKey),
      'isRunning': await _service.isRunning(),
    };
  }

  /// Get task result
  Future<String?> getTaskResult() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_taskResultKey);
  }

  /// Get error log
  Future<List<Map<String, String>>> getErrorLog() async {
    final prefs = await SharedPreferences.getInstance();
    final errors = prefs.getStringList('background_errors') ?? [];

    return errors.map((e) {
      final parts = e.split('|');
      return {
        'timestamp': parts.isNotEmpty ? parts[0] : '',
        'taskType': parts.length > 1 ? parts[1] : '',
        'error': parts.length > 2 ? parts[2] : '',
      };
    }).toList();
  }

  /// Clear error log
  Future<void> clearErrorLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('background_errors');
    await prefs.remove(_taskErrorKey);
  }
}

/// Background isolate entry point
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final notifications = FlutterLocalNotificationsPlugin();

  // Initialize notifications in isolate
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await notifications.initialize(initSettings);

  // Listen for stop command
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Get task parameters
  final taskType = prefs.getString('background_task_type') ?? '';
  final _ =
      prefs.getString('background_task_id') ?? ''; // taskId for future use
  final paramsJson = prefs.getString('background_task_params') ?? '{}';

  try {
    final params = jsonDecode(paramsJson) as Map<String, dynamic>;

    await prefs.setString('background_task_status', 'running');

    // Update notification
    await _showProgressNotification(notifications, 'Processing...', 10);

    // Execute based on task type
    switch (taskType) {
      case 'artifact':
        await _generateArtifactInBackground(
            params, prefs, service, notifications);
        break;
      case 'ebook_chapter':
        await _generateEbookChapterInBackground(
            params, prefs, service, notifications);
        break;
      case 'research':
        await _runResearchInBackground(params, prefs, service, notifications);
        break;
      default:
        throw Exception('Unknown task type: $taskType');
    }

    await prefs.setString('background_task_status', 'completed');
    await prefs.setInt('background_task_progress', 100);

    // Show completion notification
    await _showCompletionNotification(
        notifications, 'Task completed successfully!');
  } catch (e) {
    debugPrint('[BackgroundAI] Task error: $e');
    await prefs.setString('background_task_status', 'error');
    await prefs.setString('background_task_error', e.toString());

    // Show error notification
    await _showErrorNotification(
        notifications, 'Task failed: ${e.toString().substring(0, 50)}...');
  }

  // Stop service after task completes
  await Future.delayed(const Duration(seconds: 2));
  service.stopSelf();
}

Future<void> _showProgressNotification(
  FlutterLocalNotificationsPlugin notifications,
  String content,
  int progress,
) async {
  await notifications.show(
    888,
    'Notebook LLM - Processing',
    content,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'notebook_llm_background',
        'Background Processing',
        channelDescription: 'AI processing tasks',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        showProgress: true,
        maxProgress: 100,
        progress: progress,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

Future<void> _showCompletionNotification(
  FlutterLocalNotificationsPlugin notifications,
  String content,
) async {
  await notifications.show(
    889,
    'Notebook LLM - Complete',
    content,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'notebook_llm_background',
        'Background Processing',
        channelDescription: 'AI processing tasks',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
  await notifications.cancel(888);
}

Future<void> _showErrorNotification(
  FlutterLocalNotificationsPlugin notifications,
  String content,
) async {
  await notifications.show(
    890,
    'Notebook LLM - Error',
    content,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'notebook_llm_background',
        'Background Processing',
        channelDescription: 'AI processing tasks',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
  await notifications.cancel(888);
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

/// Generate artifact in background
Future<void> _generateArtifactInBackground(
  Map<String, dynamic> params,
  SharedPreferences prefs,
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notifications,
) async {
  final prompt = params['prompt'] as String?;
  final apiKey = params['apiKey'] as String?;
  final model = params['model'] as String? ?? 'gemini-1.5-flash';
  final provider = params['provider'] as String? ?? 'gemini';

  if (prompt == null || apiKey == null) {
    throw Exception('Missing required parameters');
  }

  await _showProgressNotification(notifications, 'Generating artifact...', 30);

  String result;
  if (provider == 'openrouter') {
    result = await _callOpenRouterAPI(apiKey, model, prompt);
  } else {
    result = await _callGeminiAPI(apiKey, model, prompt);
  }

  await _showProgressNotification(notifications, 'Saving result...', 90);
  await prefs.setString('background_task_result', result);
}

/// Generate ebook chapter in background
Future<void> _generateEbookChapterInBackground(
  Map<String, dynamic> params,
  SharedPreferences prefs,
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notifications,
) async {
  final prompt = params['prompt'] as String?;
  final apiKey = params['apiKey'] as String?;
  final model = params['model'] as String? ?? 'gemini-1.5-flash';
  final chapterNumber = params['chapterNumber'] as int? ?? 1;

  if (prompt == null || apiKey == null) {
    throw Exception('Missing required parameters');
  }

  await _showProgressNotification(
      notifications, 'Writing chapter $chapterNumber...', 30);

  final result = await _callGeminiAPI(apiKey, model, prompt);

  await _showProgressNotification(notifications, 'Saving chapter...', 90);
  await prefs.setString('background_task_result', result);
}

/// Run research in background
Future<void> _runResearchInBackground(
  Map<String, dynamic> params,
  SharedPreferences prefs,
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notifications,
) async {
  final query = params['query'] as String?;
  final apiKey = params['apiKey'] as String?;

  final model = params['model'] as String? ?? 'gemini-1.5-flash';
  final provider = params['provider'] as String? ?? 'gemini';

  if (query == null || apiKey == null) {
    throw Exception('Missing required parameters');
  }

  await _showProgressNotification(notifications, 'Researching: $query', 30);

  // Simplified research prompt
  final prompt = '''
You are a research assistant. Research the following topic thoroughly:

Topic: $query

Provide comprehensive information including:
1. Overview and key concepts
2. Current state and developments
3. Important facts and statistics
4. Relevant sources and references

Format your response in clear, organized markdown.
''';

  final String result;
  if (provider == 'openrouter') {
    result = await _callOpenRouterAPI(apiKey, model, prompt);
  } else {
    result = await _callGeminiAPI(apiKey, model, prompt);
  }

  await _showProgressNotification(notifications, 'Saving research...', 90);
  await prefs.setString('background_task_result', result);
}

/// Call Gemini API directly (no Flutter dependencies)
Future<String> _callGeminiAPI(
    String apiKey, String model, String prompt) async {
  final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

  final response = await http
      .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 8192,
          }
        }),
      )
      .timeout(const Duration(minutes: 5));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'] ?? '';
  } else {
    throw Exception(
        'Gemini API error: ${response.statusCode} - ${response.body}');
  }
}

/// Call OpenRouter API directly
Future<String> _callOpenRouterAPI(
    String apiKey, String model, String prompt) async {
  final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

  final response = await http
      .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://notebookllm.app',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      )
      .timeout(const Duration(minutes: 5));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] ?? '';
  } else {
    throw Exception(
        'OpenRouter API error: ${response.statusCode} - ${response.body}');
  }
}

/// Global instance
final backgroundAIService = BackgroundAIService();
