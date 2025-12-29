import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'context_usage_provider.dart';

/// A compact widget that shows context usage in the chat header
class ContextUsageIndicator extends ConsumerWidget {
  const ContextUsageIndicator({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(contextUsageWithModelProvider);
    final scheme = Theme.of(context).colorScheme;

    return usageAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (usage) {
        final color = usage.isCritical
            ? Colors.red
            : usage.isHigh
                ? Colors.orange
                : Colors.green;

        if (compact) {
          return Tooltip(
            message: 'Context: ${usage.usageDisplay} used\n'
                '${usage.estimatedTokens}/${usage.estimatedMaxTokens} tokens\n'
                '${usage.sourcesCount} sources, ${usage.messagesCount} messages\n'
                'Model: ${usage.modelName}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.gauge, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    usage.usageDisplay,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Expanded view
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.gauge, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    'Context Usage',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    usage.usageDisplay,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: usage.usagePercent,
                  backgroundColor: scheme.outline.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${usage.estimatedTokens}/${usage.estimatedMaxTokens} tokens',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    '${usage.sourcesCount} sources • ${usage.messagesCount} msgs',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Model: ${usage.modelName}',
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A dialog that shows detailed context usage information
class ContextUsageDialog extends ConsumerWidget {
  const ContextUsageDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(contextUsageWithModelProvider);
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(LucideIcons.gauge, color: scheme.primary),
          const SizedBox(width: 12),
          const Text('Context Window Usage'),
        ],
      ),
      content: usageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
        data: (usage) {
          final color = usage.isCritical
              ? Colors.red
              : usage.isHigh
                  ? Colors.orange
                  : Colors.green;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usage.usagePercent,
                  backgroundColor: scheme.outline.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${usage.usageDisplay} of context used',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Stats
              _StatRow(
                icon: LucideIcons.brain,
                label: 'Estimated Tokens',
                value: '${usage.estimatedTokens} / ${usage.estimatedMaxTokens}',
              ),
              const SizedBox(height: 8),
              _StatRow(
                icon: LucideIcons.fileText,
                label: 'Sources',
                value: '${usage.sourcesCount} files',
              ),
              const SizedBox(height: 8),
              _StatRow(
                icon: LucideIcons.messageSquare,
                label: 'Messages',
                value: '${usage.messagesCount} messages',
              ),
              const SizedBox(height: 8),
              _StatRow(
                icon: LucideIcons.bot,
                label: 'Model',
                value: usage.modelName,
              ),

              const SizedBox(height: 16),

              // Tips
              if (usage.isHigh) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.alertTriangle,
                              size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 8),
                          Text(
                            'High Usage Tips',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Start a new conversation to clear history\n'
                        '• Remove unused sources from notebook\n'
                        '• Switch to a model with larger context\n'
                        '  (Gemini 1.5 Pro, GPT-4 Turbo, Claude 3)',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7))),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// Show the context usage dialog
void showContextUsageDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const ContextUsageDialog(),
  );
}
