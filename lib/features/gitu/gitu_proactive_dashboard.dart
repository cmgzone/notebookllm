import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'models/proactive_insights_model.dart';
import 'proactive_insights_provider.dart';

/// Proactive Dashboard Widget
/// Displays aggregated insights, suggestions, and quick actions
class GituProactiveDashboard extends ConsumerWidget {
  const GituProactiveDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(proactiveInsightsProvider);
    final theme = Theme.of(context);

    if (state.isLoading && !state.hasData) {
      return _buildLoadingState(theme);
    }

    if (state.error != null && !state.hasData) {
      return _buildErrorState(theme, state.error!, ref);
    }

    final insights = state.insights ?? emptyProactiveInsights;

    // Compute low priority suggestions outside the collection literal
    final lowPrioritySuggestions = insights.activeSuggestions
        .where((s) => s.priority != SuggestionPriority.high)
        .toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(proactiveInsightsProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with last updated
            _buildHeader(context, theme, insights.lastUpdated, ref),
            const SizedBox(height: 16),

            // Connection Status Cards
            _buildConnectionCards(context, theme, insights),
            const SizedBox(height: 20),

            // High Priority Suggestions
            if (insights.highPrioritySuggestions.isNotEmpty) ...[
              _buildSuggestionsSection(
                  context, theme, insights.highPrioritySuggestions, ref),
              const SizedBox(height: 20),
            ],

            // Tasks Summary
            _buildTasksCard(context, theme, insights.tasksSummary),
            const SizedBox(height: 20),

            // Swarm Intelligence
            _ProactiveCard(
              icon: Icons.hub,
              iconColor: Colors.cyan,
              title: 'Swarm Intelligence',
              subtitle: 'Multi-agent orchestration',
              onTap: () => context.push('/gitu/swarm'),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Deploy and monitor autonomous agent swarms',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Pattern Insights
            if (insights.patterns.isNotEmpty) ...[
              _buildPatternsSection(context, theme, insights.patterns),
              const SizedBox(height: 20),
            ],

            // All Suggestions (lower priority)
            if (lowPrioritySuggestions.isNotEmpty) ...[
              _buildAllSuggestionsSection(
                  context, theme, lowPrioritySuggestions, ref),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading insights...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load insights',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  ref.read(proactiveInsightsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme,
      DateTime lastUpdated, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "What's Happening",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Updated ${_formatTimeAgo(lastUpdated)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () =>
              ref.read(proactiveInsightsProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildConnectionCards(
      BuildContext context, ThemeData theme, ProactiveInsights insights) {
    return Row(
      children: [
        Expanded(
          child: _GmailCard(summary: insights.gmailSummary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _WhatsAppCard(summary: insights.whatsappSummary),
        ),
      ],
    );
  }

  Widget _buildTasksCard(
      BuildContext context, ThemeData theme, TasksSummary summary) {
    return _ProactiveCard(
      icon: Icons.schedule,
      iconColor: Colors.indigo,
      title: 'Scheduled Tasks',
      subtitle:
          '${summary.totalEnabled} active, ${summary.pendingCount} pending',
      trailing: summary.failedTasksCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${summary.failedTasksCount} failed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      onTap: () => context.push('/gitu/scheduled-tasks'),
      child: summary.nextDueTask != null
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.upcoming,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Next: ${summary.nextDueTask!.name}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatTimeUntil(summary.nextDueTask!.nextRunAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildSuggestionsSection(
    BuildContext context,
    ThemeData theme,
    List<Suggestion> suggestions,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb, size: 20, color: Colors.amber[700]),
            const SizedBox(width: 8),
            Text(
              'Needs Attention',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...suggestions.map((s) => _SuggestionCard(
              suggestion: s,
              onDismiss: () => ref
                  .read(proactiveInsightsProvider.notifier)
                  .dismissSuggestion(s.id),
            )),
      ],
    );
  }

  Widget _buildPatternsSection(
    BuildContext context,
    ThemeData theme,
    List<PatternInsight> patterns,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insights, size: 20, color: theme.colorScheme.secondary),
            const SizedBox(width: 8),
            Text(
              'AI Insights',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: patterns.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _PatternCard(pattern: patterns[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildAllSuggestionsSection(
    BuildContext context,
    ThemeData theme,
    List<Suggestion> suggestions,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tips & Suggestions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...suggestions.take(3).map((s) => _SuggestionCard(
              suggestion: s,
              compact: true,
              onDismiss: () => ref
                  .read(proactiveInsightsProvider.notifier)
                  .dismissSuggestion(s.id),
            )),
      ],
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat.MMMd().format(time);
  }

  String _formatTimeUntil(DateTime time) {
    final diff = time.difference(DateTime.now());
    if (diff.isNegative) return 'overdue';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    return DateFormat.MMMd().format(time);
  }
}

// ==================== COMPONENT WIDGETS ====================

class _GmailCard extends StatelessWidget {
  final GmailSummary summary;

  const _GmailCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/gitu/gmail'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: summary.connected
                ? [Colors.red.shade400, Colors.red.shade600]
                : [Colors.grey.shade300, Colors.grey.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (summary.connected ? Colors.red : Colors.grey)
                  .withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.mail, color: Colors.white, size: 24),
                if (summary.connected && summary.unreadCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${summary.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Gmail',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              summary.connected
                  ? '${summary.unreadCount} unread'
                  : 'Not connected',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            if (summary.connected && summary.importantUnread > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${summary.importantUnread} important',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.yellow[200],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WhatsAppCard extends StatelessWidget {
  final WhatsAppSummary summary;

  const _WhatsAppCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/gitu/whatsapp'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: summary.connected
                ? [Colors.green.shade400, Colors.green.shade600]
                : [Colors.grey.shade300, Colors.grey.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (summary.connected ? Colors.green : Colors.grey)
                  .withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.chat, color: Colors.white, size: 24),
                if (summary.connected && summary.pendingMessages > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${summary.pendingMessages}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'WhatsApp',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              summary.connected
                  ? '${summary.unreadChats} chats'
                  : 'Not connected',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProactiveCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? child;
  final VoidCallback? onTap;

  const _ProactiveCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
              ],
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Suggestion suggestion;
  final bool compact;
  final VoidCallback? onDismiss;

  const _SuggestionCard({
    required this.suggestion,
    this.compact = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final priorityColor = switch (suggestion.priority) {
      SuggestionPriority.high => Colors.red,
      SuggestionPriority.medium => Colors.orange,
      SuggestionPriority.low => Colors.blue,
    };

    final typeIcon = switch (suggestion.type) {
      SuggestionType.email => Icons.mail_outline,
      SuggestionType.task => Icons.task_alt,
      SuggestionType.automation => Icons.auto_awesome,
      SuggestionType.reminder => Icons.alarm,
      SuggestionType.tip => Icons.lightbulb_outline,
    };

    return Dismissible(
      key: Key(suggestion.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: priorityColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: priorityColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(typeIcon, color: priorityColor, size: compact ? 16 : 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      suggestion.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (suggestion.action != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  final PatternInsight pattern;

  const _PatternCard({required this.pattern});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final typeIcon = switch (pattern.type) {
      PatternType.usage => Icons.bar_chart,
      PatternType.behavior => Icons.psychology,
      PatternType.opportunity => Icons.trending_up,
    };

    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.secondary.withValues(alpha: 0.1),
            theme.colorScheme.secondary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${(pattern.confidence * 100).toInt()}% confidence',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pattern.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            '${pattern.dataPoints} data points',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
