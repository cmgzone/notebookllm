import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

// Only import ElevenLabs on mobile platforms
import 'package:elevenlabs_agents/elevenlabs_agents.dart'
    if (dart.library.html) 'elevenlabs_stub.dart';
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) 'permission_stub.dart';
import '../../core/audio/elevenlabs_config_secure.dart';
import '../../core/audio/voice_action_handler.dart';
import '../../core/ai/deep_research_service.dart';
import '../sources/source_provider.dart';
import '../notebook/notebook_provider.dart';
import '../ebook/ebook_provider.dart';
import '../ebook/models/ebook_project.dart';
import '../ebook/models/branding_config.dart';
import 'package:uuid/uuid.dart';
import '../../core/ai/ai_settings_service.dart';

class ElevenLabsAgentScreen extends ConsumerStatefulWidget {
  const ElevenLabsAgentScreen({super.key});

  @override
  ConsumerState<ElevenLabsAgentScreen> createState() =>
      _ElevenLabsAgentScreenState();
}

class _ElevenLabsAgentScreenState extends ConsumerState<ElevenLabsAgentScreen> {
  @override
  Widget build(BuildContext context) {
    // Show web-not-supported message on web
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Conversational Agent'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.web_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 24),
              Text(
                'Not Available on Web',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'ElevenLabs Conversational AI requires a mobile platform (Android/iOS) for WebRTC support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile implementation would go here
    // For now, return the mobile UI
    return const _MobileAgentScreen();
  }
}

class _MobileAgentScreen extends ConsumerStatefulWidget {
  const _MobileAgentScreen();

  @override
  ConsumerState<_MobileAgentScreen> createState() => _MobileAgentScreenState();
}

class _MobileAgentScreenState extends ConsumerState<_MobileAgentScreen> {
  ConversationClient? _client;
  final List<String> _messages = [];
  String _agentId = '';
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _useLocalProcessing = true; // Enable local feature access
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _initAgent();
  }

  Future<void> _initAgent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final config = ref.read(elevenLabsConfigSecureProvider);
      _agentId = await config.getAgentId();

