import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/audio/voice_service.dart';
import '../../core/audio/voice_action_handler.dart';
import '../../core/audio/voice_feedback_service.dart';
import '../sources/source_provider.dart';
import '../gamification/gamification_provider.dart';
import '../subscription/services/credit_manager.dart';

// Voice message model
class VoiceMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? actionType;
  final String? imageUrl;

  VoiceMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.actionType,
    this.imageUrl,
  });
}

// Voice settings provider
final voiceSettingsProvider =
    StateNotifierProvider<VoiceSettingsNotifier, VoiceSettings>((ref) {
  return VoiceSettingsNotifier();
});

class VoiceSettings {
  final bool continuousMode;
  final bool useSourceContext;
  final double speechSpeed;
  final bool soundFeedback;
  final bool showSuggestions;

  VoiceSettings({
    this.continuousMode = false,
    this.useSourceContext = true,
    this.speechSpeed = 1.0,
    this.soundFeedback = true,
    this.showSuggestions = true,
  });

  VoiceSettings copyWith({
    bool? continuousMode,
    bool? useSourceContext,
    double? speechSpeed,
    bool? soundFeedback,
    bool? showSuggestions,
  }) {
    return VoiceSettings(
      continuousMode: continuousMode ?? this.continuousMode,
      useSourceContext: useSourceContext ?? this.useSourceContext,
      speechSpeed: speechSpeed ?? this.speechSpeed,
      soundFeedback: soundFeedback ?? this.soundFeedback,
      showSuggestions: showSuggestions ?? this.showSuggestions,
    );
  }
}

class VoiceSettingsNotifier extends StateNotifier<VoiceSettings> {
  VoiceSettingsNotifier() : super(VoiceSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = VoiceSettings(
      continuousMode: prefs.getBool('voice_continuous_mode') ?? false,
      useSourceContext: prefs.getBool('voice_use_context') ?? true,
      speechSpeed: prefs.getDouble('voice_speech_speed') ?? 1.0,
      soundFeedback: prefs.getBool('voice_sound_feedback') ?? true,
      showSuggestions: prefs.getBool('voice_show_suggestions') ?? true,
    );
    voiceFeedbackService.setSoundsEnabled(state.soundFeedback);
  }

  Future<void> toggleContinuousMode() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !state.continuousMode;
    await prefs.setBool('voice_continuous_mode', newValue);
    state = state.copyWith(continuousMode: newValue);
  }

  Future<void> toggleSourceContext() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !state.useSourceContext;
    await prefs.setBool('voice_use_context', newValue);
    state = state.copyWith(useSourceContext: newValue);
  }

  Future<void> setSpeechSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('voice_speech_speed', speed);
    state = state.copyWith(speechSpeed: speed);
  }

  Future<void> toggleSoundFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !state.soundFeedback;
    await prefs.setBool('voice_sound_feedback', newValue);
    voiceFeedbackService.setSoundsEnabled(newValue);
    state = state.copyWith(soundFeedback: newValue);
  }

  Future<void> toggleShowSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !state.showSuggestions;
    await prefs.setBool('voice_show_suggestions', newValue);
    state = state.copyWith(showSuggestions: newValue);
  }
}

// Voice commands data
class VoiceCommand {
  final String command;
  final String description;
  final IconData icon;

  const VoiceCommand({
    required this.command,
    required this.description,
    required this.icon,
  });
}

const List<VoiceCommand> voiceCommands = [
  VoiceCommand(
    command: '"Create a note about..."',
    description: 'Save a new note to your sources',
    icon: LucideIcons.fileText,
  ),
  VoiceCommand(
    command: '"Search for..."',
    description: 'Search through your sources',
    icon: LucideIcons.search,
  ),
  VoiceCommand(
    command: '"Create a notebook called..."',
    description: 'Create a new notebook',
    icon: LucideIcons.book,
  ),
  VoiceCommand(
    command: '"List my notebooks"',
    description: 'View all your notebooks',
    icon: LucideIcons.list,
  ),
  VoiceCommand(
    command: '"Summarize my sources"',
    description: 'Get a summary of your content',
    icon: LucideIcons.sparkles,
  ),
  VoiceCommand(
    command: '"Generate an image of..."',
    description: 'Create AI-generated images',
    icon: LucideIcons.image,
  ),
  VoiceCommand(
    command: '"Create an ebook about..."',
    description: 'Start a new ebook project',
    icon: LucideIcons.bookOpen,
  ),
];

// Smart suggestions based on context
class SmartSuggestion {
  final String text;
  final IconData icon;

