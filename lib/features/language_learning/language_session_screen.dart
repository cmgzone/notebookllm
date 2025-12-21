import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'language_learning_provider.dart';
import 'language_session.dart';
import '../../core/audio/voice_service.dart';

class LanguageSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const LanguageSessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<LanguageSessionScreen> createState() =>
      _LanguageSessionScreenState();
}

class _LanguageSessionScreenState extends ConsumerState<LanguageSessionScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isListening = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;

    _inputController.clear();
    setState(() => _isLoading = true);

    try {
      await ref
          .read(languageLearningProvider.notifier)
          .sendMessage(widget.sessionId, content);
      _scrollToBottom();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('+2 XP 🔥 Keep it up!'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleListening() async {
    final voiceService = ref.read(voiceServiceProvider);

    if (_isListening) {
      await voiceService.stopListening();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      try {
        await voiceService.listen(onResult: (text) {
          if (mounted) {
            _inputController.text = text;
          }
        }, onDone: (finalText) {
          if (mounted) {
            _inputController.text = finalText;
            setState(() => _isListening = false);
          }
        }, onSoundLevel: (level) {
          // Optional: Visualize sound level
        });
      } catch (e) {
        if (mounted) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Microphone error: $e')),
          );
        }
      }
    }
  }

  void _showAudioSettings() {
    showDialog(
      context: context,
      builder: (context) => _AudioSettingsDialog(),
    );
  }

  void _finishSession() async {
    await ref
        .read(languageLearningProvider.notifier)
        .completeSession(widget.sessionId);
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Session Complete!'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.partyPopper, size: 48, color: Colors.orange),
              SizedBox(height: 16),
              Text('+50 XP',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Great job practicing today!'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Exit screen
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(languageLearningProvider).firstWhere(
        (s) => s.id == widget.sessionId,
        orElse: () => LanguageSession(targetLanguage: 'Unknown'));

    // Loading state if session not found yet (though unlikely due to provider structure)
    if (session.targetLanguage == 'Unknown') {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(session.targetLanguage),
            Text(
              session.topic ?? 'General Conversation',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.checkCircle),
            tooltip: 'Finish Session',
            onPressed: _finishSession,
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: 'Audio Settings',
            onPressed: _showAudioSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: session.messages.length,
              itemBuilder: (context, index) {
                final message = session.messages[index];
                return _MessageBubble(message: message);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          _buildInputArea(scheme),
        ],
      ),
    );
  }

  Widget _buildInputArea(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _toggleListening,
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
              color: _isListening ? Colors.red : scheme.onSurfaceVariant,
              style: IconButton.styleFrom(
                backgroundColor:
                    _isListening ? Colors.red.withValues(alpha: 0.1) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: _isListening ? 'Listening...' : 'Type message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerStatefulWidget {
  final LanguageMessage message;

  const _MessageBubble({required this.message});

  @override
  ConsumerState<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<_MessageBubble> {
  bool _showTranslation = false;
  bool _isPlaying = false;

  Future<void> _playAudio() async {
    if (_isPlaying) return;

    setState(() => _isPlaying = true);
    try {
      await ref.read(voiceServiceProvider).speak(widget.message.content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = widget.message.role == LanguageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Text(
                          widget.message.content,
                          style: TextStyle(
                            color: isUser ? scheme.onPrimary : scheme.onSurface,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _playAudio,
                          icon: Icon(_isPlaying
                              ? Icons.volume_up
                              : Icons.volume_up_outlined),
                          color: scheme.onSurface,
                          iconSize: 20,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                  if (widget.message.pronunciation != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '/${widget.message.pronunciation}/',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: (isUser ? scheme.onPrimary : scheme.onSurface)
                            .withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_showTranslation &&
                      widget.message.translation != null) ...[
                    const SizedBox(height: 8),
                    Divider(
                        color: (isUser ? scheme.onPrimary : scheme.onSurface)
                            .withValues(alpha: 0.2)),
                    const SizedBox(height: 4),
                    Text(
                      widget.message.translation!,
                      style: TextStyle(
                        color: (isUser ? scheme.onPrimary : scheme.onSurface)
                            .withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (_showTranslation &&
                      widget.message.correction != null) ...[
                    const SizedBox(height: 8),
                    Divider(
                        color: (isUser ? scheme.onPrimary : scheme.onSurface)
                            .withValues(alpha: 0.2)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 14,
                            color:
                                isUser ? scheme.inversePrimary : Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Correction: ${widget.message.correction!}',
                            style: TextStyle(
                                color: (isUser
                                        ? scheme.onPrimary
                                        : scheme.onSurface)
                                    .withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!isUser || widget.message.correction != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isUser)
                      TextButton.icon(
                        onPressed: () => setState(
                            () => _showTranslation = !_showTranslation),
                        icon: Icon(
                            _showTranslation
                                ? Icons.visibility_off_outlined
                                : Icons.translate,
                            size: 14),
                        label: Text(_showTranslation ? 'Hide' : 'Translate',
                            style: const TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          foregroundColor: scheme.secondary,
                        ),
                      ),
                    if (isUser &&
                        widget.message.correction != null &&
                        !_showTranslation)
                      TextButton.icon(
                        onPressed: () => setState(
                            () => _showTranslation = !_showTranslation),
                        icon: const Icon(Icons.info_outline, size: 14),
                        label: const Text('See Correction',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          foregroundColor: Colors.orange,
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

class _AudioSettingsDialog extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceService = ref.watch(voiceServiceProvider);

    return AlertDialog(
      title: const Text('Audio Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose a voice provider for better pronunciation.'),
          const SizedBox(height: 16),
          _ProviderOption(
              title: 'Murf AI (Best)',
              subtitle: 'Studio quality voices',
              isSelected: voiceService.currentProvider == TtsProvider.murf,
              onTap: () {
                voiceService.setTtsProvider(TtsProvider.murf);
                Navigator.pop(context);
              }),
          _ProviderOption(
              title: 'Google Cloud',
              subtitle: 'Standard quality',
              isSelected:
                  voiceService.currentProvider == TtsProvider.googleCloud,
              onTap: () {
                voiceService.setTtsProvider(TtsProvider.googleCloud);
                Navigator.pop(context);
              }),
          _ProviderOption(
              title: 'Device Default',
              subtitle: 'Free, works offline',
              isSelected: voiceService.currentProvider == TtsProvider.google,
              onTap: () {
                voiceService.setTtsProvider(TtsProvider.google);
                Navigator.pop(context);
              }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        )
      ],
    );
  }
}

class _ProviderOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProviderOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing:
          isSelected ? Icon(Icons.check_circle, color: scheme.primary) : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: scheme.primary) : BorderSide.none,
      ),
      tileColor:
          isSelected ? scheme.primaryContainer.withValues(alpha: 0.3) : null,
    );
  }
}
