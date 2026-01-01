// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/api/api_service.dart';
import '../../theme/app_theme.dart';
import '../../core/extensions/color_compat.dart';
import '../../ui/widgets/agent_notebook_badge.dart';
import 'api_tokens_section.dart';

/// Model for agent session data
/// Requirements: 4.1, 4.4
class AgentSession {
  final String id;
  final String agentName;
  final String agentIdentifier;
  final String status;
  final String? notebookId;
  final String? notebookTitle;
  final DateTime lastActivity;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const AgentSession({
    required this.id,
    required this.agentName,
    required this.agentIdentifier,
    required this.status,
    this.notebookId,
    this.notebookTitle,
    required this.lastActivity,
    required this.createdAt,
    this.metadata,
  });

  factory AgentSession.fromJson(Map<String, dynamic> json) {
    return AgentSession(
      id: json['id'] as String,
      agentName: json['agent_name'] as String? ??
          json['agentName'] as String? ??
          'Unknown Agent',
      agentIdentifier: json['agent_identifier'] as String? ??
          json['agentIdentifier'] as String? ??
          '',
      status: json['status'] as String? ?? 'active',
      notebookId:
          json['notebook_id'] as String? ?? json['notebookId'] as String?,
      notebookTitle:
          json['notebook_title'] as String? ?? json['notebookTitle'] as String?,
      lastActivity: json['last_activity'] != null
          ? DateTime.parse(json['last_activity'] as String)
          : json['lastActivity'] != null
              ? DateTime.parse(json['lastActivity'] as String)
              : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired';
  bool get isDisconnected => status == 'disconnected';
}

/// State for agent connections
class AgentConnectionsState {
  final List<AgentSession> sessions;
  final bool isLoading;
  final String? error;

  const AgentConnectionsState({
    this.sessions = const [],
    this.isLoading = false,
    this.error,
  });

  AgentConnectionsState copyWith({
    List<AgentSession>? sessions,
    bool? isLoading,
    String? error,
  }) {
    return AgentConnectionsState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get activeCount => sessions.where((s) => s.isActive).length;
  int get expiredCount => sessions.where((s) => s.isExpired).length;
  int get disconnectedCount => sessions.where((s) => s.isDisconnected).length;
}

/// Provider for managing agent connections
/// Requirements: 4.1, 4.4
class AgentConnectionsNotifier extends StateNotifier<AgentConnectionsState> {
  final Ref ref;

  AgentConnectionsNotifier(this.ref) : super(const AgentConnectionsState()) {
    loadSessions();
  }

  /// Load all agent sessions from the API
  Future<void> loadSessions() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiService = ref.read(apiServiceProvider);
      final notebooks = await apiService.getAgentNotebooks();

      final sessions = notebooks.map((n) {
        // Extract agent session info from notebook metadata
        return AgentSession(
          id: n['agent_session_id'] as String? ?? n['id'] as String,
          agentName: n['agent_name'] as String? ??
              n['agentName'] as String? ??
              'Unknown Agent',
          agentIdentifier: n['agent_identifier'] as String? ??
              n['agentIdentifier'] as String? ??
              '',
          status: n['agent_status'] as String? ??
              n['agentStatus'] as String? ??
              'active',
          notebookId: n['id'] as String?,
          notebookTitle: n['title'] as String?,
          lastActivity: n['last_activity'] != null
              ? DateTime.parse(n['last_activity'] as String)
              : n['updated_at'] != null
                  ? DateTime.parse(n['updated_at'] as String)
                  : DateTime.now(),
          createdAt: n['created_at'] != null
              ? DateTime.parse(n['created_at'] as String)
              : DateTime.now(),
          metadata: n['metadata'] as Map<String, dynamic>?,
        );
      }).toList();

      state = state.copyWith(
        sessions: sessions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Disconnect an agent session
  /// Requirements: 4.3
  Future<bool> disconnectSession(String sessionId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.disconnectAgent(sessionId);

      // Update local state
      final updatedSessions = state.sessions.map((s) {
        if (s.id == sessionId) {
          return AgentSession(
            id: s.id,
            agentName: s.agentName,
            agentIdentifier: s.agentIdentifier,
            status: 'disconnected',
            notebookId: s.notebookId,
            notebookTitle: s.notebookTitle,
            lastActivity: DateTime.now(),
            createdAt: s.createdAt,
            metadata: s.metadata,
          );
        }
        return s;
      }).toList();

      state = state.copyWith(sessions: updatedSessions);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Refresh sessions
  Future<void> refresh() async {
    await loadSessions();
  }
}

/// Provider for agent connections
final agentConnectionsProvider =
    StateNotifierProvider<AgentConnectionsNotifier, AgentConnectionsState>(
  (ref) => AgentConnectionsNotifier(ref),
);

/// Screen showing all connected coding agents
/// Requirements: 4.1, 4.4
class AgentConnectionsScreen extends ConsumerWidget {
  const AgentConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(agentConnectionsProvider);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.premiumGradient,
          ),
        ),
        title: const Text(
          'Agent Connections',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(agentConnectionsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // API Tokens Section - always visible
            const ApiTokensSection(),
            // Agent Sessions Section
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null)
              _buildErrorState(context, ref, state.error!)
            else if (state.sessions.isEmpty)
              _buildEmptyState(context, scheme)
            else
              _buildSessionsList(context, ref, state, scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertCircle,
              size: 64,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load agents',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: scheme.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(agentConnectionsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.terminal,
                size: 64,
                color: scheme.primary,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              'No Connected Agents',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 12),
            Text(
              'Connect a coding agent like Claude, Kiro, or Cursor via MCP to see them here.',
              style: TextStyle(color: scheme.secondaryText),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                // Show info dialog about connecting agents
                _showConnectionInfoDialog(context);
              },
              icon: const Icon(LucideIcons.helpCircle),
              label: const Text('How to Connect'),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }

  void _showConnectionInfoDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(LucideIcons.terminal, size: 48, color: scheme.primary),
        title: const Text('Connecting Coding Agents'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To connect a coding agent:\n\n'
                '1. Configure the MCP server in your coding agent (Claude, Kiro, Cursor, etc.)\n\n'
                '2. Use the create_agent_notebook tool to create a dedicated notebook\n\n'
                '3. Save verified code using save_code_with_context\n\n'
                '4. Your agent will appear here once connected!',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(
    BuildContext context,
    WidgetRef ref,
    AgentConnectionsState state,
    ColorScheme scheme,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.read(agentConnectionsProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats summary
          _buildStatsSummary(context, state, scheme),
          const SizedBox(height: 24),
          // Sessions list
          ...state.sessions.asMap().entries.map((entry) {
            final index = entry.key;
            final session = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AgentSessionCard(
                session: session,
                onDisconnect: () =>
                    _showDisconnectDialog(context, ref, session),
                onViewNotebook: session.notebookId != null
                    ? () => context.push('/notebook/${session.notebookId}')
                    : null,
              ).animate().fadeIn(delay: Duration(milliseconds: index * 100)),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(
    BuildContext context,
    AgentConnectionsState state,
    ColorScheme scheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.1),
            scheme.secondary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: LucideIcons.checkCircle,
            label: 'Active',
            value: state.activeCount.toString(),
            color: const Color(0xFF22C55E),
          ),
          _StatItem(
            icon: LucideIcons.clock,
            label: 'Expired',
            value: state.expiredCount.toString(),
            color: const Color(0xFFF59E0B),
          ),
          _StatItem(
            icon: LucideIcons.xCircle,
            label: 'Disconnected',
            value: state.disconnectedCount.toString(),
            color: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  void _showDisconnectDialog(
    BuildContext context,
    WidgetRef ref,
    AgentSession session,
  ) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(LucideIcons.unplug, size: 48, color: scheme.error),
        title: const Text('Disconnect Agent?'),
        content: Text(
          'Are you sure you want to disconnect ${session.agentName}?\n\n'
          'The notebook and sources will remain accessible, but you won\'t receive new messages from this agent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(agentConnectionsProvider.notifier)
                  .disconnectSession(session.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '${session.agentName} disconnected'
                          : 'Failed to disconnect agent',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}

/// Stat item widget for the summary
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.secondaryText,
              ),
        ),
      ],
    );
  }
}

/// Card widget for displaying an agent session
/// Requirements: 4.1, 4.2, 4.3
class _AgentSessionCard extends StatelessWidget {
  final AgentSession session;
  final VoidCallback onDisconnect;
  final VoidCallback? onViewNotebook;

  const _AgentSessionCard({
    required this.session,
    required this.onDisconnect,
    this.onViewNotebook,
  });

  IconData _getAgentIcon() {
    final name = session.agentName.toLowerCase();
    if (name.contains('claude')) return Icons.smart_toy_outlined;
    if (name.contains('kiro')) return Icons.auto_awesome;
    if (name.contains('cursor')) return Icons.code;
    if (name.contains('copilot')) return Icons.assistant;
    return Icons.terminal;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Agent icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getAgentIcon(),
                    size: 24,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                // Agent info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.agentName,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AgentNotebookBadge(
                        agentName: session.agentIdentifier,
                        status: session.status,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                // Status indicator
                _StatusChip(status: session.status),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (session.notebookTitle != null) ...[
                  _DetailRow(
                    icon: LucideIcons.bookOpen,
                    label: 'Notebook',
                    value: session.notebookTitle!,
                  ),
                  const SizedBox(height: 8),
                ],
                _DetailRow(
                  icon: LucideIcons.clock,
                  label: 'Last Activity',
                  value: _formatTimeAgo(session.lastActivity),
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  icon: LucideIcons.calendar,
                  label: 'Connected',
                  value: _formatTimeAgo(session.createdAt),
                ),
              ],
            ),
          ),
          // Actions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: scheme.outline.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                if (onViewNotebook != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewNotebook,
                      icon: const Icon(LucideIcons.externalLink, size: 16),
                      label: const Text('View Notebook'),
                    ),
                  ),
                if (onViewNotebook != null) const SizedBox(width: 8),
                if (session.isActive)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDisconnect,
                      icon: const Icon(LucideIcons.unplug, size: 16),
                      label: const Text('Disconnect'),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                      ),
                    ),
                  ),
                if (session.isExpired || session.isDisconnected)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Show reconnect info
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'To reconnect, use the coding agent to create a new session',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      label: const Text('Reconnect Info'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status chip widget
class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  Color _getColor() {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF22C55E);
      case 'expired':
        return const Color(0xFFF59E0B);
      case 'disconnected':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String _getLabel() {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'expired':
        return 'Expired';
      case 'disconnected':
        return 'Disconnected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _getLabel(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail row widget
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.secondaryText),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 13,
            color: scheme.secondaryText,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
