import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Detects GitHub-related actions in AI responses
/// Requirements: 6.1 - Detect issue suggestions and show "Create Issue" button
/// Requirements: 6.2 - Detect code suggestions and show "Copy Code" button
class GitHubActionDetector {
  /// Detect if the AI response contains an issue suggestion
  /// Returns the parsed issue data if found
  static IssueSuggestion? detectIssueSuggestion(String text) {
    // Pattern 1: Explicit issue suggestion format
    // [[SUGGEST_ISSUE: title | body]]
    final explicitPattern = RegExp(
      r'\[\[SUGGEST_ISSUE:\s*([^|]+)\s*\|\s*(.+?)\]\]',
      dotAll: true,
    );
    final explicitMatch = explicitPattern.firstMatch(text);
    if (explicitMatch != null) {
      return IssueSuggestion(
        title: explicitMatch.group(1)?.trim() ?? '',
        body: explicitMatch.group(2)?.trim() ?? '',
        isExplicit: true,
      );
    }

    // Pattern 2: Natural language issue suggestion
    // Look for phrases like "I suggest creating an issue", "You should file a bug", etc.
    final issueKeywords = [
      'create an issue',
      'file an issue',
      'open an issue',
      'report this bug',
      'file a bug',
      'create a bug report',
      'suggest creating an issue',
      'recommend filing an issue',
      'should create an issue',
      'could create an issue',
    ];

    final lowerText = text.toLowerCase();
    for (final keyword in issueKeywords) {
      if (lowerText.contains(keyword)) {
        // Try to extract a suggested title from the context
        final title = _extractSuggestedTitle(text);
        return IssueSuggestion(
          title: title ?? 'Issue from AI suggestion',
          body: _extractIssueBody(text),
          isExplicit: false,
        );
      }
    }

    return null;
  }

  /// Detect if the AI response contains code suggestions
  /// Returns a list of code blocks found
  static List<CodeSuggestion> detectCodeSuggestions(String text) {
    final suggestions = <CodeSuggestion>[];

    // Pattern: Markdown code blocks with optional language
    final codeBlockPattern = RegExp(
      r'```(\w*)\n([\s\S]*?)```',
      multiLine: true,
    );

    final matches = codeBlockPattern.allMatches(text);
    for (final match in matches) {
      final language = match.group(1) ?? '';
      final code = match.group(2)?.trim() ?? '';

      if (code.isNotEmpty) {
        // Determine if this is a fix/change suggestion
        final isFix = _isCodeFix(text, match.start);

        suggestions.add(CodeSuggestion(
          code: code,
          language: language,
          isFix: isFix,
          description: _extractCodeDescription(text, match.start),
        ));
      }
    }

    return suggestions;
  }

  /// Extract a suggested title from the text
  static String? _extractSuggestedTitle(String text) {
    // Look for patterns like "titled 'X'" or "called 'X'" or "named 'X'"
    final patterns = <RegExp>[
      RegExp(r'''titled\s+["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''called\s+["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''named\s+["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''title:\s*["']?([^"'.\n]+)["']?''', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    return null;
  }

  /// Extract issue body from the text
  static String _extractIssueBody(String text) {
    // Remove code blocks for cleaner body
    final cleanText = text.replaceAll(RegExp(r'```[\s\S]*?```'), '[code]');

    // Limit to reasonable length
    if (cleanText.length > 500) {
      return '${cleanText.substring(0, 500)}...';
    }
    return cleanText;
  }

  /// Check if a code block appears to be a fix/change suggestion
  static bool _isCodeFix(String text, int codeBlockStart) {
    // Look at text before the code block
    final textBefore = text.substring(0, codeBlockStart).toLowerCase();
    final lastChars = textBefore.length > 200
        ? textBefore.substring(textBefore.length - 200)
        : textBefore;

    final fixKeywords = [
      'fix',
      'change',
      'modify',
      'update',
      'replace',
      'should be',
      'instead',
      'correct',
      'here is the',
      'try this',
      'use this',
    ];

    return fixKeywords.any((keyword) => lastChars.contains(keyword));
  }

  /// Extract description for a code block
  static String _extractCodeDescription(String text, int codeBlockStart) {
    // Get text before the code block
    final textBefore = text.substring(0, codeBlockStart);
    final lines = textBefore.split('\n');

    // Get the last non-empty line before the code block
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i].trim();
      if (line.isNotEmpty && !line.startsWith('```')) {
        // Limit length
        if (line.length > 100) {
          return '${line.substring(0, 100)}...';
        }
        return line;
      }
    }

    return 'Code suggestion';
  }
}

/// Represents a detected issue suggestion
class IssueSuggestion {
  final String title;
  final String body;
  final bool isExplicit;
  final List<String> labels;

  const IssueSuggestion({
    required this.title,
    required this.body,
    this.isExplicit = false,
    this.labels = const [],
  });
}

/// Represents a detected code suggestion
class CodeSuggestion {
  final String code;
  final String language;
  final bool isFix;
  final String description;

  const CodeSuggestion({
    required this.code,
    required this.language,
    this.isFix = false,
    this.description = '',
  });
}

/// Widget that displays GitHub action buttons for AI responses
/// Requirements: 6.1, 6.2
class GitHubActionButtons extends ConsumerWidget {
  final String messageText;
  final VoidCallback? onCreateIssue;
  final Function(String code, String language)? onCopyCode;

  const GitHubActionButtons({
    super.key,
    required this.messageText,
    this.onCreateIssue,
    this.onCopyCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    // Detect actions
    final issueSuggestion =
        GitHubActionDetector.detectIssueSuggestion(messageText);
    final codeSuggestions =
        GitHubActionDetector.detectCodeSuggestions(messageText);

    // If no actions detected, return empty
    if (issueSuggestion == null && codeSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Create Issue button
          if (issueSuggestion != null)
            _ActionButton(
              icon: LucideIcons.gitPullRequestDraft,
              label: 'Create Issue',
              color: Colors.green,
              onTap: onCreateIssue,
              tooltip: 'Create a GitHub issue from this suggestion',
            ),

          // Copy Code buttons
          for (int i = 0; i < codeSuggestions.length && i < 3; i++)
            _ActionButton(
              icon: LucideIcons.copy,
              label: codeSuggestions.length == 1
                  ? 'Copy Code'
                  : 'Copy Code ${i + 1}',
              color: scheme.primary,
              onTap: () {
                final suggestion = codeSuggestions[i];
                Clipboard.setData(ClipboardData(text: suggestion.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      suggestion.language.isNotEmpty
                          ? 'Copied ${suggestion.language} code to clipboard'
                          : 'Copied code to clipboard',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
                onCopyCode?.call(suggestion.code, suggestion.language);
              },
              tooltip: codeSuggestions[i].description,
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
