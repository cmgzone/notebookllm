import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/audio/voice_service.dart';
import '../../core/audio/voice_action_handler.dart';

class VoiceModeScreen extends ConsumerStatefulWidget {
  const VoiceModeScreen({super.key});

  @override
  ConsumerState<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

enum VoiceState { idle, listening, processing, speaking }

class _VoiceModeScreenState extends ConsumerState<VoiceModeScreen> {
  VoiceState _state = VoiceState.idle;
  String _lastUserText = '';
  String _lastAiText = '';
  String? _generatedImageUrl;
  final List<String> _conversationHistory = []; // For context

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  void _initVoice() async {
    try {
      await ref.read(voiceServiceProvider).initialize();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize voice: $e')),
      );
    }
  }

  void _startListening() async {
    setState(() => _state = VoiceState.listening);
    try {
      await ref.read(voiceServiceProvider).listen(
        onResult: (text) {
          setState(() => _lastUserText = text);
        },
        onDone: (text) {
          _processUserRequest(text);
        },
      );
    } catch (e) {
      setState(() => _state = VoiceState.idle);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error listening: $e')),
      );
    }
  }

  void _processUserRequest(String text) async {
    if (text.isEmpty) {
      setState(() => _state = VoiceState.idle);
      return;
    }

    setState(() {
      _state = VoiceState.processing;
      _conversationHistory.add('User: $text');
    });

    try {
      // Process user input with action handler
      final actionHandler = ref.read(voiceActionHandlerProvider);
      final result =
          await actionHandler.processUserInput(text, _conversationHistory);
      final response = result.response;

      setState(() {
        _lastAiText = response;
        _conversationHistory.add('AI: $response');
        _state = VoiceState.speaking;

        // Handle image generation result
        if (result.actionType == 'generate_image' && result.imageUrl != null) {
          _generatedImageUrl = result.imageUrl;
        }
      });

      // Speak response
      await ref.read(voiceServiceProvider).speak(response);

      if (mounted) {
        setState(() => _state = VoiceState.idle);
      }
    } catch (e) {
      setState(() => _state = VoiceState.idle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing: $e')),
        );
      }
    }
  }

  void _stop() async {
    await ref.read(voiceServiceProvider).stopListening();
    await ref.read(voiceServiceProvider).stopSpeaking();
    setState(() => _state = VoiceState.idle);
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Voice Mode'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Conversation display
                  if (_lastUserText.isNotEmpty) ...[
                    Text(
                      _lastUserText,
                      style: text.headlineSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn().slideY(begin: 0.2),
                    const SizedBox(height: 32),
                  ],
                  if (_lastAiText.isNotEmpty) ...[
                    Text(
                      _lastAiText,
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    )
                        .animate(key: ValueKey(_lastAiText))
                        .fadeIn()
                        .slideY(begin: 0.2),
                  ],
                  if (_generatedImageUrl != null) ...[
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _generatedImageUrl!,
                        height: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                      ),
                    ).animate().fadeIn().scale(),
                  ],
                ],
              ),
            ),
          ),

          // Visualizer / Controls
          SizedBox(
            height: 200,
            child: Center(
              child: _buildVisualizer(scheme),
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildVisualizer(ColorScheme scheme) {
    switch (_state) {
      case VoiceState.idle:
        return GestureDetector(
          onTap: _startListening,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary,
            ),
            child: Icon(LucideIcons.mic, color: scheme.onPrimary, size: 32),
          ),
        ).animate().scale(duration: 200.ms);

      case VoiceState.listening:
        return GestureDetector(
          onTap: _stop,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.error,
            ),
            child: Icon(Icons.stop, color: scheme.onError, size: 40),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
        );

      case VoiceState.processing:
        return SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            color: scheme.primary,
            strokeWidth: 6,
          ),
        );

      case VoiceState.speaking:
        return GestureDetector(
          onTap: _stop,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondary,
            ),
            child:
                Icon(LucideIcons.volume2, color: scheme.onSecondary, size: 32),
          ).animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1.seconds, color: Colors.white.withValues(alpha: 0.5)),
        );
    }
  }
}