  const SmartSuggestion({required this.text, required this.icon});
}

List<SmartSuggestion> getSuggestions(String? lastActionType, int sourceCount) {
  if (lastActionType == 'create_note') {
    return [
      const SmartSuggestion(
        text: 'Add this to a notebook',
        icon: LucideIcons.folderPlus,
      ),
      const SmartSuggestion(
        text: 'Create another note',
        icon: LucideIcons.filePlus,
      ),
    ];
  } else if (lastActionType == 'search_sources') {
    return [
      const SmartSuggestion(
        text: 'Tell me more about the first result',
        icon: LucideIcons.messageSquare,
      ),
      const SmartSuggestion(
        text: 'Search for something else',
        icon: LucideIcons.search,
      ),
    ];
  } else if (lastActionType == 'create_notebook') {
    return [
      const SmartSuggestion(
        text: 'Add a note to this notebook',
        icon: LucideIcons.filePlus,
      ),
      const SmartSuggestion(
        text: 'Create another notebook',
        icon: LucideIcons.bookPlus,
      ),
    ];
  } else if (sourceCount == 0) {
    return [
      const SmartSuggestion(
        text: 'Create my first note',
        icon: LucideIcons.fileText,
      ),
      const SmartSuggestion(
        text: 'What can you help me with?',
        icon: LucideIcons.helpCircle,
      ),
    ];
  } else {
    return [
      const SmartSuggestion(
        text: 'Summarize my sources',
        icon: LucideIcons.sparkles,
      ),
      const SmartSuggestion(
        text: 'Search for something',
        icon: LucideIcons.search,
      ),
    ];
  }
}

class EnhancedVoiceModeScreen extends ConsumerStatefulWidget {
  const EnhancedVoiceModeScreen({super.key});

  @override
  ConsumerState<EnhancedVoiceModeScreen> createState() =>
      _EnhancedVoiceModeScreenState();
}

enum VoiceState { idle, listening, processing, speaking }

