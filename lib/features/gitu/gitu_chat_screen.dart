import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
              child: _GituMessageList(messages: state.messages),
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

  const _ConnectionBadge({
    required this.isConnected,
    required this.isConnecting,
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

  const _GituMessageList({required this.messages});

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
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _GituMessageBubble(message: message);
      },
    );
  }
}

class _GituMessageBubble extends StatelessWidget {
  final GituMessage message;

  const _GituMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final scheme = Theme.of(context).colorScheme;

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
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
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
                    enabled: state.isConnected,
                    decoration: InputDecoration(
                      hintText: state.isConnected ? 'Message Gitu...' : 'Connecting...',
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
                  onPressed: state.isConnected ? _sendMessage : null,
                  icon: Icon(
                    LucideIcons.send, 
                    color: Colors.white.withValues(alpha: state.isConnected ? 1.0 : 0.5), 
                    size: 20
                  ),
                  tooltip: 'Send',
                ),
              ).animate(target: state.isConnected ? 1 : 0).scale(duration: 200.ms),
            ],
          ),
        ),
      ),
    );
  }
}
