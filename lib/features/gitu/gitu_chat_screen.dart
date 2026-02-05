import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../ui/components/glass_container.dart';
import '../../theme/app_theme.dart';
import 'gitu_provider.dart';

class GituChatScreen extends ConsumerWidget {
  const GituChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gituChatProvider);
    final notifier = ref.read(gituChatProvider.notifier);

    // Auto-connect when screen opens if not connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!state.isConnected && !state.isConnecting && state.error == null) {
        notifier.connect();
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Gitu Assistant'),
            const SizedBox(width: 8),
            _ConnectionBadge(
              isConnected: state.isConnected,
              isConnecting: state.isConnecting,
              isHttpMode: state.isHttpMode,
            ),
          ],
        ),
        flexibleSpace: GlassContainer(
          borderRadius: BorderRadius.zero,
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Container(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Navigate to Gitu settings if needed
              // context.push('/gitu-settings');
              // For now we assume this screen might be accessed FROM settings or main nav
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainer,
            ],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),
            if (state.error != null)
              _ErrorBanner(
                error: state.error!,
                onRetry: () => notifier.connect(),
              ),
            Expanded(
              child: _GituMessageList(
                messages: state.messages,
                isTyping: state.isTyping,
              ),
            ),
            if (state.isConnecting)
               const LinearProgressIndicator(minHeight: 2),
            const _GituInputBar(),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final bool isHttpMode;

  const _ConnectionBadge({
    required this.isConnected,
    required this.isConnecting,
    required this.isHttpMode,
  });

  @override
  Widget build(BuildContext context) {
    if (isConnecting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
        ),
        child: const Text(
          'Connecting...',
          style: TextStyle(fontSize: 10, color: Colors.orange),
        ),
      );
    }

    if (isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
        ),
        child: const Text(
          'Online',
          style: TextStyle(fontSize: 10, color: Colors.green),
        ),
      );
    }

    if (isHttpMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
        ),
        child: const Text(
          'HTTP',
          style: TextStyle(fontSize: 10, color: Colors.blue),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'Offline',
        style: TextStyle(fontSize: 10, color: Colors.red),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.red.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 20),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _GituMessageList extends StatelessWidget {
  final List<GituMessage> messages;
  final bool isTyping;

  const _GituMessageList({
    required this.messages,
    required this.isTyping,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.bot, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Start a conversation with Gitu',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ).animate().fadeIn(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (isTyping && index == messages.length) {
          return const _GituTypingIndicator();
        }
        final message = messages[index];
        if (message.metadata?['type'] == 'mission_update') {
          return _GituMissionUpdateBubble(message: message);
        }
        if (message.metadata?['type'] == 'agent_update') {
          return _GituAgentUpdateBubble(message: message);
        }
        if (message.metadata?['type'] == 'whatsapp_qr') {
          return _GituWhatsAppQrBubble(message: message);
        }
        return _GituMessageBubble(message: message);
      },
    );
  }
}

class _GituTypingIndicator extends StatelessWidget {
  const _GituTypingIndicator();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Gitu is typing...',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GituMessageBubble extends ConsumerWidget {
  final GituMessage message;