class _EnhancedVoiceModeScreenState
    extends ConsumerState<EnhancedVoiceModeScreen> {
  VoiceState _state = VoiceState.idle;
  String _currentUserText = '';
  final List<VoiceMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  double _audioLevel = 0.0;
  String? _lastActionType;

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
    final settings = ref.read(voiceSettingsProvider);

    setState(() {
      _state = VoiceState.listening;
      _currentUserText = '';
      _audioLevel = 0.0;
    });

    // Play feedback sound
    if (settings.soundFeedback) {
      await voiceFeedbackService.playStartListening();
    }

    // Track voice mode usage
    ref.read(gamificationProvider.notifier).trackVoiceModeUsed();
    ref.read(gamificationProvider.notifier).trackFeatureUsed('voice_mode');

    try {
      await ref.read(voiceServiceProvider).listen(
        onResult: (text) {
          setState(() {
            _currentUserText = text;
          });
        },
        onDone: (text) {
          _processUserRequest(text);
        },
        onSoundLevel: (level) {
          setState(() {
            _audioLevel = level;
          });
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

    // Check and consume credits for voice mode
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.voiceMode,
      feature: 'voice_mode',
    );
    if (!hasCredits) {
      setState(() => _state = VoiceState.idle);
      return;
    }

    final settings = ref.read(voiceSettingsProvider);

    // Play processing feedback
    if (settings.soundFeedback) {
      await voiceFeedbackService.playProcessing();
    }

    // Add user message
    final userMessage = VoiceMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _state = VoiceState.processing;
      _audioLevel = 0.0;
    });

    _scrollToBottom();

    try {
      final actionHandler = ref.read(voiceActionHandlerProvider);

      // Build context with sources if enabled
      final conversationHistory = _messages
          .map((m) => '${m.isUser ? "User" : "AI"}: ${m.text}')
          .toList();

      // Add source context if enabled
      String enhancedPrompt = text;
      if (settings.useSourceContext) {
        final sources = ref.read(sourceProvider);
        if (sources.isNotEmpty) {
          final sourceContext = sources
              .take(5)
              .map((s) =>
                  '${s.title}: ${s.content.length > 200 ? s.content.substring(0, 200) : s.content}')
              .join('\n');

          enhancedPrompt = '''
Available sources:
$sourceContext

User question: $text
''';
        }
      }

      final result = await actionHandler.processUserInput(
        enhancedPrompt,
        conversationHistory,
      );

      // Update last action type for suggestions
      _lastActionType = result.actionType;

      // Add AI message
      final aiMessage = VoiceMessage(
        text: result.response,
        isUser: false,
        timestamp: DateTime.now(),
        actionType: result.actionType,
        imageUrl: result.imageUrl,
      );

      setState(() {
        _messages.add(aiMessage);
        _state = VoiceState.speaking;
      });

      _scrollToBottom();

      // Play success sound if action was performed
      if (result.actionPerformed && settings.soundFeedback) {
        await voiceFeedbackService.playSuccess();
      }

      // Speak response
      await ref
          .read(voiceServiceProvider)
          .speak(result.response, speed: settings.speechSpeed);

      if (mounted) {
        setState(() => _state = VoiceState.idle);

        // Auto-listen if continuous mode is on
        if (settings.continuousMode && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted && _state == VoiceState.idle) {
            _startListening();
          }
        }
      }
    } catch (e) {
      final settings = ref.read(voiceSettingsProvider);
      if (settings.soundFeedback) {
        await voiceFeedbackService.playError();
      }

      setState(() => _state = VoiceState.idle);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing: $e')),
      );
    }
  }

  void _useSuggestion(String suggestion) {
    _processUserRequest(suggestion);
  }

  void _interrupt() async {
    final settings = ref.read(voiceSettingsProvider);

    // Play stop sound
    if (settings.soundFeedback) {
      await voiceFeedbackService.playStopListening();
    }

    // Get any remaining text before stopping
    final remainingText = await ref.read(voiceServiceProvider).stopListening();
    await ref.read(voiceServiceProvider).stopSpeaking();

    // If there was text being recognized, process it
    if (remainingText.isNotEmpty && _state == VoiceState.listening) {
      _processUserRequest(remainingText);
    } else {
      setState(() {
        _state = VoiceState.idle;
        _audioLevel = 0.0;
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const VoiceSettingsSheet(),
    );
  }

  void _showCommandsHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const VoiceCommandsHelpSheet(),
    );
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _lastActionType = null;
    });
  }

  Future<void> _exportConversation() async {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No conversation to export')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Voice Conversation Export');
    buffer.writeln('=' * 40);
    buffer.writeln('Date: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('=' * 40);
    buffer.writeln();

    for (final msg in _messages) {
      final speaker = msg.isUser ? 'You' : 'AI';
      final time =
          '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
      buffer.writeln('[$time] $speaker:');
      buffer.writeln(msg.text);
      if (msg.actionType != null) {
        buffer.writeln('  (Action: ${msg.actionType})');
      }
      buffer.writeln();
    }

    final transcript = buffer.toString();

    // Save to temp file and share
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/voice_conversation_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(transcript);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Voice Conversation Export',
      );
    } catch (e) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: transcript));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation copied to clipboard')),
        );
      }
    }
  }

  @override
  void dispose() {
    _interrupt();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(voiceSettingsProvider);
    final sources = ref.watch(sourceProvider);

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
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.helpCircle),
            onPressed: _showCommandsHelp,
            tooltip: 'Voice commands',
          ),
          IconButton(
            icon: const Icon(Icons.groups),
            onPressed: () => context.push('/meeting-mode'),
            tooltip: 'Meeting Mode',
          ),
          IconButton(
            icon: const Icon(Icons.support_agent),
            onPressed: () => context.push('/elevenlabs-agent'),
            tooltip: 'Conversational Agent',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportConversation();
                  break;
                case 'clear':
                  _clearConversation();
                  break;
                case 'settings':
                  _showSettings();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(LucideIcons.share2),
                    SizedBox(width: 12),
                    Text('Export conversation'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                enabled: _messages.isNotEmpty,
                child: const Row(
                  children: [
                    Icon(LucideIcons.trash2),
                    SizedBox(width: 12),
                    Text('Clear conversation'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(LucideIcons.settings),
                    SizedBox(width: 12),
                    Text('Voice settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Settings indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (settings.continuousMode)
                  Chip(
                    avatar: const Icon(Icons.repeat, size: 16),
                    label: const Text('Continuous',
                        style: TextStyle(fontSize: 11)),
                    backgroundColor: scheme.primaryContainer,
                  ),
                if (settings.continuousMode) const SizedBox(width: 8),
                if (settings.useSourceContext)
                  Chip(
                    avatar: const Icon(Icons.source, size: 16),
                    label:
                        const Text('Context', style: TextStyle(fontSize: 11)),
                    backgroundColor: scheme.secondaryContainer,
                  ),
                if (settings.useSourceContext) const SizedBox(width: 8),
                if (settings.soundFeedback)
                  Chip(
                    avatar: const Icon(LucideIcons.volume2, size: 16),
                    label: const Text('Sound', style: TextStyle(fontSize: 11)),
                    backgroundColor: scheme.tertiaryContainer,
                  ),
              ],
            ),
          ),

          // Conversation transcript
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(scheme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _MessageBubble(message: message)
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.2, duration: 300.ms);
                    },
                  ),
          ),

          // Smart suggestions
          if (_state == VoiceState.idle &&
              settings.showSuggestions &&
              _messages.isNotEmpty)
            _buildSuggestions(scheme, sources.length),

          // Current listening text
          if (_state == VoiceState.listening && _currentUserText.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.3),
                border: Border(
                  top: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.mic, color: scheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentUserText,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),

          // Audio visualizer
          _buildAudioVisualizer(scheme),

          // Control button
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildControlButton(scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ColorScheme scheme, int sourceCount) {
    final suggestions = getSuggestions(_lastActionType, sourceCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map((s) => ActionChip(
                      avatar: Icon(s.icon, size: 16),
                      label: Text(s.text, style: const TextStyle(fontSize: 12)),
                      onPressed: () => _useSuggestion(s.text),
                    ))
                .toList(),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer.withValues(alpha: 0.3),
            ),
            child: Icon(
              LucideIcons.mic,
              size: 64,
              color: scheme.primary,
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'Tap to start talking',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          Text(
            'I can help you with notes, research,\nand answering questions',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _showCommandsHelp,
            icon: const Icon(LucideIcons.helpCircle),
            label: const Text('View voice commands'),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildAudioVisualizer(ColorScheme scheme) {
    if (_state == VoiceState.idle) return const SizedBox(height: 60);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(20, (index) {
          // Use real audio level for dynamic visualization
          const baseHeight = 4.0;
          final normalizedIndex = (index - 10).abs() / 10.0;

          double height;
          if (_state == VoiceState.listening) {
            // Real audio level visualization
            height = baseHeight + (_audioLevel * 40 * (1 - normalizedIndex));
          } else if (_state == VoiceState.speaking) {
            // Animated speaking visualization
            height = baseHeight + (30 * (1 - normalizedIndex));
          } else {
            height = baseHeight;
          }

          return Container(
            width: 3,
            height: height.clamp(4.0, 50.0),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _state == VoiceState.listening
                  ? scheme.error
                  : _state == VoiceState.speaking
                      ? scheme.secondary
                      : scheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ).animate(onPlay: (c) => c.loop()).shimmer(
              duration: 1.seconds, delay: Duration(milliseconds: index * 50));
        }),
      ),
    );
  }

  Widget _buildControlButton(ColorScheme scheme) {
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
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(LucideIcons.mic, color: scheme.onPrimary, size: 32),
          ),
        ).animate().scale(duration: 200.ms);

      case VoiceState.listening:
        return GestureDetector(
          onTap: _interrupt,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.error,
              boxShadow: [
                BoxShadow(
                  color: scheme.error.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(Icons.stop, color: scheme.onError, size: 40),
          )
              .animate(onPlay: (c) => c.loop(reverse: true))
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
          onTap: _interrupt,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondary,
              boxShadow: [
                BoxShadow(
                  color: scheme.secondary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(Icons.stop, color: scheme.onSecondary, size: 32),
          ).animate(onPlay: (c) => c.loop()).shimmer(
              duration: 1.seconds, color: Colors.white.withValues(alpha: 0.5)),
        );
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final VoiceMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
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
                  bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? scheme.onPrimary : scheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
                  if (message.actionType != null && !isUser) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getActionIcon(message.actionType!),
                            size: 12,
                            color: scheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getActionLabel(message.actionType!),
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType) {
      case 'create_note':
        return LucideIcons.fileText;
      case 'search_sources':
        return LucideIcons.search;
      case 'create_notebook':
        return LucideIcons.book;
      case 'list_sources':
      case 'list_notebooks':
        return LucideIcons.list;
      case 'get_summary':
        return LucideIcons.sparkles;
      case 'generate_image':
        return LucideIcons.image;
      case 'create_ebook':
        return LucideIcons.bookOpen;
      default:
        return LucideIcons.messageSquare;
    }
  }

  String _getActionLabel(String actionType) {
    switch (actionType) {
      case 'create_note':
        return 'Note Created';
      case 'search_sources':
        return 'Sources Searched';
      case 'create_notebook':
        return 'Notebook Created';
      case 'list_sources':
        return 'Sources Listed';
      case 'list_notebooks':
        return 'Notebooks Listed';
      case 'get_summary':
        return 'Summary Generated';
      case 'generate_image':
        return 'Image Generated';
      case 'create_ebook':
        return 'Ebook Created';
      default:
        return 'Action Completed';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class VoiceCommandsHelpSheet extends StatelessWidget {
  const VoiceCommandsHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.mic, color: scheme.primary),
              const SizedBox(width: 12),
              Text(
                'Voice Commands',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Try saying any of these commands:',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: voiceCommands.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final cmd = voiceCommands[index];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(cmd.icon,
                        size: 20, color: scheme.onPrimaryContainer),
                  ),
                  title: Text(
                    cmd.command,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  subtitle: Text(cmd.description),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it!'),
            ),
          ),
        ],
      ),
    );
  }
}

