import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'dart:ui' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'ai_browser_service.dart';
import '../../theme/app_theme.dart';
import '../subscription/services/credit_manager.dart';
import '../notebook/notebook_provider.dart';
import '../notebook/notebook_detail_screen.dart';
import '../../core/api/api_service.dart';
import '../studio/audio_overview_provider.dart';
import '../../core/audio/voice_service.dart';
import '../../core/services/overlay_bubble_service.dart';
import '../sources/source_provider.dart';

class AIBrowserScreen extends ConsumerStatefulWidget {
  final String? notebookId;

  const AIBrowserScreen({
    super.key,
    this.notebookId,
  });

  @override
  ConsumerState<AIBrowserScreen> createState() => _AIBrowserScreenState();
}

class _AIBrowserScreenState extends ConsumerState<AIBrowserScreen> {
  late WebViewController _webController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final GlobalKey _repainterKey = GlobalKey();

  final List<_ChatMessage> _messages = [];
  bool _isAIBrowsing = false;
  String _currentUrl = 'https://www.google.com';
  String _aiStatus = '';
  double _loadingProgress = 0;
  bool _showChat = true;
  bool _enableDeepBrowse = false;
  bool _isListening = false;
  bool _isNarrating = false;
  String _lastSpokenStatus = '';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true) // User requested zoom capability
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() {
            _currentUrl = url;
            _urlController.text = url;
            _loadingProgress = 0;
          });
        },
        onProgress: (progress) {
          setState(() => _loadingProgress = progress / 100);
        },
        onPageFinished: (url) {
          setState(() {
            _currentUrl = url;
            _urlController.text = url;
            _loadingProgress = 1;
          });
        },
      ))
      ..loadRequest(Uri.parse(_currentUrl));

    // Set controller in service
    ref.read(aiBrowserServiceProvider).setController(_webController);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _navigateToUrl() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Check if it looks like a URL or a search query
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        // Treat as Google search
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }

    await _webController.loadRequest(Uri.parse(url));
  }

  Future<void> _sendAIMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    // Handle User Intervention during browsing
    if (_isAIBrowsing) {
      ref.read(aiBrowserServiceProvider).addUserMessage(message);
      setState(() {
        _messages.add(_ChatMessage(text: message, isUser: true));
      });
      _chatController.clear();
      _scrollToBottom();
      return;
    }

    // Check credits - Deep Browse costs more
    final cost = _enableDeepBrowse
        ? CreditCosts.chatMessage * 10
        : CreditCosts.chatMessage * 3;
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: cost,
      feature: 'ai_browser',
    );
    if (!hasCredits) return;

    setState(() {
      _messages.add(_ChatMessage(text: message, isUser: true));
      _isAIBrowsing = true;
      _aiStatus = _enableDeepBrowse
          ? 'Starting Deep Browse (30m max)...'
          : 'Starting...';
      // Smart close: Hide chat to show browser action
      _showChat = false;
    });
    _chatController.clear();
    _scrollToBottom();

    try {
      final service = ref.read(aiBrowserServiceProvider);

      await for (final update in service.browse(
        query: message,
        maxDuration: _enableDeepBrowse ? const Duration(minutes: 30) : null,
      )) {
        if (!mounted) return;

        setState(() {
          _aiStatus = update.status;
        });

        // Handle Vision Screenshot Request
        if (update.action == AIBrowserAction.takingScreenshot) {
          // 1. Take Screenshot
          final screenshot = await _takeScreenshot();

          if (screenshot != null) {
            // 2. Send back to service
            await service.processVisionScreenshot(screenshot);
          } else {
            // Failed to take screenshot, send empty signal to unblock service (or handle error)
            // Ideally service has a timeout, but we can verify
            debugPrint('Failed to capture screenshot for Vision');
            // For now we rely on service timeout or we can expose a fail method
          }
        }

        // Narrator: Speak status updates
        if (_isNarrating && update.status != _lastSpokenStatus) {
          _lastSpokenStatus = update.status;
          // Remove emojis for cleaner speech
          final textToSpeak =
              update.status.replaceAll(RegExp(r'[^\x00-\x7F]+'), '').trim();
          ref.read(voiceServiceProvider).speak(textToSpeak, interrupt: true);
        }

        if (update.isFinding) {
          final screenshot = await _takeScreenshot();
          if (mounted) {
            setState(() {
              _messages.add(_ChatMessage(
                text: '💡 Found: ${update.findingText}',
                isUser: false,
                imageBytes: screenshot,
              ));
            });
            _scrollToBottom();
          }
        }

        if (update.action == AIBrowserAction.waitingForFeedback &&
            update.isProduct) {
          if (mounted) {
            await _showProductProposalDialog(update);
          }
        }

        if (update.isComplete) {
          setState(() {
            _isAIBrowsing = false;
            // Smart open: Show chat to display result
            _showChat = true;
            if (update.finalResponse != null) {
              _messages.add(_ChatMessage(
                text: update.finalResponse!,
                isUser: false,
                url: update.currentUrl,
                // Add save capability
                canSave: true,
                onSave: _saveResearchToNotebook,
              ));
            }
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      setState(() {
        _isAIBrowsing = false;
        _messages.add(_ChatMessage(
          text: 'Error: $e',
          isUser: false,
          isError: true,
        ));
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showProductProposalDialog(AIBrowserUpdate update) async {
    // Take a screenshot of the product area
    final screenshot = await _takeScreenshot();

    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;
    final hasNetworkImage = update.productImageUrl != null &&
        update.productImageUrl!.startsWith('http');

    await showDialog(
      context: context,
      barrierDismissible: false, // User MUST choose
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shopping_bag, color: scheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Found Product')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section - Show both network image and screenshot
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: scheme.surfaceContainerHighest,
                ),
                child: Row(
                  children: [
                    // Primary: Network Image (if available)
                    if (hasNetworkImage)
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: update.productImageUrl!,
                            height: 180,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.primary,
                              ),
                            ),
                            errorWidget: (context, url, error) => screenshot !=
                                    null
                                ? Image.memory(screenshot, fit: BoxFit.cover)
                                : Icon(Icons.image_not_supported,
                                    size: 48, color: scheme.outline),
                          ),
                        ),
                      ),

                    // Secondary: Screenshot (if no network image or as additional context)
                    if (!hasNetworkImage && screenshot != null)
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            screenshot,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                    // Show screenshot as thumbnail if we have both
                    if (hasNetworkImage && screenshot != null)
                      Container(
                        width: 80,
                        margin: const EdgeInsets.only(left: 8),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                screenshot,
                                height: 70,
                                width: 70,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Live View',
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Product Title
              Text(
                update.productTitle ?? 'Unknown Product',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              // Price
              if (update.productPrice != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    update.productPrice!,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],

              // Description
              if (update.productDescription != null) ...[
                const SizedBox(height: 12),
                Text(
                  update.productDescription!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 16),

              // Question prompt
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 20, color: scheme.tertiary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Do you like this product?'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.thumb_down, color: Colors.red),
            label: const Text('No, skip'),
            onPressed: () {
              ref.read(aiBrowserServiceProvider).provideFeedback(false);
              Navigator.of(dialogContext).pop();
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.thumb_up),
            label: const Text('Yes, save it!'),
            onPressed: () {
              // Pass screenshot bytes when saving the product
              ref.read(aiBrowserServiceProvider).provideFeedback(
                    true,
                    screenshotBytes: screenshot,
                  );
              Navigator.of(dialogContext).pop();

              // Also add to chat as a positive finding
              setState(() {
                _messages.add(_ChatMessage(
                  text:
                      '❤️ Liked: ${update.productTitle} (${update.productPrice})',
                  isUser: true, // Show as if user typed it
                  imageBytes: screenshot,
                ));
              });
            },
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _takeScreenshot() async {
    try {
      // Find the render boundary
      final boundary = _repainterKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Capture image - need to wait for frame if rapidly changing
      // await Future.delayed(const Duration(milliseconds: 100));
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing screenshot: $e');
      return null;
    }
  }

  Future<void> _saveResearchToNotebook(String content) async {
    try {
      String targetNotebookId;
      String snackBarMessage;

      if (widget.notebookId != null) {
        // Use existing notebook
        targetNotebookId = widget.notebookId!;
        snackBarMessage = 'Research saved to current notebook!';
      } else {
        // Create new notebook
        final title =
            'Deep Research: ${DateTime.now().toString().substring(0, 16)}';
        final newNotebookId =
            await ref.read(notebookProvider.notifier).addNotebook(title);

        if (newNotebookId == null) throw Exception('Failed to create notebook');
        targetNotebookId = newNotebookId;
        snackBarMessage = 'Research saved to new notebook!';
      }

      // Add Source
      await ref.read(apiServiceProvider).createSource(
            notebookId: targetNotebookId,
            type: 'text',
            title: 'Browser Research Report',
            content: content,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackBarMessage),
            backgroundColor: Theme.of(context).colorScheme.primary,
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NotebookDetailScreen(
                      notebookId: targetNotebookId,
                    ),
                  ),
                );
              },
              textColor: Colors.white,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  Future<void> _showSaveToNotebookDialog(AIBrowserService service) async {
    final notebooks = ref.read(notebookProvider);
    String? selectedNotebookId = widget.notebookId;

    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.save_alt, color: scheme.primary),
              const SizedBox(width: 8),
              const Text('Save Comparison'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a notebook to save the comparison table:'),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final notebookList = notebooks;

                  if (notebookList.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                          'No notebooks found. A new one will be created.'),
                    );
                  }

                  // Pre-select current notebook if available
                  if (selectedNotebookId == null && notebookList.isNotEmpty) {
                    selectedNotebookId = notebookList.first.id;
                  }

                  return DropdownButtonFormField<String>(
                    key: ValueKey(selectedNotebookId),
                    initialValue: selectedNotebookId,
                    decoration: InputDecoration(
                      labelText: 'Notebook',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.book),
                    ),
                    items: notebookList.map<DropdownMenuItem<String>>((nb) {
                      return DropdownMenuItem<String>(
                        value: nb.id,
                        child: Text(
                          nb.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedNotebookId = value;
                      });
                    },
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              onPressed: () async {
                Navigator.pop(dialogContext);

                if (!mounted) return;

                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Generating comparison table...')),
                );

                try {
                  // Generate the comparison table
                  final tableMarkdown = await service.generateComparisonTable();
                  if (!mounted) return;

                  String targetNotebookId;

                  if (selectedNotebookId != null) {
                    targetNotebookId = selectedNotebookId!;
                  } else {
                    // Create new notebook if none selected
                    final title =
                        'Product Comparison ${DateTime.now().toString().substring(0, 16)}';
                    final newId = await ref
                        .read(notebookProvider.notifier)
                        .addNotebook(title);
                    if (newId == null) {
                      throw Exception('Failed to create notebook');
                    }
                    targetNotebookId = newId;
                  }

                  // Find a screenshot from the products to better represent this source
                  Uint8List? coverImage;
                  for (final product in service.collectedProducts) {
                    if (product.screenshotBytes != null) {
                      coverImage = product.screenshotBytes;
                      break;
                    }
                  }

                  // Save as source via sourceProvider to handle image processing
                  await ref.read(sourceProvider.notifier).addSource(
                        notebookId: targetNotebookId,
                        type: coverImage != null
                            ? 'image'
                            : 'text', // Use image type if we have one
                        title: 'Product Comparison Table',
                        content: tableMarkdown,
                        mediaBytes: coverImage,
                      );

                  if (!mounted) return;
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('✅ Comparison saved as source!'),
                      backgroundColor: scheme.primary,
                      action: SnackBarAction(
                        label: 'Open',
                        textColor: Colors.white,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => NotebookDetailScreen(
                                notebookId: targetNotebookId,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePagePodcast() async {
    // Check credits
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: 50,
      feature: 'page_podcast',
    );
    if (!hasCredits) return;

    try {
      // 1. Get Page Content
      final service = ref.read(aiBrowserServiceProvider);
      // We need to implement a public getContent in service or use this hack
      // Since we updated service to expose getPageContent, we can use it
      // But we need to update ai_browser_service.dart first to expose it
      // Assuming we updated it as planned:
      final content = await service.getPageContent();

      if (content.length < 100) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Page content too short for podcast')),
          );
        }
        return;
      }

      final title = await _webController.getTitle() ?? 'Web Page Summary';

      // 2. Start Generation via AudioOverview
      // We use the new contentOverride parameter we added to AudioOverviewProvider
      // We need to call it without awaiting so it runs in background

      // Request permission for overlay with explanation
      final hasPermission = await overlayBubbleService.checkPermission();
      if (!hasPermission && mounted) {
        final shouldRequest = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enable Background Progress?'),
            content: const Text(
              'To show generation progress while you continue browsing, we need "Display over other apps" permission.\n\nAlternatively, you can just wait for the notification.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Use Notification Only'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        );

        if (shouldRequest == true) {
          await overlayBubbleService.requestPermission();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Podcast generation started in background...')),
        );
      }

      // Fire and forget (provider handles state)
      ref.read(audioOverviewProvider.notifier).generate(
            title,
            isPodcast: true,
            topic: 'Summary of this web page',
            contentOverride: content,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting podcast: $e')),
        );
      }
    }
  }

  Future<void> _startVoiceCommand() async {
    final voiceService = ref.read(voiceServiceProvider);

    // Toggle listening
    if (_isListening) {
      await voiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    try {
      setState(() => _isListening = true);

      await voiceService.listen(
        onResult: (text) {
          if (mounted) {
            _chatController.text = text;
          }
        },
        onDone: (finalText) {
          if (mounted) {
            setState(() => _isListening = false);
            if (finalText.isNotEmpty) {
              _chatController.text = finalText;
              _sendAIMessage(); // Auto-send
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.premiumGradient),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('AI Browser', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_showChat ? Icons.web : Icons.chat),
            onPressed: () => setState(() => _showChat = !_showChat),
            tooltip: _showChat ? 'Fullscreen Browser' : 'Show Chat',
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => _webController.loadRequest(
              Uri.parse('https://www.google.com'),
            ),
            tooltip: 'Home',
          ),
          IconButton(
            icon: const Icon(Icons.headphones),
            onPressed: _generatePagePodcast,
            tooltip: 'Generate Page Podcast',
          ),
          IconButton(
            icon: Icon(_isNarrating ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              setState(() => _isNarrating = !_isNarrating);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      _isNarrating ? 'Narrator Mode On' : 'Narrator Mode Off'),
                  duration: const Duration(milliseconds: 1000),
                ),
              );
            },
            tooltip: _isNarrating ? 'Disable Narrator' : 'Enable Narrator',
          ),
        ],
      ),
      body: Column(
        children: [
          // URL Bar
          _buildUrlBar(scheme),

          // Loading indicator
          if (_loadingProgress < 1)
            LinearProgressIndicator(
              value: _loadingProgress,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),

          // Main content
          Expanded(
            child: _showChat
                ? Row(
                    children: [
                      // WebView
                      Expanded(
                        flex: 3,
                        child: _buildWebView(),
                      ),
                      // Chat panel
                      Container(
                        width: 320,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: scheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: _buildChatPanel(scheme, text),
                      ),
                    ],
                  )
                : _buildWebView(),
          ),
        ],
      ),
      // Comparison Tray FAB
      floatingActionButton: _buildComparisonFab(scheme),
    );
  }

  Widget? _buildComparisonFab(ColorScheme scheme) {
    // Watch collected products count (rebuild when set state updates)
    // Note: Since service isn't a notifier, we might need a better way to watch
    // For now, we rely on the fact that 'browse' stream updates might trigger rebuilds
    // or we simply check periodically.
    // BETTER: The service could expose a ValueNotifier or Stream.
    // However, for this turn, we will access the service directly.
    final service = ref.watch(aiBrowserServiceProvider);
    final count = service.collectedProducts.length;

    if (count == 0) return null;

    return FloatingActionButton.extended(
      onPressed: _showComparisonTray,
      label: Text('Compare ($count)'),
      icon: const Icon(Icons.compare_arrows),
      backgroundColor: scheme.tertiaryContainer,
      foregroundColor: scheme.onTertiaryContainer,
    );
  }

  void _showComparisonTray() {
    final service = ref.read(aiBrowserServiceProvider);
    final products = service.collectedProducts;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (sheetContext, scrollController) => Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined),
                  const SizedBox(width: 12),
                  Text(
                    'Comparison Tray',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final product = products[index];

                  // Build image widget with multiple fallbacks
                  Widget buildProductImage() {
                    // Priority 1: Screenshot (most accurate)
                    if (product.screenshotBytes != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          product.screenshotBytes!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      );
                    }

                    // Priority 2: Network image URL
                    if (product.imageUrl != null &&
                        product.imageUrl!.startsWith('http')) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 60,
                            height: 60,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Icon(Icons.image, size: 24),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Icon(Icons.shopping_bag, size: 24),
                          ),
                        ),
                      );
                    }

                    // Fallback: Icon
                    return Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shopping_bag,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    );
                  }

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                    leading: buildProductImage(),
                    title: Text(product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          product.price,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    trailing: const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                  );
                },
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext); // Close sheet

                    // Show notebook selection dialog
                    await _showSaveToNotebookDialog(service);
                  },
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Create Comparison Table'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlBar(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: scheme.surface,
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () async {
              if (await _webController.canGoBack()) {
                _webController.goBack();
              }
            },
            visualDensity: VisualDensity.compact,
          ),
          // Forward button
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 20),
            onPressed: () async {
              if (await _webController.canGoForward()) {
                _webController.goForward();
              }
            },
            visualDensity: VisualDensity.compact,
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _webController.reload(),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          // URL input
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'Enter URL or search...',
                  hintStyle: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: (_) => _navigateToUrl(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        RepaintBoundary(
          key: _repainterKey,
          child: WebViewWidget(controller: _webController),
        ),
        // AI action overlay
        if (_isAIBrowsing)
          // AI action overlay - Floating Capsule
          if (_isAIBrowsing)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    // Glassmorphism effect
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status Dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00FF9D), // Bright green dot
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00FF9D),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.2, 1.2),
                          duration: 1.seconds),
                      const SizedBox(width: 12),

                      // Status Text
                      Flexible(
                        child: Text(
                          _aiStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Pause/Resume Button
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 8),

                      if (_aiStatus.contains('Paused'))
                        IconButton(
                          icon: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Resume AI',
                          onPressed: () {
                            ref.read(aiBrowserServiceProvider).resume();
                          },
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.pause,
                              color: Colors.white, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Pause AI',
                          onPressed: () {
                            ref.read(aiBrowserServiceProvider).pause();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'AI Paused. Tap Resume to continue.')),
                            );
                          },
                        ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn()
                    .slideY(begin: 0.3, curve: Curves.easeOutBack),
              ),
            ),
      ],
    );
  }

  Widget _buildChatPanel(ColorScheme scheme, TextTheme text) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(
                color: scheme.outline.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.smart_toy_rounded,
                        color: scheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Assistant',
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Powered by Gemini',
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_messages.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => setState(() => _messages.clear()),
                      tooltip: 'Clear chat',
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Deep Browse Card
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _enableDeepBrowse
                      ? scheme.primary.withValues(alpha: 0.1)
                      : scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _enableDeepBrowse
                        ? scheme.primary.withValues(alpha: 0.3)
                        : scheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.manage_search_rounded,
                      size: 20,
                      color: _enableDeepBrowse
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deep Research Mode',
                            style: text.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _enableDeepBrowse ? scheme.primary : null,
                            ),
                          ),
                          Text(
                            'Autonomously browse for 30m',
                            style: text.bodySmall?.copyWith(
                              fontSize: 10,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _enableDeepBrowse,
                      onChanged: (v) => setState(() => _enableDeepBrowse = v),
                      activeTrackColor: scheme.primary,
                      activeThumbColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyChat(scheme, text)
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg, scheme, text);
                  },
                ),
        ),

        // AI status
        if (_isAIBrowsing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: scheme.tertiaryContainer.withValues(alpha: 0.3),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: Stack(children: [
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.tertiary,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(2, 2),
                            duration: 1.5.seconds,
                            curve: Curves.easeOut)
                        .fadeOut(duration: 1.5.seconds),
                    Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.tertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _aiStatus,
                    style: text.bodySmall?.copyWith(color: scheme.tertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),

        // Input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(color: scheme.outline.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: _enableDeepBrowse
                        ? 'Autonomously research...'
                        : 'Ask or speak to guide AI...',
                    hintStyle: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3,
                  minLines: 1,
                  onSubmitted: (_) => _sendAIMessage(),
                  // enabled: true, // Always allow input for interventions
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.premiumGradient,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendAIMessage,
                ),
              ),
              const SizedBox(width: 8),
              // Voice Command Button
              Container(
                decoration: BoxDecoration(
                  color: _isListening ? Colors.red : scheme.secondary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(_isListening ? Icons.mic_off : Icons.mic,
                      color: Colors.white, size: 20),
                  onPressed: _startVoiceCommand,
                  tooltip: 'Voice Command',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChat(ColorScheme scheme, TextTheme text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppTheme.premiumGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy,
                size: 32,
                color: Colors.white,
              ),
            ).animate().scale(curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text(
              'AI Browser Assistant',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              'Ask me to browse, search, click, or extract information from any website.',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 24),
            // Example prompts
            ..._buildExamplePrompts(scheme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildExamplePrompts(ColorScheme scheme) {
    final prompts = [
      '🔍 Search for Flutter tutorials',
      '📰 Find latest tech news',
      '🛒 Search Amazon for headphones',
      '📧 Go to Gmail',
    ];

    return prompts.asMap().entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () {
            _chatController.text = entry.value.substring(2).trim();
            _sendAIMessage();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              entry.value,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: 500 + entry.key * 100));
    }).toList();
  }

  Widget _buildMessageBubble(
      _ChatMessage msg, ColorScheme scheme, TextTheme text) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isUser ? AppTheme.premiumGradient : null,
                color: isUser
                    ? null
                    : msg.isError
                        ? scheme.errorContainer
                        : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                  bottomLeft: !isUser ? Radius.zero : const Radius.circular(20),
                ),
                boxShadow: isUser
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: isUser
                  ? Text(
                      msg.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : MarkdownBody(
                      data: msg.text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: msg.isError
                              ? scheme.onErrorContainer
                              : scheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ),
            ),
            if (msg.url != null) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg.url!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL copied')),
                  );
                },
                child: Text(
                  msg.url!,
                  style: text.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontSize: 10,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // Image Attachment
            if (msg.imageBytes != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: MemoryImage(msg.imageBytes!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Save Action
            if (msg.canSave && msg.onSave != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('Save to Notebook'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => msg.onSave!(msg.text),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: isUser ? 0.1 : -0.1);
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final String? url;
  final bool isError;
  final Uint8List? imageBytes;
  final bool canSave;
  final Function(String)? onSave;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.url,
    this.isError = false,
    this.imageBytes,
    this.canSave = false,
    this.onSave,
  });
}