  const _GituMessageBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final scheme = Theme.of(context).colorScheme;
    final confirmation = !isUser ? _parseConfirmation(message.content) : null;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && message.model != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.model!,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            SelectableText(
              message.content,
              style: TextStyle(
                color: isUser ? scheme.onPrimary : scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (confirmation != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(gituChatProvider.notifier)
                          .sendMessage(confirmation.confirmCommand);
                    },
                    child: const Text('Confirm'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      ref.read(gituChatProvider.notifier).sendMessage('No');
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}

class _GituMissionUpdateBubble extends StatelessWidget {
  final GituMessage message;

  const _GituMissionUpdateBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = message.metadata?['summary'] as Map<String, dynamic>?;
    final startedAtRaw = message.metadata?['startedAt'] as String?;
    final progressValue = _computeProgress(summary);
    final eta = _computeEta(startedAtRaw, summary);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.activity, size: 18, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                  if (progressValue != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 6,
                      color: scheme.primary,
                      backgroundColor: scheme.outline.withValues(alpha: 0.2),
                    ),
                  ],
                  if (eta != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'ETA ~ $eta',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GituAgentUpdateBubble extends StatelessWidget {
  final GituMessage message;

  const _GituAgentUpdateBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.tertiary.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.bot, size: 18, color: scheme.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GituWhatsAppQrBubble extends StatelessWidget {
  final GituMessage message;

  const _GituWhatsAppQrBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final qr = message.metadata?['qr'] as String? ?? '';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.secondary.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.qrCode, size: 18, color: scheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan this QR in WhatsApp to link your account.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (qr.isNotEmpty)
                    Center(
                      child: QrImageView(
                        data: qr,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationData {
  final String action;
  final String objective;
  final String confirmCommand;

  const _ConfirmationData({
    required this.action,
    required this.objective,
    required this.confirmCommand,
  });
}

_ConfirmationData? _parseConfirmation(String content) {
  if (!content.toLowerCase().contains('confirmation required')) return null;
  final actionMatch =
      RegExp(r'Action:\s*(.+)', caseSensitive: false).firstMatch(content);
  final goalMatch =
      RegExp(r'(Goal|Task):\s*\"([^\"]+)\"', caseSensitive: false)
          .firstMatch(content);
  if (actionMatch == null || goalMatch == null) return null;

  final action = actionMatch.group(1)!.trim();
  final objective = goalMatch.group(2)!.trim();
  final isSwarm = action.toLowerCase().contains('swarm');
  final confirmCommand =
      isSwarm ? 'Deploy swarm: $objective' : 'Spawn agent: $objective';

  return _ConfirmationData(
    action: action,
    objective: objective,
    confirmCommand: confirmCommand,
  );
}

double? _computeProgress(Map<String, dynamic>? summary) {
  if (summary == null) return null;
  final total = (summary['total'] as num?)?.toInt() ?? 0;
  final completed = (summary['completed'] as num?)?.toInt() ?? 0;
  if (total <= 0) return null;
  return (completed / total).clamp(0.0, 1.0);
}

String? _computeEta(String? startedAtRaw, Map<String, dynamic>? summary) {
  if (summary == null || startedAtRaw == null) return null;
  final total = (summary['total'] as num?)?.toInt() ?? 0;
  final completed = (summary['completed'] as num?)?.toInt() ?? 0;
  if (total <= 0 || completed <= 0 || completed >= total) return null;

  final startedAt = DateTime.tryParse(startedAtRaw);
  if (startedAt == null) return null;
  final elapsed = DateTime.now().difference(startedAt);
  if (elapsed.inSeconds < 5) return null;

  final estimatedTotalMs = (elapsed.inMilliseconds / completed) * total;
  final remainingMs = estimatedTotalMs - elapsed.inMilliseconds;
  if (remainingMs.isNaN || remainingMs.isInfinite || remainingMs <= 0) {
    return null;
  }

  return _formatDuration(Duration(milliseconds: remainingMs.round()));
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}

class _GituInputBar extends ConsumerStatefulWidget {
  const _GituInputBar();

  @override
  ConsumerState<_GituInputBar> createState() => _GituInputBarState();
}

class _GituInputBarState extends ConsumerState<_GituInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(gituChatProvider.notifier).sendMessage(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(gituChatProvider);

    return GlassContainer(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: 0.1))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: state.isConnected || state.isHttpMode,
                    decoration: InputDecoration(
                      hintText: state.isConnected || state.isHttpMode
                          ? 'Message Gitu...'
                          : 'Connecting...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      isDense: true,
                    ),
                    style: TextStyle(color: scheme.onSurface),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.premiumGradient,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed:
                      (state.isConnected || state.isHttpMode) ? _sendMessage : null,
                  icon: Icon(
                    LucideIcons.send, 
                    color: Colors.white.withValues(
                        alpha: (state.isConnected || state.isHttpMode) ? 1.0 : 0.5), 
                    size: 20
                  ),
                  tooltip: 'Send',
                ),
              ).animate(target: (state.isConnected || state.isHttpMode) ? 1 : 0).scale(duration: 200.ms),
            ],
          ),
        ),
      ),
    );
  }
}