class VoiceSettingsSheet extends ConsumerWidget {
  const VoiceSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(voiceSettingsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.settings, color: scheme.primary),
              const SizedBox(width: 12),
              Text(
                'Voice Settings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Behavior settings
                  Text(
                    'Behavior',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Continuous Mode'),
                    subtitle: const Text('Auto-listen after AI responds'),
                    value: settings.continuousMode,
                    onChanged: (_) => ref
                        .read(voiceSettingsProvider.notifier)
                        .toggleContinuousMode(),
                  ),
                  SwitchListTile(
                    title: const Text('Use Source Context'),
                    subtitle: const Text('AI knows your sources'),
                    value: settings.useSourceContext,
                    onChanged: (_) => ref
                        .read(voiceSettingsProvider.notifier)
                        .toggleSourceContext(),
                  ),
                  SwitchListTile(
                    title: const Text('Sound Feedback'),
                    subtitle: const Text('Play sounds for actions'),
                    value: settings.soundFeedback,
                    onChanged: (_) => ref
                        .read(voiceSettingsProvider.notifier)
                        .toggleSoundFeedback(),
                  ),
                  SwitchListTile(
                    title: const Text('Smart Suggestions'),
                    subtitle: const Text('Show contextual suggestions'),
                    value: settings.showSuggestions,
                    onChanged: (_) => ref
                        .read(voiceSettingsProvider.notifier)
                        .toggleShowSuggestions(),
                  ),
                  const SizedBox(height: 16),

                  // Speech settings
                  Text(
                    'Speech',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(
                        'Speech Speed: ${settings.speechSpeed.toStringAsFixed(1)}x'),
                    subtitle: Slider(
                      value: settings.speechSpeed,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: '${settings.speechSpeed.toStringAsFixed(1)}x',
                      onChanged: (value) => ref
                          .read(voiceSettingsProvider.notifier)
                          .setSpeechSpeed(value),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Voice provider
                  Text(
                    'Voice Provider',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('Google TTS (Free)'),
                    subtitle: const Text('Standard device voice'),
                    leading: const Icon(Icons.smartphone),
                    trailing: ref.read(voiceServiceProvider).currentProvider ==
                            TtsProvider.google
                        ? Icon(Icons.check_circle, color: scheme.primary)
                        : null,
                    onTap: () {
                      ref
                          .read(voiceServiceProvider)
                          .setTtsProvider(TtsProvider.google);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Google Cloud TTS'),
                    subtitle: const Text('High quality neural voices'),
                    leading: const Icon(Icons.cloud),
                    trailing: ref.read(voiceServiceProvider).currentProvider ==
                            TtsProvider.googleCloud
                        ? Icon(Icons.check_circle, color: scheme.primary)
                        : null,
                    onTap: () {
                      ref
                          .read(voiceServiceProvider)
                          .setTtsProvider(TtsProvider.googleCloud);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('ElevenLabs'),
                    subtitle: const Text('Ultra realistic AI voices'),
                    leading: const Icon(Icons.graphic_eq),
                    trailing: ref.read(voiceServiceProvider).currentProvider ==
                            TtsProvider.elevenlabs
                        ? Icon(Icons.check_circle, color: scheme.primary)
                        : null,
                    onTap: () {
                      ref
                          .read(voiceServiceProvider)
                          .setTtsProvider(TtsProvider.elevenlabs);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Murf AI'),
                    subtitle: const Text('Studio quality voices'),
                    leading: const Icon(Icons.record_voice_over),
                    trailing: ref.read(voiceServiceProvider).currentProvider ==
                            TtsProvider.murf
                        ? Icon(Icons.check_circle, color: scheme.primary)
                        : null,
                    onTap: () {
                      ref
                          .read(voiceServiceProvider)
                          .setTtsProvider(TtsProvider.murf);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
