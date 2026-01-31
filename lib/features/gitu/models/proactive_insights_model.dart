/// Data models for Gitu proactive insights feature
/// These models map to the backend gituProactiveService responses
library proactive_insights_model;

import 'package:flutter/foundation.dart';

// ==================== GMAIL SUMMARY ====================

class GmailSummary {
  final bool connected;
  final String? email;
  final int unreadCount;
  final int importantUnread;
  final List<RecentEmail> recentEmails;
  final DateTime? lastSyncAt;

  const GmailSummary({
    required this.connected,
    this.email,
    this.unreadCount = 0,
    this.importantUnread = 0,
    this.recentEmails = const [],
    this.lastSyncAt,
  });

  factory GmailSummary.fromJson(Map<String, dynamic> json) {
    return GmailSummary(
      connected: json['connected'] ?? false,
      email: json['email'],
      unreadCount: json['unreadCount'] ?? 0,
      importantUnread: json['importantUnread'] ?? 0,
      recentEmails: (json['recentEmails'] as List?)
              ?.map((e) => RecentEmail.fromJson(e))
              .toList() ??
          [],
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.tryParse(json['lastSyncAt'])
          : null,
    );
  }

  GmailSummary copyWith({
    bool? connected,
    String? email,
    int? unreadCount,
    int? importantUnread,
    List<RecentEmail>? recentEmails,
    DateTime? lastSyncAt,
  }) {
    return GmailSummary(
      connected: connected ?? this.connected,
      email: email ?? this.email,
      unreadCount: unreadCount ?? this.unreadCount,
      importantUnread: importantUnread ?? this.importantUnread,
      recentEmails: recentEmails ?? this.recentEmails,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

class RecentEmail {
  final String id;
  final String from;
  final String subject;
  final String snippet;
  final String date;
  final bool isImportant;

  const RecentEmail({
    required this.id,
    required this.from,
    required this.subject,
    required this.snippet,
    required this.date,
    this.isImportant = false,
  });

  factory RecentEmail.fromJson(Map<String, dynamic> json) {
    return RecentEmail(
      id: json['id'] ?? '',
      from: json['from'] ?? 'Unknown',
      subject: json['subject'] ?? '(No Subject)',
      snippet: json['snippet'] ?? '',
      date: json['date'] ?? '',
      isImportant: json['isImportant'] ?? false,
    );
  }
}

// ==================== WHATSAPP SUMMARY ====================

class WhatsAppSummary {
  final bool connected;
  final String? phoneNumber;
  final int unreadChats;
  final int pendingMessages;
  final DateTime? lastMessageAt;

  const WhatsAppSummary({
    required this.connected,
    this.phoneNumber,
    this.unreadChats = 0,
    this.pendingMessages = 0,
    this.lastMessageAt,
  });

  factory WhatsAppSummary.fromJson(Map<String, dynamic> json) {
    return WhatsAppSummary(
      connected: json['connected'] ?? false,
      phoneNumber: json['phoneNumber'],
      unreadChats: json['unreadChats'] ?? 0,
      pendingMessages: json['pendingMessages'] ?? 0,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'])
          : null,
    );
  }

  WhatsAppSummary copyWith({
    bool? connected,
    String? phoneNumber,
    int? unreadChats,
    int? pendingMessages,
    DateTime? lastMessageAt,
  }) {
    return WhatsAppSummary(
      connected: connected ?? this.connected,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      unreadChats: unreadChats ?? this.unreadChats,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }
}

// ==================== TASKS SUMMARY ====================

class TasksSummary {
  final int totalEnabled;
  final int pendingCount;
  final NextDueTask? nextDueTask;
  final List<RecentExecution> recentExecutions;
  final int failedTasksCount;

  const TasksSummary({
    this.totalEnabled = 0,
    this.pendingCount = 0,
    this.nextDueTask,
    this.recentExecutions = const [],
    this.failedTasksCount = 0,
  });

  factory TasksSummary.fromJson(Map<String, dynamic> json) {
    return TasksSummary(
      totalEnabled: json['totalEnabled'] ?? 0,
      pendingCount: json['pendingCount'] ?? 0,
      nextDueTask: json['nextDueTask'] != null
          ? NextDueTask.fromJson(json['nextDueTask'])
          : null,
      recentExecutions: (json['recentExecutions'] as List?)
              ?.map((e) => RecentExecution.fromJson(e))
              .toList() ??
          [],
      failedTasksCount: json['failedTasksCount'] ?? 0,
    );
  }
}

class NextDueTask {
  final String id;
  final String name;
  final DateTime nextRunAt;

  const NextDueTask({
    required this.id,
    required this.name,
    required this.nextRunAt,
  });

  factory NextDueTask.fromJson(Map<String, dynamic> json) {
    return NextDueTask(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nextRunAt: DateTime.tryParse(json['nextRunAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class RecentExecution {
  final String taskName;
  final bool success;
  final DateTime executedAt;

  const RecentExecution({
    required this.taskName,
    required this.success,
    required this.executedAt,
  });

  factory RecentExecution.fromJson(Map<String, dynamic> json) {
    return RecentExecution(
      taskName: json['taskName'] ?? '',
      success: json['success'] ?? false,
      executedAt: DateTime.tryParse(json['executedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

// ==================== SUGGESTIONS ====================

enum SuggestionType { email, task, automation, reminder, tip }

enum SuggestionPriority { high, medium, low }

class Suggestion {
  final String id;
  final SuggestionType type;
  final SuggestionPriority priority;
  final String title;
  final String description;
  final SuggestionAction? action;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const Suggestion({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    this.action,
    required this.createdAt,
    this.expiresAt,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['id'] ?? '',
      type: _parseSuggestionType(json['type']),
      priority: _parseSuggestionPriority(json['priority']),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      action: json['action'] != null
          ? SuggestionAction.fromJson(json['action'])
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
    );
  }

  static SuggestionType _parseSuggestionType(String? type) {
    switch (type) {
      case 'email':
        return SuggestionType.email;
      case 'task':
        return SuggestionType.task;
      case 'automation':
        return SuggestionType.automation;
      case 'reminder':
        return SuggestionType.reminder;
      default:
        return SuggestionType.tip;
    }
  }

  static SuggestionPriority _parseSuggestionPriority(String? priority) {
    switch (priority) {
      case 'high':
        return SuggestionPriority.high;
      case 'medium':
        return SuggestionPriority.medium;
      default:
        return SuggestionPriority.low;
    }
  }

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

class SuggestionAction {
  final String type;
  final Map<String, dynamic>? params;

  const SuggestionAction({
    required this.type,
    this.params,
  });

  factory SuggestionAction.fromJson(Map<String, dynamic> json) {
    return SuggestionAction(
      type: json['type'] ?? '',
      params: json['params'] as Map<String, dynamic>?,
    );
  }
}

// ==================== PATTERNS ====================

enum PatternType { usage, behavior, opportunity }

class PatternInsight {
  final String id;
  final PatternType type;
  final String title;
  final String description;
  final double confidence;
  final int dataPoints;
  final String? suggestedAction;
  final DateTime createdAt;

  const PatternInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.confidence,
    required this.dataPoints,
    this.suggestedAction,
    required this.createdAt,
  });

  factory PatternInsight.fromJson(Map<String, dynamic> json) {
    return PatternInsight(
      id: json['id'] ?? '',
      type: _parsePatternType(json['type']),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      dataPoints: json['dataPoints'] ?? 0,
      suggestedAction: json['suggestedAction'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  static PatternType _parsePatternType(String? type) {
    switch (type) {
      case 'usage':
        return PatternType.usage;
      case 'behavior':
        return PatternType.behavior;
      case 'opportunity':
        return PatternType.opportunity;
      default:
        return PatternType.usage;
    }
  }
}

// ==================== AGGREGATED INSIGHTS ====================

@immutable
class ProactiveInsights {
  final String userId;
  final GmailSummary gmailSummary;
  final WhatsAppSummary whatsappSummary;
  final TasksSummary tasksSummary;
  final List<Suggestion> suggestions;
  final List<PatternInsight> patterns;
  final DateTime lastUpdated;

  const ProactiveInsights({
    required this.userId,
    required this.gmailSummary,
    required this.whatsappSummary,
    required this.tasksSummary,
    this.suggestions = const [],
    this.patterns = const [],
    required this.lastUpdated,
  });

  factory ProactiveInsights.fromJson(Map<String, dynamic> json) {
    return ProactiveInsights(
      userId: json['userId'] ?? '',
      gmailSummary: GmailSummary.fromJson(json['gmailSummary'] ?? {}),
      whatsappSummary: WhatsAppSummary.fromJson(json['whatsappSummary'] ?? {}),
      tasksSummary: TasksSummary.fromJson(json['tasksSummary'] ?? {}),
      suggestions: (json['suggestions'] as List?)
              ?.map((e) => Suggestion.fromJson(e))
              .toList() ??
          [],
      patterns: (json['patterns'] as List?)
              ?.map((e) => PatternInsight.fromJson(e))
              .toList() ??
          [],
      lastUpdated:
          DateTime.tryParse(json['lastUpdated'] ?? '') ?? DateTime.now(),
    );
  }

  /// Get only active (non-expired) suggestions
  List<Suggestion> get activeSuggestions =>
      suggestions.where((s) => !s.isExpired).toList();

  /// Get high-priority suggestions
  List<Suggestion> get highPrioritySuggestions => suggestions
      .where((s) => s.priority == SuggestionPriority.high && !s.isExpired)
      .toList();

  /// Total notification count for badge
  int get totalNotificationCount {
    int count = 0;
    if (gmailSummary.connected) count += gmailSummary.unreadCount;
    if (whatsappSummary.connected) count += whatsappSummary.pendingMessages;
    count += highPrioritySuggestions.length;
    return count;
  }

  /// Check if any connections need attention
  bool get needsAttention =>
      tasksSummary.failedTasksCount > 0 ||
      highPrioritySuggestions.isNotEmpty ||
      gmailSummary.importantUnread > 3;

  ProactiveInsights copyWith({
    String? userId,
    GmailSummary? gmailSummary,
    WhatsAppSummary? whatsappSummary,
    TasksSummary? tasksSummary,
    List<Suggestion>? suggestions,
    List<PatternInsight>? patterns,
    DateTime? lastUpdated,
  }) {
    return ProactiveInsights(
      userId: userId ?? this.userId,
      gmailSummary: gmailSummary ?? this.gmailSummary,
      whatsappSummary: whatsappSummary ?? this.whatsappSummary,
      tasksSummary: tasksSummary ?? this.tasksSummary,
      suggestions: suggestions ?? this.suggestions,
      patterns: patterns ?? this.patterns,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Empty state for initial loading
ProactiveInsights get emptyProactiveInsights => ProactiveInsights(
      userId: '',
      gmailSummary: const GmailSummary(connected: false),
      whatsappSummary: const WhatsAppSummary(connected: false),
      tasksSummary: const TasksSummary(),
      suggestions: const [],
      patterns: const [],
      lastUpdated: DateTime.now(),
    );
