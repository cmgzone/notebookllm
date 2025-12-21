import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../sources/source.dart';
import '../notebook/notebook.dart';

class ExportService {
  /// Export notebook as Markdown
  static Future<String> exportNotebookAsMarkdown({
    required Notebook notebook,
    required List<Source> sources,
    String? summary,
  }) async {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('# ${notebook.title}');
    buffer.writeln();
    buffer.writeln('Generated: ${DateTime.now().toLocal()}');
    buffer.writeln('Total Sources: ${sources.length}');
    buffer.writeln();

    // Summary if available
    if (summary != null && summary.isNotEmpty) {
      buffer.writeln('## Summary');
      buffer.writeln();
      buffer.writeln(summary);
      buffer.writeln();
    }

    // Sources
    buffer.writeln('## Sources');
    buffer.writeln();

    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      buffer.writeln('### ${i + 1}. ${source.title}');
      buffer.writeln();
      buffer.writeln('**Type:** ${source.type}');
      buffer.writeln('**Added:** ${source.addedAt.toLocal()}');
      buffer.writeln();

      if (source.summary != null && source.summary!.isNotEmpty) {
        buffer.writeln('**Summary:**');
        buffer.writeln(source.summary);
        buffer.writeln();
      }

      buffer.writeln('**Content:**');
      buffer.writeln('```');
      buffer.writeln(source.content);
      buffer.writeln('```');
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Export and share notebook
  static Future<void> shareNotebook({
    required Notebook notebook,
    required List<Source> sources,
    String? summary,
  }) async {
    try {
      final markdown = await exportNotebookAsMarkdown(
        notebook: notebook,
        sources: sources,
        summary: summary,
      );

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${notebook.title.replaceAll(RegExp(r'[^\w\s-]'), '')}_${DateTime.now().millisecondsSinceEpoch}.md';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(markdown);

      // Share file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: notebook.title,
        text: 'Notebook: ${notebook.title}',
      );
    } catch (e) {
      debugPrint('Error sharing notebook: $e');
      rethrow;
    }
  }

  /// Export source as text
  static String exportSourceAsText(Source source) {
    final buffer = StringBuffer();

    buffer.writeln('Title: ${source.title}');
    buffer.writeln('Type: ${source.type}');
    buffer.writeln('Added: ${source.addedAt.toLocal()}');
    buffer.writeln();

    if (source.summary != null && source.summary!.isNotEmpty) {
      buffer.writeln('Summary:');
      buffer.writeln(source.summary);
      buffer.writeln();
    }

    buffer.writeln('Content:');
    buffer.writeln(source.content);

    return buffer.toString();
  }

  /// Share a single source
  static Future<void> shareSource(Source source) async {
    try {
      final text = exportSourceAsText(source);
      await Share.share(
        text,
        subject: source.title,
      );
    } catch (e) {
      debugPrint('Error sharing source: $e');
      rethrow;
    }
  }

  /// Export chat conversation
  static String exportChatConversation({
    required List<Map<String, dynamic>> messages,
    String? notebookTitle,
  }) {
    final buffer = StringBuffer();

    if (notebookTitle != null) {
      buffer.writeln('# Chat: $notebookTitle');
    } else {
      buffer.writeln('# Chat Conversation');
    }
    buffer.writeln();
    buffer.writeln('Exported: ${DateTime.now().toLocal()}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    for (final message in messages) {
      final role = message['role'] ?? 'unknown';
      final content = message['content'] ?? '';
      final timestamp = message['timestamp'];

      buffer.writeln('**${role.toUpperCase()}**');
      if (timestamp != null) {
        buffer.writeln('*$timestamp*');
      }
      buffer.writeln();
      buffer.writeln(content);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Share chat conversation
  static Future<void> shareChatConversation({
    required List<Map<String, dynamic>> messages,
    String? notebookTitle,
  }) async {
    try {
      final text = exportChatConversation(
        messages: messages,
        notebookTitle: notebookTitle,
      );

      await Share.share(
        text,
        subject: notebookTitle != null
            ? 'Chat: $notebookTitle'
            : 'Chat Conversation',
      );
    } catch (e) {
      debugPrint('Error sharing chat: $e');
      rethrow;
    }
  }
}
