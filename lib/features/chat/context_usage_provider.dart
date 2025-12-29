import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/ai/ai_models_provider.dart';
import '../sources/source_provider.dart';
import 'chat_provider.dart';

/// Represents the current context usage for the AI chat
class ContextUsage {
  final int usedChars;
  final int maxChars;
  final int sourcesCount;
  final int messagesCount;
  final String modelName;

  const ContextUsage({
    required this.usedChars,
    required this.maxChars,
    required this.sourcesCount,
    required this.messagesCount,
    required this.modelName,
  });

  /// Usage percentage (0.0 to 1.0)
  double get usagePercent =>
      maxChars > 0 ? (usedChars / maxChars).clamp(0.0, 1.0) : 0.0;

  /// Estimated tokens used (~4 chars per token)
  int get estimatedTokens => (usedChars / 4).ceil();

  /// Estimated max tokens
  int get estimatedMaxTokens => (maxChars / 4).ceil();

  /// Display string for usage
  String get usageDisplay => '${(usagePercent * 100).toStringAsFixed(0)}%';

  /// Is usage high (>70%)
  bool get isHigh => usagePercent > 0.7;

  /// Is usage critical (>90%)
  bool get isCritical => usagePercent > 0.9;
}

/// Provider that calculates context usage based on sources and chat history
final contextUsageProvider = Provider<ContextUsage>((ref) {
  final sources = ref.watch(sourceProvider);
  final messages = ref.watch(chatProvider);

  // Calculate used characters
  int usedChars = 0;

  // Sources context
  for (final source in sources) {
    usedChars += source.title.length;
    usedChars += source.type.length;
    usedChars +=
        source.content.length.clamp(0, 500); // Each source limited to 500 chars
    usedChars += 50; // Overhead for formatting
  }

  // Chat history (last 10 messages)
  final recentMessages =
      messages.length > 10 ? messages.sublist(messages.length - 10) : messages;
  for (final msg in recentMessages) {
    usedChars += msg.text.length;
    usedChars += 30; // Overhead for role labels
  }

  // Instructions overhead (~2000 chars)
  usedChars += 2000;

  return ContextUsage(
    usedChars: usedChars,
    maxChars: 30000, // Will be updated by async provider
    sourcesCount: sources.length,
    messagesCount: messages.length,
    modelName: 'Loading...',
  );
});

/// Async provider that includes model info for accurate limits
final contextUsageWithModelProvider = FutureProvider<ContextUsage>((ref) async {
  final sources = ref.watch(sourceProvider);
  final messages = ref.watch(chatProvider);
  final prefs = await SharedPreferences.getInstance();

  final modelName = prefs.getString('ai_model') ?? 'gemini-2.5-flash';

  // Determine max context based on model
  int maxChars = 30000; // Default

  try {
    // Try to get dynamic context window from available models
    final modelsAsync = await ref.read(availableModelsProvider.future);

    // Search in all providers
    bool found = false;
    for (final models in modelsAsync.values) {
      // m.id contains the API model string (e.g. gemini-1.5-flash) in AIModelOption
      final modelFound = models.where((m) => m.id == modelName).firstOrNull;
      if (modelFound != null) {
        // Convert tokens to chars (approx 4 chars per token)
        maxChars = modelFound.contextWindow * 4;
        found = true;
        break;
      }
    }

    if (!found) {
      // Fallback heuristics if model not found in DB list (e.g. outdated list)
      if (modelName.contains('gpt-3.5')) {
        maxChars = 12000;
      } else if (modelName.contains('gpt-4-turbo') ||
          modelName.contains('gpt-4o')) {
        maxChars = 100000;
      } else if (modelName.contains('gemini-1.5') ||
          modelName.contains('gemini-2')) {
        maxChars = 80000;
      } else if (modelName.contains('claude-3')) {
        maxChars = 80000;
      } else if (modelName.contains('llama') || modelName.contains('mistral')) {
        maxChars = 20000;
      }
    }
  } catch (e) {
    debugPrint('Error fetching context window for usage: $e');
  }

  // Calculate used characters
  int usedChars = 0;

  // Calculate available context for sources (60% of total)
  final maxSourceChars = (maxChars * 0.6).toInt();
  int sourceChars = 0;

  for (final source in sources) {
    final sourceSize = source.title.length +
        source.type.length +
        source.content.length.clamp(0, 500) +
        50;
    if (sourceChars + sourceSize <= maxSourceChars) {
      sourceChars += sourceSize;
    }
  }
  usedChars += sourceChars;

  // Calculate available context for history (20% of total)
  final maxHistoryChars = (maxChars * 0.2).toInt();
  int historyChars = 0;

  final recentMessages =
      messages.length > 10 ? messages.sublist(messages.length - 10) : messages;
  for (final msg in recentMessages) {
    final msgSize = msg.text.length + 30;
    if (historyChars + msgSize <= maxHistoryChars) {
      historyChars += msgSize;
    }
  }
  usedChars += historyChars;

  // Instructions overhead (~2000 chars)
  usedChars += 2000;

  return ContextUsage(
    usedChars: usedChars,
    maxChars: maxChars,
    sourcesCount: sources.length,
    messagesCount: messages.length,
    modelName: _formatModelName(modelName),
  );
});

String _formatModelName(String modelId) {
  // Extract readable name from model ID
  if (modelId.contains('/')) {
    return modelId.split('/').last;
  }
  return modelId;
}
