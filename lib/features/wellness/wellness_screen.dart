import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'wellness_provider.dart';

class WellnessScreen extends ConsumerStatefulWidget {
  const WellnessScreen({super.key});

  @override
  ConsumerState<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends ConsumerState<WellnessScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isMedicalMode = false;

  @override
  void dispose() {
    // Stop voice if active when leaving screen
    ref.read(wellnessProvider.notifier).stopVoice();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wellnessProvider);
    final notifier = ref.read(wellnessProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    // Auto-scroll on new message
    ref.listen(wellnessProvider, (previous, next) {
      if (next.messages.length > (previous?.messages.length ?? 0)) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }

      // Show error snackbar
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: scheme.error,
            action: SnackBarAction(
              label: 'Settings',
              textColor: scheme.onError,
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              _isMedicalMode
                  ? LucideIcons.stethoscope
                  : LucideIcons.heartHandshake,
              color: _isMedicalMode ? Colors.blue : Colors.pink,
            ),
            const SizedBox(width: 8),
            const Text('Wellness AI'),
          ],
        ),
        actions: [
          Switch(
            value: _isMedicalMode,
            onChanged: (val) => setState(() => _isMedicalMode = val),
            thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
              if (states.contains(WidgetState.selected)) {
                return const Icon(LucideIcons.stethoscope, color: Colors.white);
              }
              return const Icon(LucideIcons.heartHandshake,
                  color: Colors.white);
            }),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Banner explaining the mode
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: _isMedicalMode
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.pink.withValues(alpha: 0.1),
            child: Text(
              _isMedicalMode
                  ? "Medical Research Mode: Queries will be deeply researched using autonomous agents."
                  : "Emotional Support Mode: A safe space to talk about stress, anxiety, and feelings.",
              style: TextStyle(
                  fontSize: 12,
                  color: _isMedicalMode ? Colors.blue[800] : Colors.pink[800],
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),

          // Research Status Indicator
          if (state.isResearching)
            Container(
              padding: const EdgeInsets.all(8),
              color: scheme.surfaceContainerHighest,
              child: Row(
                children: [
                  SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: state.researchProgress > 0
                              ? state.researchProgress
                              : null)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(state.researchStatus ?? "Researching...",
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant))),
                ],
              ),
            ),

          // Chat Area
          Expanded(
            child: state.messages.isEmpty && !state.isResearching
                ? _buildEmptyState(scheme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length + (state.isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 16, bottom: 16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final msg = state.messages[index];
                      return _buildMessageBubble(msg, scheme);
                    },
                  ),
          ),

          // Input Area
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.isListening && state.currentSpeechText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        '"${state.currentSpeechText}"',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: scheme.primary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: state.isListening
                                ? 'Listening...'
                                : (_isMedicalMode
                                    ? 'Enter medical topic to research...'
                                    : 'How are you feeling today?'),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(notifier),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Voice Button
                      IconButton.filledTonal(
                        onPressed: () => _toggleVoice(notifier),
                        icon: Icon(
                          state.isListening
                              ? LucideIcons.micOff
                              : LucideIcons.mic,
                          color:
                              state.isListening ? Colors.red : scheme.primary,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: state.isListening
                              ? Colors.red.withValues(alpha: 0.1)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: state.isResearching || state.isTyping
                            ? null
                            : () => _sendMessage(notifier),
                        icon: const Icon(LucideIcons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleVoice(WellnessNotifier notifier) {
    notifier.toggleVoice(onInputComplete: (text) {
      // This callback is triggered when silence is detected or stop is called
      if (_isMedicalMode) {
        notifier.startMedicalResearch(text, triggeredByVoice: true);
      } else {
        notifier.sendEmotionalSupportMessage(text, triggeredByVoice: true);
      }
    });
  }

  void _sendMessage(WellnessNotifier notifier) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    if (_isMedicalMode) {
      notifier.startMedicalResearch(text);
    } else {
      notifier.sendEmotionalSupportMessage(text);
    }
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.heartHandshake,
              size: 64, color: scheme.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            "Wellness AI Helper",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "I'm here to listen and help. Toggle the switch at the top for deep medical research.",
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(WellnessMessage msg, ColorScheme scheme) {
    final isMe = msg.isUser;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMe
              ? scheme.primaryContainer
              : (msg.isResearchResult
                  ? scheme.tertiaryContainer
                  : scheme.surfaceContainerHighest),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isResearchResult)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(LucideIcons.fileText,
                        size: 16, color: scheme.onTertiaryContainer),
                    const SizedBox(width: 8),
                    Text("Research Report",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: scheme.onTertiaryContainer)),
                  ],
                ),
              ),
            MarkdownBody(
              data: msg.content,
              selectable: true,
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(
                    color: isMe ? scheme.onPrimaryContainer : scheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
