import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../chat_provider.dart';
import '../models/message.dart';
import '../../../core/auth/custom_auth_service.dart';

const List<String> _reactionTypes = [
  'like',
  'love',
  'laugh',
  'wow',
  'sad',
  'party',
];

IconData _reactionIcon(String type) {
  switch (type) {
    case 'like':
      return Icons.thumb_up;
    case 'love':
      return Icons.favorite;
    case 'laugh':
      return Icons.emoji_emotions;
    case 'wow':
      return Icons.sentiment_satisfied;
    case 'sad':
      return Icons.sentiment_dissatisfied;
    case 'party':
      return Icons.celebration;
    default:
      return Icons.add_reaction;
  }
}

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    this.groupName,
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _replyToId;
  String? _replyToContent;
  late final GroupChatNotifier _chatNotifier;

  @override
  void initState() {
    super.initState();
    _chatNotifier = ref.read(groupChatProvider.notifier);
    _scrollController.addListener(_handleScroll);
    Future.microtask(() {
      if (!mounted) return;
      _chatNotifier.openChat(
        widget.groupId,
        widget.groupName ?? 'Group',
      );
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _chatNotifier.closeChat();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels <= 80) {
      final state = ref.read(groupChatProvider);
      if (!state.isLoading && state.hasMore && state.messages.isNotEmpty) {
        ref.read(groupChatProvider.notifier).loadMessages(loadMore: true);
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    final replyId = _replyToId;
    setState(() {
      _replyToId = null;
      _replyToContent = null;
    });

    try {
      await ref.read(groupChatProvider.notifier).sendMessage(
            content,
            replyToId: replyId,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _setReply(GroupMessage message) {
    setState(() {
      _replyToId = message.id;
      _replyToContent = '${message.senderUsername}: ${message.content}';
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToContent = null;
    });
  }

  void _handleReactionTap(GroupMessage message, String type) {
    if (message.isDeleted) return;
    final notifier = ref.read(groupChatProvider.notifier);
    if (message.userReaction == type) {
      notifier.removeReaction(message.id);
    } else {
      notifier.addReaction(message.id, type);
    }
  }

  void _showMessageActions(GroupMessage message) {
    final state = ref.read(groupChatProvider);
    final currentUserId = ref.read(customAuthStateProvider).user?.uid;
    final isMe = message.senderId == currentUserId;
    final canModerate = state.groupRole?.hasModerationPrivileges ?? false;
    final canEdit = isMe && !message.isDeleted;
    final canDelete = (isMe || canModerate);
    final canPin = canModerate;
    final isPinned = message.isPinned;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _reactionTypes.map((type) {
                    final isSelected = message.userReaction == type;
                    return IconButton(
                      icon: Icon(
                        _reactionIcon(type),
                        color: isSelected
                            ? Theme.of(sheetContext).colorScheme.primary
                            : Theme.of(sheetContext).colorScheme.outline,
                      ),
                      onPressed: message.isDeleted
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _handleReactionTap(message, type);
                            },
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setReply(message);
                },
              ),
              if (message.replyCount > 0)
                ListTile(
                  leading: const Icon(Icons.forum_outlined),
                  title: Text('View thread (${message.replyCount})'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openThreadView(message);
                  },
                ),
              if (!message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditDialog(message);
                  },
                ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDelete(message);
                  },
                ),
              if (canPin)
                ListTile(
                  leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                  title: Text(isPinned ? 'Unpin' : 'Pin'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (isPinned) {
                      ref.read(groupChatProvider.notifier).unpinMessage(message.id);
                    } else {
                      ref.read(groupChatProvider.notifier).pinMessage(message.id);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(GroupMessage message) async {
    final controller = TextEditingController(text: message.content);
    final rootContext = context;
    await showDialog(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = controller.text.trim();
              if (updated.isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                await ref
                    .read(groupChatProvider.notifier)
                    .editMessage(message.id, updated);
              } catch (e) {
                if (!rootContext.mounted) return;
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text('Edit failed: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _confirmDelete(GroupMessage message) async {
    final rootContext = context;
    final confirmed = await showDialog<bool>(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text('This message will be removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(groupChatProvider.notifier).deleteMessage(message.id);
    } catch (e) {
      if (!rootContext.mounted) return;
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Widget _buildPinnedBanner(ThemeData theme, GroupChatState state) {
    final preview = state.pinnedMessages.first;
    return InkWell(
      onTap: _showPinnedMessages,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.push_pin, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pinned (${state.pinnedMessages.length}): ${preview.content}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  void _showPinnedMessages() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(groupChatProvider);
              final canModerate =
                  state.groupRole?.hasModerationPrivileges ?? false;
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pinned Messages',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: state.pinnedMessages.isEmpty
                          ? const Center(child: Text('No pinned messages'))
                          : ListView.separated(
                              itemCount: state.pinnedMessages.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final message = state.pinnedMessages[index];
                                return ListTile(
                                  title: Text(
                                    message.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${message.senderUsername} - ${timeago.format(message.createdAt)}',
                                  ),
                                  trailing: canModerate
                                      ? IconButton(
                                          icon: const Icon(Icons.push_pin),
                                          onPressed: () => ref
                                              .read(groupChatProvider.notifier)
                                              .unpinMessage(message.id),
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openThreadView(GroupMessage rootMessage) async {
    final controller = TextEditingController();
    final rootContext = context;
    List<GroupMessage> threadMessages = [];
    bool isLoading = true;
    bool didLoad = false;
    String? errorMessage;
    bool isSending = false;

    Future<void> loadThread(StateSetter setState) async {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      try {
        final messages =
            await ref.read(groupChatProvider.notifier).loadThread(rootMessage.id);
        setState(() {
          threadMessages = messages;
          isLoading = false;
        });
      } catch (e) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }

    await showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setState) {
              if (!didLoad) {
                didLoad = true;
                loadThread(setState);
              }
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Thread',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: ListTile(
                          title: Text(rootMessage.senderUsername),
                          subtitle: Text(rootMessage.content),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : errorMessage != null
                              ? Center(child: Text(errorMessage!))
                              : threadMessages.isEmpty
                                  ? const Center(
                                      child: Text('No replies yet'),
                                    )
                                  : ListView.builder(
                                      itemCount: threadMessages.length,
                                      itemBuilder: (context, index) {
                                        final message = threadMessages[index];
                                        return ListTile(
                                          title: Text(message.senderUsername),
                                          subtitle: Text(message.content),
                                          trailing: Text(
                                            timeago.format(message.createdAt),
                                            style:
                                                Theme.of(context).textTheme.bodySmall,
                                          ),
                                        );
                                      },
                                    ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 12,
                        top: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                hintText: 'Reply in thread...',
                                border: OutlineInputBorder(),
                              ),
                              minLines: 1,
                              maxLines: 3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: isSending
                                ? null
                                : () async {
                                    final content = controller.text.trim();
                                    if (content.isEmpty) return;
                                    setState(() => isSending = true);
                                    try {
                                      await ref
                                          .read(groupChatProvider.notifier)
                                          .sendMessage(content,
                                              replyToId: rootMessage.id);
                                      controller.clear();
                                      await loadThread(setState);
                                    } catch (e) {
                                      if (!rootContext.mounted) return;
                                      ScaffoldMessenger.of(rootContext)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Reply failed: $e')),
                                      );
                                    } finally {
                                      setState(() => isSending = false);
                                    }
                                  },
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupChatProvider);
    final theme = Theme.of(context);
    final currentUserId = ref.watch(customAuthStateProvider).user?.uid;
    final totalItems = state.messages.length + state.pendingMessages.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.groupName ?? widget.groupName ?? 'Group Chat'),
            Text(
              'Group Chat',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          if (state.pinnedMessages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.push_pin_outlined),
              onPressed: _showPinnedMessages,
              tooltip: 'Pinned messages',
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.error != null && state.messages.isNotEmpty)
            _buildErrorBanner(theme, state.error!),
          if (state.pinnedMessages.isNotEmpty)
            _buildPinnedBanner(theme, state),
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.messages.isEmpty
                    ? _buildErrorState(theme, state.error!)
                    : state.messages.isEmpty && state.pendingMessages.isEmpty
                        ? _buildEmptyState(theme)
                        : RefreshIndicator(
                            onRefresh: () => ref
                                .read(groupChatProvider.notifier)
                                .loadMessages(),
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: totalItems,
                              itemBuilder: (context, index) {
                                if (index < state.messages.length) {
                                  final message = state.messages[index];
                                  final isMe =
                                      message.senderId == currentUserId;
                                  return _GroupMessageBubble(
                                    message: message,
                                    isMe: isMe,
                                    onLongPress: () =>
                                        _showMessageActions(message),
                                    onReactionTap: (type) =>
                                        _handleReactionTap(message, type),
                                    onViewThread: () =>
                                        _openThreadView(message),
                                  );
                                }

                                final pendingIndex =
                                    index - state.messages.length;
                                final pending =
                                    state.pendingMessages[pendingIndex];
                                return _PendingGroupMessageBubble(
                                  message: pending,
                                  onRetry: () => ref
                                      .read(groupChatProvider.notifier)
                                      .retryPendingMessage(pending.tempId),
                                );
                              },
                            ),
                          ),
          ),
          if (_replyToContent != null) _buildReplyPreview(theme),
          _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme, String error) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: theme.colorScheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(groupChatProvider.notifier).loadMessages(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Failed to load messages',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.read(groupChatProvider.notifier).loadMessages(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
          left: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  _replyToContent!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
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
    );
  }
}

class _GroupMessageBubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMe;
  final VoidCallback onLongPress;
  final ValueChanged<String> onReactionTap;
  final VoidCallback onViewThread;

  const _GroupMessageBubble({
    required this.message,
    required this.isMe,
    required this.onLongPress,
    required this.onReactionTap,
    required this.onViewThread,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: message.senderAvatarUrl != null
                  ? NetworkImage(message.senderAvatarUrl!)
                  : null,
              child: message.senderAvatarUrl == null
                  ? Text(
                      message.senderUsername[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderUsername,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    if (message.replyToContent != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? theme.colorScheme.onPrimary
                                  .withValues(alpha: 0.1)
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isMe
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          message.replyToContent!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isMe
                                ? theme.colorScheme.onPrimary
                                    .withValues(alpha: 0.8)
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontStyle:
                            message.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    if (!message.isDeleted && message.reactions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: message.reactions.map((reaction) {
                          final isSelected = message.userReaction == reaction.type;
                          return InkWell(
                            onTap: () => onReactionTap(reaction.type),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isMe
                                        ? theme.colorScheme.onPrimary
                                            .withValues(alpha: 0.2)
                                        : theme.colorScheme.primaryContainer)
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _reactionIcon(reaction.type),
                                    size: 14,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    reaction.count.toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeago.format(message.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? theme.colorScheme.onPrimary
                                    .withValues(alpha: 0.7)
                                : theme.colorScheme.outline,
                          ),
                        ),
                        if (message.editedAt != null && !message.isDeleted) ...[
                          Text(
                            ' (edited)',
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? theme.colorScheme.onPrimary
                                      .withValues(alpha: 0.7)
                                  : theme.colorScheme.outline,
                            ),
                          ),
                        ],
                        if (message.isPinned) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.push_pin,
                            size: 12,
                            color: isMe
                                ? theme.colorScheme.onPrimary
                                    .withValues(alpha: 0.7)
                                : theme.colorScheme.outline,
                          ),
                        ],
                      ],
                    ),
                    if (message.replyCount > 0)
                      TextButton(
                        onPressed: onViewThread,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'View thread (${message.replyCount})',
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe
                                ? theme.colorScheme.onPrimary
                                    .withValues(alpha: 0.8)
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _PendingGroupMessageBubble extends StatelessWidget {
  final PendingGroupMessage message;
  final VoidCallback onRetry;

  const _PendingGroupMessageBubble({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = message.status == PendingSendStatus.failed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: isFailed ? onRetry : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.replyToContent != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onPrimary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.onPrimary,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          message.replyToContent!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onPrimary
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    Text(
                      message.content,
                      style: TextStyle(color: theme.colorScheme.onPrimary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFailed ? Icons.error_outline : Icons.schedule,
                          size: 12,
                          color: theme.colorScheme.onPrimary
                              .withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isFailed ? 'Tap to retry' : 'Sending...',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onPrimary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
