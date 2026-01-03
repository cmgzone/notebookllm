import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/extensions/color_compat.dart';
import 'github_source_provider.dart';

/// A card widget for displaying GitHub sources with syntax highlighting,
/// update indicators, and quick actions.
///
/// Requirements: 1.4, 1.5, 6.3
class GitHubSourceCard extends ConsumerWidget {
  const GitHubSourceCard({
    super.key,
    required this.source,
    this.onTap,
    this.onDelete,
    this.onChat,
    this.showUpdateIndicator = true,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionChanged,
  });

  final GitHubSource source;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onChat;
  final bool showUpdateIndicator;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Watch for updates on this source
    final hasUpdates = showUpdateIndicator
        ? ref.watch(githubSourceHasUpdatesProvider(source.id))
        : false;
    final isRefreshing = ref.watch(githubSourceIsRefreshingProvider(source.id));

    final languageColor = _getLanguageColor(source.metadata.language);
    final languageIcon = _getLanguageIcon(source.metadata.language);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: scheme.primary, width: 2)
            : hasUpdates
                ? BorderSide(color: Colors.orange.shade400, width: 2)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: isSelectionMode
            ? () => onSelectionChanged?.call(!isSelected)
            : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isSelected
                    ? scheme.primary.withValues(alpha: 0.1)
                    : languageColor.withValues(alpha: 0.05),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    if (isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: onSelectionChanged,
                        ),
                      )
                    else
                      // GitHub icon badge
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: languageColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          languageIcon,
                          color: languageColor,
                          size: 24,
                        ),
                      ),
                    if (!isSelectionMode) const SizedBox(width: 12),
                    // Title and repo info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  source.title,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Update indicator
                              if (hasUpdates && !isSelectionMode)
                                _buildUpdateIndicator(context, ref),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // Language badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: languageColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  source.metadata.language.toUpperCase(),
                                  style: text.labelSmall?.copyWith(
                                    color: languageColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // GitHub badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.code,
                                      size: 12,
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'GitHub',
                                      style: text.labelSmall?.copyWith(
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Actions menu (hide in selection mode)
                    if (!isSelectionMode)
                      _buildActionsMenu(context, ref, scheme),
                  ],
                ),
                const SizedBox(height: 12),
                // Repository path
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 14,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${source.metadata.owner}/${source.metadata.repo}/${source.metadata.path}',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Code preview with syntax highlighting
                _buildCodePreview(context, scheme, text),
                const SizedBox(height: 12),
                // Footer
                _buildFooter(context, scheme, text, isRefreshing),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildUpdateIndicator(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'File has been updated on GitHub',
      child: InkWell(
        onTap: () => _refreshSource(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sync,
                size: 12,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                'Updated',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
        duration: 2000.ms, color: Colors.orange.withValues(alpha: 0.3));
  }

  Widget _buildActionsMenu(
      BuildContext context, WidgetRef ref, ColorScheme scheme) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: scheme.onSurface.withValues(alpha: 0.6),
      ),
      onSelected: (value) => _handleAction(context, ref, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view_github',
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 20),
              SizedBox(width: 8),
              Text('View on GitHub'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy_link',
          child: Row(
            children: [
              Icon(Icons.link, size: 20),
              SizedBox(width: 8),
              Text('Copy Link'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 20),
              SizedBox(width: 8),
              Text('Refresh'),
            ],
          ),
        ),
        if (onChat != null)
          const PopupMenuItem(
            value: 'chat',
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 20),
                SizedBox(width: 8),
                Text('Chat with Agent'),
              ],
            ),
          ),
        if (onDelete != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCodePreview(
      BuildContext context, ColorScheme scheme, TextTheme text) {
    // Show first few lines of code with syntax highlighting
    final lines = source.content.split('\n').take(5).toList();
    final hasMore = source.content.split('\n').length > 5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // VS Code dark theme background
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line numbers and code
          ...lines.asMap().entries.map((entry) {
            final lineNum = entry.key + 1;
            final line = entry.value;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$lineNum',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF858585),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.isEmpty ? ' ' : line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: _getSyntaxColor(line, source.metadata.language),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '... ${source.content.split('\n').length - 5} more lines',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: scheme.primary.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ColorScheme scheme, TextTheme text,
      bool isRefreshing) {
    return Row(
      children: [
        // Branch info
        Icon(
          Icons.call_split,
          size: 14,
          color: scheme.hintText,
        ),
        const SizedBox(width: 4),
        Text(
          source.metadata.branch,
          style: text.labelSmall?.copyWith(
            color: scheme.hintText,
          ),
        ),
        const SizedBox(width: 12),
        // File size
        Icon(
          Icons.storage,
          size: 14,
          color: scheme.hintText,
        ),
        const SizedBox(width: 4),
        Text(
          _formatFileSize(source.metadata.size),
          style: text.labelSmall?.copyWith(
            color: scheme.hintText,
          ),
        ),
        const Spacer(),
        // Refresh indicator or AI Ready badge
        if (isRefreshing)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Refreshing...',
                style: text.labelSmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: scheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                'AI Ready',
                style: text.labelSmall?.copyWith(
                  color: scheme.primary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'view_github':
        _openGitHub(context);
        break;
      case 'copy_link':
        _copyLink(context);
        break;
      case 'refresh':
        _refreshSource(context, ref);
        break;
      case 'chat':
        onChat?.call();
        break;
      case 'delete':
        onDelete?.call();
        break;
    }
  }

  Future<void> _openGitHub(BuildContext context) async {
    final url = source.metadata.githubUrl;
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open GitHub')),
          );
        }
      }
    }
  }

  void _copyLink(BuildContext context) {
    final url = source.metadata.githubUrl;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _refreshSource(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(githubSourceProvider.notifier).refreshSource(source.id);

    if (context.mounted) {
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Source refreshed'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final error = ref.read(githubSourceErrorProvider(source.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to refresh'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getLanguageColor(String language) {
    switch (language.toLowerCase()) {
      case 'dart':
        return const Color(0xFF00B4AB);
      case 'typescript':
      case 'ts':
        return const Color(0xFF3178C6);
      case 'javascript':
      case 'js':
        return const Color(0xFFF7DF1E);
      case 'python':
      case 'py':
        return const Color(0xFF3776AB);
      case 'java':
        return const Color(0xFFB07219);
      case 'kotlin':
      case 'kt':
        return const Color(0xFFA97BFF);
      case 'swift':
        return const Color(0xFFFA7343);
      case 'go':
        return const Color(0xFF00ADD8);
      case 'rust':
      case 'rs':
        return const Color(0xFFDEA584);
      case 'c':
        return const Color(0xFF555555);
      case 'cpp':
      case 'c++':
        return const Color(0xFFF34B7D);
      case 'csharp':
      case 'cs':
        return const Color(0xFF178600);
      case 'ruby':
      case 'rb':
        return const Color(0xFF701516);
      case 'php':
        return const Color(0xFF4F5D95);
      case 'html':
        return const Color(0xFFE34C26);
      case 'css':
        return const Color(0xFF563D7C);
      case 'json':
        return const Color(0xFF292929);
      case 'yaml':
      case 'yml':
        return const Color(0xFFCB171E);
      case 'markdown':
      case 'md':
        return const Color(0xFF083FA1);
      case 'sql':
        return const Color(0xFFE38C00);
      default:
        return Colors.grey;
    }
  }

  IconData _getLanguageIcon(String language) {
    switch (language.toLowerCase()) {
      case 'dart':
        return Icons.flutter_dash;
      case 'typescript':
      case 'ts':
      case 'javascript':
      case 'js':
        return Icons.javascript;
      case 'python':
      case 'py':
        return Icons.code;
      case 'java':
      case 'kotlin':
      case 'kt':
        return Icons.android;
      case 'swift':
        return Icons.apple;
      case 'html':
      case 'css':
        return Icons.web;
      case 'json':
      case 'yaml':
      case 'yml':
        return Icons.data_object;
      case 'markdown':
      case 'md':
        return Icons.description;
      case 'sql':
        return Icons.storage;
      default:
        return Icons.code;
    }
  }

  Color _getSyntaxColor(String line, String language) {
    // Basic syntax highlighting based on common patterns
    final trimmed = line.trim();

    // Comments
    if (trimmed.startsWith('//') ||
        trimmed.startsWith('#') ||
        trimmed.startsWith('/*')) {
      return const Color(0xFF6A9955); // Green for comments
    }

    // Strings
    if (trimmed.contains('"') || trimmed.contains("'")) {
      return const Color(0xFFCE9178); // Orange for strings
    }

    // Keywords
    final keywords = [
      'import',
      'export',
      'class',
      'function',
      'const',
      'let',
      'var',
      'if',
      'else',
      'for',
      'while',
      'return',
      'async',
      'await',
      'def',
      'from',
      'interface',
      'type',
      'enum',
      'struct'
    ];
    for (final keyword in keywords) {
      if (trimmed.startsWith('$keyword ') || trimmed.contains(' $keyword ')) {
        return const Color(0xFF569CD6); // Blue for keywords
      }
    }

    // Default code color
    return const Color(0xFFD4D4D4);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
