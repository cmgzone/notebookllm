import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../social_provider.dart';
import '../chat_provider.dart';
import 'friends_screen.dart';
import 'study_groups_screen.dart';
import 'activity_feed_screen.dart';
import 'social_leaderboard_screen.dart';
import 'conversations_screen.dart';

class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key});

  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen> {
  @override
  void initState() {
    super.initState();
    // Preload data
    Future.microtask(() {
      ref.read(friendsProvider.notifier).loadFriends();
      ref.read(friendsProvider.notifier).loadRequests();
      ref.read(studyGroupsProvider.notifier).loadGroups();
      ref.read(studyGroupsProvider.notifier).loadInvitations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsProvider);
    final groupsState = ref.watch(studyGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(friendsProvider.notifier).loadFriends();
              ref.read(studyGroupsProvider.notifier).loadGroups();
            },
          ),
        ],
      ),
      body: friendsState.error != null || groupsState.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading social data',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (friendsState.error != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        friendsState.error!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(friendsProvider.notifier).loadFriends();
                      ref.read(studyGroupsProvider.notifier).loadGroups();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Quick stats
                Row(
                  children: [
                    Expanded(
                      child: _QuickStatCard(
                        icon: Icons.people,
                        label: 'Friends',
                        value: '${friendsState.friends.length}',
                        color: Colors.blue,
                        onTap: () => _navigateTo(const FriendsScreen()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickStatCard(
                        icon: Icons.groups,
                        label: 'Groups',
                        value: '${groupsState.groups.length}',
                        color: Colors.green,
                        onTap: () => _navigateTo(const StudyGroupsScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Main navigation cards
                _NavigationCard(
                  icon: Icons.dynamic_feed,
                  title: 'Activity Feed',
                  subtitle: 'See what your friends are up to',
                  color: Colors.purple,
                  onTap: () => _navigateTo(const ActivityFeedScreen()),
                ),
                const SizedBox(height: 12),
                _NavigationCard(
                  icon: Icons.leaderboard,
                  title: 'Leaderboard',
                  subtitle: 'Compete with friends and globally',
                  color: Colors.orange,
                  onTap: () => _navigateTo(const SocialLeaderboardScreen()),
                ),
                const SizedBox(height: 12),
                _NavigationCard(
                  icon: Icons.people,
                  title: 'Friends',
                  subtitle: 'Manage your friends and requests',
                  color: Colors.blue,
                  badge: friendsState.receivedRequests.isNotEmpty
                      ? '${friendsState.receivedRequests.length}'
                      : null,
                  onTap: () => _navigateTo(const FriendsScreen()),
                ),
                const SizedBox(height: 12),
                _MessagesCard(),
                const SizedBox(height: 12),
                _NavigationCard(
                  icon: Icons.groups,
                  title: 'Study Groups',
                  subtitle: 'Join or create study groups',
                  color: Colors.green,
                  badge: groupsState.invitations.isNotEmpty
                      ? '${groupsState.invitations.length}'
                      : null,
                  onTap: () => _navigateTo(const StudyGroupsScreen()),
                ),
              ],
            ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _NavigationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(badge!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadCountsProvider);

    return unreadAsync.when(
      data: (unread) => _NavigationCard(
        icon: Icons.chat,
        title: 'Messages',
        subtitle: 'Chat with your friends',
        color: Colors.teal,
        badge: unread.direct > 0 ? '${unread.direct}' : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConversationsScreen()),
        ),
      ),
      loading: () => _NavigationCard(
        icon: Icons.chat,
        title: 'Messages',
        subtitle: 'Chat with your friends',
        color: Colors.teal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConversationsScreen()),
        ),
      ),
      error: (_, __) => _NavigationCard(
        icon: Icons.chat,
        title: 'Messages',
        subtitle: 'Chat with your friends',
        color: Colors.teal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConversationsScreen()),
        ),
      ),
    );
  }
}