      if (_agentId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Missing ELEVENLABS_AGENT_ID. Configure it in Settings or .env file.';
            _messages.add('Error: Missing ELEVENLABS_AGENT_ID');
          });
        }
        return;
      }

      final permissionGranted = await _requestMicrophonePermission();
      if (!permissionGranted) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Microphone permission is required for voice conversations.';
          });
        }
        return;
      }

      _initializeClient();
    } catch (e) {
      debugPrint('Error initializing agent: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize: $e';
          _messages.add('Error: $e');
        });
      }
    }
  }

  Future<bool> _requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _messages.add('Microphone permission denied');
          });
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Permission error: $e');
      return false;
    }
  }

  void _initializeClient() {
    try {
      _client = ConversationClient(
        callbacks: ConversationCallbacks(
          onConnect: ({required conversationId}) {
            debugPrint('Connected with ID: $conversationId');
            if (mounted) {
              setState(() {
                _messages.add('System: Connected to agent');
              });
            }
          },
          onDisconnect: (details) {
            debugPrint('Disconnected: ${details.reason}');
            if (mounted) {
              setState(() {
                _messages.add('System: Disconnected from agent');
              });
            }
          },
          onMessage: ({required message, required source}) {
            debugPrint('Message from ${source.name}: $message');
            if (mounted) {
              setState(() {
                _messages.add('${source.name}: $message');
              });

              // Process user messages for local actions
              if (source.name == 'user' && _useLocalProcessing) {
                _processLocalAction(message);
              }
            }
          },
          onModeChange: ({required mode}) {
            debugPrint('Mode changed: ${mode.name}');
            if (mounted) {
              setState(() {
                _messages.add('System: Mode changed to ${mode.name}');
              });
            }
          },
          onError: (message, [context]) {
            debugPrint('Error: $message');
            if (mounted) {
              setState(() {
                _messages.add('Error: $message');
              });
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text('Error: $message'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      );

      _client!.addListener(() {
        if (mounted) {
          setState(() {}); // Rebuild on state changes
        }
      });

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error creating client: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to create conversation client: $e';
      });
    }
  }

  Future<void> _startConversation() async {
    if (_agentId.isEmpty || !_isInitialized || _client == null) return;

    try {
      setState(() {
        _messages.add('System: Connecting...');
      });
      await _client!.startSession(
        agentId: _agentId,
        userId: 'flutter-user-${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      debugPrint('Start conversation error: $e');
      if (mounted) {
        setState(() {
          _messages.add('Failed to start conversation: $e');
          if (e.toString().toLowerCase().contains('vpn') ||
              e.toString().contains('403') ||
              e.toString().toLowerCase().contains('connection')) {
            _messages.add('⚠️ Troubleshooting Tip:');
            _messages.add(
                '1. Ensure your Agent is set to "Public" in ElevenLabs Dashboard.');
            _messages.add(
                '2. If "Private", this client currently requires a signed URL (not yet implemented).');
            _messages.add('3. Check your internet connection and firewall.');
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endConversation() async {
    if (_client == null) return;
    try {
      await _client!.endSession();
    } catch (e) {
      debugPrint('End conversation error: $e');
    }
  }

  /// Process user messages for local app actions
  Future<void> _processLocalAction(String userMessage) async {
    if (_isProcessingAction) return;

    final lowerMessage = userMessage.toLowerCase();

    // Detect action keywords
    _AgentAction? action;

    if (_containsKeywords(lowerMessage,
        ['deep research', 'research about', 'research on', 'investigate'])) {
      action = _AgentAction(type: 'deep_research', query: userMessage);
    } else if (_containsKeywords(lowerMessage,
        ['create note', 'save note', 'write note', 'add note', 'take note'])) {
      action = _AgentAction(type: 'create_note', query: userMessage);
    } else if (_containsKeywords(lowerMessage, [
      'search sources',
      'find in sources',
      'look in my sources',
      'search my notes'
    ])) {
      action = _AgentAction(type: 'search_sources', query: userMessage);
    } else if (_containsKeywords(lowerMessage,
        ['list sources', 'show sources', 'my sources', 'what sources'])) {
      action = _AgentAction(type: 'list_sources', query: userMessage);
    } else if (_containsKeywords(
        lowerMessage, ['create notebook', 'new notebook', 'add notebook'])) {
      action = _AgentAction(type: 'create_notebook', query: userMessage);
    } else if (_containsKeywords(
        lowerMessage, ['list notebooks', 'show notebooks', 'my notebooks'])) {
      action = _AgentAction(type: 'list_notebooks', query: userMessage);
    } else if (_containsKeywords(
        lowerMessage, ['summarize', 'summary of', 'give me a summary'])) {
      action = _AgentAction(type: 'summarize', query: userMessage);
    } else if (_containsKeywords(
        lowerMessage, ['create ebook', 'write ebook', 'generate ebook'])) {
      action = _AgentAction(type: 'create_ebook', query: userMessage);
    }

    if (action != null) {
      await _executeAction(action);
    }
  }

  bool _containsKeywords(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  Future<void> _executeAction(_AgentAction action) async {
    setState(() => _isProcessingAction = true);

    try {
      switch (action.type) {
        case 'deep_research':
          await _performDeepResearch(action.query);
          break;
        case 'create_note':
          await _performCreateNote(action.query);
          break;
        case 'search_sources':
          await _performSearchSources(action.query);
          break;
        case 'list_sources':
          await _performListSources();
          break;
        case 'create_notebook':
          await _performCreateNotebook(action.query);
          break;
        case 'list_notebooks':
          await _performListNotebooks();
          break;
        case 'summarize':
          await _performSummarize();
          break;
        case 'create_ebook':
          await _performCreateEbook(action.query);
          break;
      }
    } catch (e) {
      debugPrint('Action error: $e');
      if (mounted) {
        setState(() {
          _messages.add('System: Action failed - $e');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _performDeepResearch(String query) async {
    setState(() {
      _messages.add('System: 🔍 Starting deep research...');
    });

    try {
      final researchService = ref.read(deepResearchServiceProvider);
      String lastStatus = '';
      String? finalReport;

      await for (final update
          in researchService.research(query, notebookId: '')) {
        if (update.status != lastStatus) {
          lastStatus = update.status;
          if (mounted) {
            setState(() {
              _messages.add('System: ${update.status}');
            });
          }
        }

        if (update.result != null) {
          finalReport = update.result;
        }
      }

      if (finalReport != null && mounted) {
        // Save research as a source
        await ref.read(sourceProvider.notifier).addSource(
              title:
                  'Research: ${query.substring(0, query.length > 50 ? 50 : query.length)}',
              type: 'text',
              content: finalReport,
            );

        setState(() {
          _messages.add('System: ✅ Research complete! Saved to your sources.');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add('System: ❌ Research failed: $e');
        });
      }
    }
  }

  Future<void> _performCreateNote(String query) async {
    final actionHandler = ref.read(voiceActionHandlerProvider);
    final result = await actionHandler.processUserInput(query, _messages);

    if (mounted) {
      setState(() {
        _messages.add('System: ${result.response}');
      });
    }
  }

  Future<void> _performSearchSources(String query) async {
    final sources = ref.read(sourceProvider);
    final searchTerms = query.toLowerCase();

    final matches = sources
        .where((s) {
          final text = '${s.title} ${s.content}'.toLowerCase();
          return text.contains(searchTerms);
        })
        .take(5)
        .toList();

    if (mounted) {
      if (matches.isEmpty) {
        setState(() {
          _messages.add('System: No matching sources found.');
        });
      } else {
        setState(() {
          _messages.add('System: Found ${matches.length} sources:');
          for (final source in matches) {
            _messages.add('  • ${source.title} (${source.type})');
          }
        });
      }
    }
  }

  Future<void> _performListSources() async {
    final sources = ref.read(sourceProvider);

    if (mounted) {
      if (sources.isEmpty) {
        setState(() {
          _messages.add('System: You have no sources yet.');
        });
      } else {
        final types = <String, int>{};
        for (final s in sources) {
          types[s.type] = (types[s.type] ?? 0) + 1;
        }

        setState(() {
          _messages.add('System: You have ${sources.length} sources:');
          types.forEach((type, count) {
            _messages.add('  • $count $type source${count > 1 ? 's' : ''}');
          });
        });
      }
    }
  }

  Future<void> _performCreateNotebook(String query) async {
    // Extract notebook name from query
    String name = 'New Notebook';
    final patterns = [
      RegExp(r'called\s+(\w+(?:\s+\w+)*)', caseSensitive: false),
      RegExp(r'named\s+(\w+(?:\s+\w+)*)', caseSensitive: false),
      RegExp(r'titled\s+(\w+(?:\s+\w+)*)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match != null && match.group(1) != null) {
        name = match.group(1)!;
        break;
      }
    }

    await ref.read(notebookProvider.notifier).addNotebook(name);

    if (mounted) {
      setState(() {
        _messages.add('System: ✅ Created notebook "$name"');
      });
    }
  }

  Future<void> _performListNotebooks() async {
    final notebooks = ref.read(notebookProvider);

    if (mounted) {
      if (notebooks.isEmpty) {
        setState(() {
          _messages.add('System: You have no notebooks yet.');
        });
      } else {
        setState(() {
          _messages.add('System: You have ${notebooks.length} notebooks:');
          for (final nb in notebooks.take(5)) {
            _messages.add('  • ${nb.title} (${nb.sourceCount} sources)');
          }
          if (notebooks.length > 5) {
            _messages.add('  ... and ${notebooks.length - 5} more');
          }
        });
      }
    }
  }

  Future<void> _performSummarize() async {
    final actionHandler = ref.read(voiceActionHandlerProvider);
    final result =
        await actionHandler.processUserInput('summarize my sources', _messages);

    if (mounted) {
      setState(() {
        _messages.add('System: ${result.response}');
      });
    }
  }

  Future<void> _performCreateEbook(String query) async {
    // Extract ebook title and topic
    String title = 'New Ebook';
    String topic = 'General Topic';

    // Simple parsing logic
    // "Create ebook about [topic] called [title]"
    // "Create ebook titled [title] about [topic]"

    final aboutMatch =
        RegExp(r'about\s+(.*?)(?:called|named|titled|$)', caseSensitive: false)
            .firstMatch(query);
    if (aboutMatch != null && aboutMatch.group(1) != null) {
      topic = aboutMatch.group(1)!.trim();
    }

    final titleMatch = RegExp(r'(?:called|named|titled)\s+(.*?)(?:about|$)',
            caseSensitive: false)
        .firstMatch(query);
    if (titleMatch != null && titleMatch.group(1) != null) {
      title = titleMatch.group(1)!.trim();
    } else if (topic != 'General Topic') {
      // If no title but topic exists, use topic as title
      title = topic;
    }

    final settings = await AISettingsService.getSettings();
    final currentModel = settings.getEffectiveModel();

    final id = const Uuid().v4();
    final now = DateTime.now();
    final ebook = EbookProject(
      id: id,
      title: title,
      topic: topic,
      targetAudience: 'General Audience',
      branding: const BrandingConfig(
        primaryColorValue: 0xFF000000,
        fontFamily: 'Roboto',
      ),
      selectedModel: currentModel,
      createdAt: now,
      updatedAt: now,
      status: EbookStatus.draft,
    );

    await ref.read(ebookProvider.notifier).addEbook(ebook);

    if (mounted) {
      setState(() {
        _messages.add('System: ✅ Created ebook "$title" about "$topic"');
      });
    }
  }

  @override
  void dispose() {
    if (_isInitialized && _client != null) {
      _client!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Show loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: const Text('Conversational Agent'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing agent...'),
            ],
          ),
        ),
      );
    }

    // Show error state
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: const Text('Conversational Agent'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: scheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Configuration Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _initAgent,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isConnected = _isInitialized &&
        _client != null &&
        _client!.status == ConversationStatus.connected;
    final isDisconnected = !_isInitialized ||
        _client == null ||
        _client!.status == ConversationStatus.disconnected;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Conversational Agent'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Toggle for local feature access
          IconButton(
            icon: Icon(
              _useLocalProcessing
                  ? Icons.auto_awesome
                  : Icons.auto_awesome_outlined,
              color: _useLocalProcessing ? scheme.primary : null,
            ),
            tooltip: _useLocalProcessing
                ? 'App features enabled'
                : 'App features disabled',
            onPressed: () {
              setState(() => _useLocalProcessing = !_useLocalProcessing);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_useLocalProcessing
                      ? 'App features enabled (deep research, notes, sources)'
                      : 'App features disabled'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Feature access indicator
          if (_useLocalProcessing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: scheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Say: "deep research about...", "create note...", "search sources...", "summarize"',
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
            ),

          // Processing indicator
          if (_isProcessingAction)
            LinearProgressIndicator(color: scheme.primary),

          // Status indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isConnected
                    ? [scheme.primary, scheme.primaryContainer]
                    : [scheme.surfaceContainerHighest, scheme.surface],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isConnected ? Icons.mic : Icons.mic_off,
                  color: isConnected ? scheme.onPrimary : scheme.onSurface,
                ),
                const SizedBox(width: 12),
                Text(
                  _isInitialized && _client != null
                      ? 'Status: ${_client!.status.name}'
                      : 'Initializing...',
                  style: TextStyle(
                    color: isConnected ? scheme.onPrimary : scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isInitialized &&
                    _client != null &&
                    _client!.isSpeaking) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.volume_up,
                    color: scheme.onPrimary,
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 1.seconds),
                ],
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.messageCircle,
                          size: 64,
                          color: scheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _agentId.isEmpty
                              ? 'Configure agent ID in .env'
                              : 'Start a conversation to begin',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isSystem = message.startsWith('System:') ||
                          message.startsWith('Error:');
                      final isUser = message.startsWith('user:');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSystem
                                  ? scheme.surfaceContainerHighest
                                  : isUser
                                      ? scheme.primary
                                      : scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message,
                              style: TextStyle(
                                color: isUser
                                    ? scheme.onPrimary
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.2);
                    },
                  ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isDisconnected && _agentId.isNotEmpty
                            ? _startConversation
                            : null,
                        icon: const Icon(Icons.call),
                        label: const Text('Start Conversation'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isConnected ? _endConversation : null,
                        icon: const Icon(Icons.call_end),
                        label: const Text('End Call'),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isConnected && _client != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _client!.toggleMute(),
                    icon: Icon(_client!.isMuted ? Icons.mic_off : Icons.mic),
                    label: Text(_client!.isMuted ? 'Unmute' : 'Mute'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _client!.isMuted
                          ? scheme.error
                          : scheme.surfaceContainerHighest,
                      foregroundColor:
                          _client!.isMuted ? scheme.onError : scheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class for tracking agent actions
class _AgentAction {
  final String type;
  final String query;

  _AgentAction({required this.type, required this.query});
}
