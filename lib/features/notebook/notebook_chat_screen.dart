import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../sources/source_provider.dart';
import '../../core/ai/ai_provider.dart';
import 'notebook_provider.dart';
import '../../core/api/api_service.dart';
import '../../theme/app_theme.dart';
import '../chat/context_usage_widget.dart';

class NotebookChatScreen extends ConsumerStatefulWidget {
  final String notebookId;

  const NotebookChatScreen({
    super.key,
    required this.notebookId,
  });

  @override
  ConsumerState<NotebookChatScreen> createState() => _NotebookChatScreenState();
}

class _NotebookChatScreenState extends ConsumerState<NotebookChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  ChatStyle _selectedStyle = ChatStyle.standard;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await ref
          .read(apiServiceProvider)
          .getChatHistory(notebookId: widget.notebookId);
      final messages = history
          .map((data) => ChatMessage(
                text: data['content'],
                isUser: data['role'] == 'user',
                timestamp: DateTime.parse(data['created_at']),
              ))
          .toList();

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _isLoading = false;
        });
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Error loading chat history: $e');
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Save User Message
      await ref.read(apiServiceProvider).saveChatMessage(
            role: 'user',
            content: message,
            notebookId: widget.notebookId,
          );

      // Get notebook sources for context
      final allSources = ref.read(sourceProvider);
      final notebookSources =
          allSources.where((s) => s.notebookId == widget.notebookId).toList();

      final context =
          notebookSources.map((s) => '${s.title}: ${s.content}').toList();

      // Construct history pairs
      final historyPairs = <AIPromptResponse>[];
      for (int i = 0; i < _messages.length - 1; i++) {
        if (_messages[i].isUser && !_messages[i + 1].isUser) {
          historyPairs.add(AIPromptResponse(
              prompt: _messages[i].text,
              response: _messages[i + 1].text,
              timestamp: _messages[i + 1].timestamp));
        }
      }

      // Generate AI response
      await ref.read(aiProvider.notifier).generateContent(
            message,
            context: context,
            style: _selectedStyle,
            externalHistory: historyPairs,
          );

      final aiState = ref.read(aiProvider);
      if (aiState.lastResponse != null) {
        // Save AI Message
        await ref.read(apiServiceProvider).saveChatMessage(
              role: 'model',
              content: aiState.lastResponse!,
              notebookId: widget.notebookId,
            );

        setState(() {
          _messages.add(ChatMessage(
            text: aiState.lastResponse!,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
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

  Future<void> _saveConversationAsSource() async {
    if (_messages.isEmpty) return;

    final conversation = _messages
        .map((m) => '${m.isUser ? "User" : "AI"}: ${m.text}')
        .join('\n\n');

    try {
      await ref.read(sourceProvider.notifier).addSource(
            title:
                'Chat Conversation - ${DateTime.now().toString().split('.')[0]}',
            type: 'conversation',
            content: conversation,
            notebookId: widget.notebookId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation saved as source'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving conversation: $e')),
        );
      }
    }
  }

  void _showStyleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Communication Style',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildStyleTile(ChatStyle.standard, 'Standard',
                'Balanced and helpful', Icons.chat),
            _buildStyleTile(ChatStyle.tutor, 'Socratic Tutor',
                'Asks guiding questions', Icons.school),
            _buildStyleTile(ChatStyle.deepDive, 'Deep Dive',
                'Detailed and analytical', Icons.analytics),
            _buildStyleTile(ChatStyle.concise, 'Concise', 'Short and direct',
                Icons.short_text),
            _buildStyleTile(ChatStyle.creative, 'Creative',
                'Imaginative and novel', Icons.lightbulb),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleTile(
      ChatStyle style, String title, String subtitle, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _selectedStyle == style;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.1)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isSelected ? scheme.primary : scheme.onSurface,
        ),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle),
      trailing:
          isSelected ? Icon(Icons.check_circle, color: scheme.primary) : null,
      onTap: () {
        setState(() => _selectedStyle = style);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to $title mode'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: scheme.primaryContainer,
            showCloseIcon: true,
            closeIconColor: scheme.onPrimaryContainer,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final notebooks = ref.watch(notebookProvider);
    final notebook = notebooks.firstWhere(
      (n) => n.id == widget.notebookId,
      orElse: () => notebooks.first,
    );
    final allSources = ref.watch(sourceProvider);
    final sourcesCount =
        allSources.where((s) => s.notebookId == widget.notebookId).length;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.premiumGradient,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notebook.title, style: const TextStyle(color: Colors.white)),
            Text(
              '$sourcesCount sources available',
              style: text.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Context usage indicator
          GestureDetector(
            onTap: () => showContextUsageDialog(context),
            child: const ContextUsageIndicator(compact: true),
          ),
          const SizedBox(width: 4),
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save as Source',
              onPressed: _saveConversationAsSource,
            ),
          IconButton(
            icon: const Icon(Icons.psychology), // Brain icon for personas
            tooltip: 'Conversation Style',
            onPressed: _showStyleSelector,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Chat',
            onPressed: () {
              setState(() => _messages.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner if no sources
          if (sourcesCount == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: scheme.secondaryContainer.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add sources to this notebook for better AI responses',
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ).animate().slideY(begin: -0.2).fadeIn(),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: AppTheme.premiumGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 40,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        )
                            .animate()
                            .scale(duration: 600.ms, curve: Curves.elasticOut),
                        const SizedBox(height: 24),
                        Text(
                          'Start a conversation',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 8),
                        Text(
                          'Ask questions about your sources',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _MessageBubble(message: message)
                          .animate()
                          .slideY(
                            begin: 0.2, // Slide up
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          )
                          .fadeIn();
                    },
                  ),
          ),

          // Loading indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text('Thinking...', style: text.bodySmall),
                ],
              ),
            ),

          // Input field
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.8),
                  border: Border(
                    top: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.1)),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: scheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Ask anything...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          enabled: !_isLoading,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.premiumGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _isLoading ? null : _sendMessage,
                        icon:
                            const Icon(Icons.arrow_upward, color: Colors.white),
                        tooltip: 'Send',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.75 : 0.88),
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24).copyWith(
            bottomRight: isUser ? Radius.zero : const Radius.circular(24),
            bottomLeft: !isUser ? Radius.zero : const Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: !isUser
              ? Border.all(color: scheme.outline.withValues(alpha: 0.1))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Use Markdown for AI messages, plain text for user
            if (isUser)
              SelectableText(
                message.text,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onPrimary,
                  height: 1.5,
                ),
              )
            else
              MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  // Text styles
                  p: text.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.6,
                  ),
                  h1: text.headlineSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: text.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: text.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  h4: text.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  // Bold and emphasis
                  strong: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                  em: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurface,
                  ),
                  // Lists
                  listBullet: text.bodyMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  // Code
                  code: TextStyle(
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: scheme.tertiary,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  codeblockPadding: const EdgeInsets.all(12),
                  // Blockquotes
                  blockquote: text.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.6),
                        width: 4,
                      ),
                    ),
                  ),
                  blockquotePadding:
                      const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                  // Links
                  a: TextStyle(
                    color: scheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: scheme.primary,
                  ),
                  // Horizontal rule
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  // Table styles
                  tableHead: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                  tableBody: text.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                onTapLink: (text, href, title) async {
                  if (href != null) {
                    final uri = Uri.parse(href);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  }
                },
              ),
            const SizedBox(height: 8),
            // Action row with timestamp and copy button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: text.bodySmall?.copyWith(
                    color: isUser
                        ? scheme.onPrimary.withValues(alpha: 0.7)
                        : scheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: scheme.inverseSurface,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
