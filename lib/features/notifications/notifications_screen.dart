import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'notification_provider.dart';
import 'notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllAsRead(),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettingsSheet(context),
            tooltip: 'Notification Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(notificationProvider.notifier)
            .fetchNotifications(refresh: true),
        child: state.isLoading && state.notifications.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.notifications.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    itemCount: state.notifications.length,
                    itemBuilder: (context, index) {
                      final notification = state.notifications[index];
                      return _NotificationTile(
                        notification: notification,
                        onTap: () => _handleNotificationTap(notification),
                        onDismiss: () => ref
                            .read(notificationProvider.notifier)
                            .deleteNotification(notification.id),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Text(
            "You're all caught up!",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(AppNotification notification) {
    // Mark as read
    if (!notification.isRead) {
      ref.read(notificationProvider.notifier).markAsRead(notification.id);
    }

    // Navigate to action URL if present
    if (notification.actionUrl != null && notification.actionUrl!.isNotEmpty) {
      context.push(notification.actionUrl!);
    }
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _NotificationSettingsSheet(),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  IconData _getIcon() {
    switch (notification.type) {
      case 'message':
        return Icons.chat_bubble;
      case 'friend_request':
        return Icons.person_add;
      case 'achievement':
        return Icons.emoji_events;
      case 'group_invite':
        return Icons.group_add;
      case 'group_message':
        return Icons.forum;
      case 'study_reminder':
        return Icons.schedule;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(ThemeData theme) {
    switch (notification.type) {
      case 'message':
        return Colors.blue;
      case 'friend_request':
        return Colors.green;
      case 'achievement':
        return Colors.amber;
      case 'group_invite':
        return Colors.purple;
      case 'group_message':
        return Colors.teal;
      case 'study_reminder':
        return Colors.orange;
      case 'system':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _getIconColor(theme).withValues(alpha: 0.1),
          child: Icon(_getIcon(), color: _getIconColor(theme), size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.body != null)
              Text(
                notification.body!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              timeago.format(notification.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        tileColor: notification.isRead
            ? null
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
      ),
    );
  }
}

class _NotificationSettingsSheet extends ConsumerStatefulWidget {
  const _NotificationSettingsSheet();

  @override
  ConsumerState<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends ConsumerState<_NotificationSettingsSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationProvider.notifier).fetchSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final settings = state.settings;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('Notification Settings',
                        style: theme.textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (settings == null)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSection('Notification Types', [
                        _buildSwitch('Messages', settings.messagesEnabled,
                            'messagesEnabled'),
                        _buildSwitch(
                            'Friend Requests',
                            settings.friendRequestsEnabled,
                            'friendRequestsEnabled'),
                        _buildSwitch(
                            'Achievements',
                            settings.achievementsEnabled,
                            'achievementsEnabled'),
                        _buildSwitch(
                            'Group Invites',
                            settings.groupInvitesEnabled,
                            'groupInvitesEnabled'),
                        _buildSwitch(
                            'Group Messages',
                            settings.groupMessagesEnabled,
                            'groupMessagesEnabled'),
                        _buildSwitch(
                            'Study Reminders',
                            settings.studyRemindersEnabled,
                            'studyRemindersEnabled'),
                        _buildSwitch(
                            'System', settings.systemEnabled, 'systemEnabled'),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection('Delivery', [
                        _buildSwitch('Push Notifications',
                            settings.pushNotifications, 'pushNotifications'),
                        _buildSwitch('Email Notifications',
                            settings.emailNotifications, 'emailNotifications'),
                      ]),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildSwitch(String label, bool value, String key) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: (newValue) {
        ref.read(notificationProvider.notifier).updateSettings({key: newValue});
      },
      contentPadding: EdgeInsets.zero,
    );
  }
}
