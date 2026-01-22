import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/custom_auth_service.dart';
import '../../notebook/notebook_provider.dart';
import '../social_provider.dart';
import 'edit_profile_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/components/premium_card.dart';
import '../../../ui/components/glass_container.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    ref.read(friendsProvider.notifier).loadFriends();
    ref.read(studyGroupsProvider.notifier).loadGroups();
    ref.read(activityFeedProvider.notifier).loadFeed(refresh: true);
    ref.read(notebookProvider.notifier).loadNotebooks();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(customAuthStateProvider);
    final isMe = widget.userId == null || widget.userId == authState.user?.uid;

    final user = isMe ? authState.user : null;

    final notebooks = ref.watch(notebookProvider);
    final friendsState = ref.watch(friendsProvider);
    final groupsState = ref.watch(studyGroupsProvider);
    final activityState = ref.watch(activityFeedProvider);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (user == null && isMe) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              stretch: true,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (user.coverUrl != null)
                      CachedNetworkImage(
                        imageUrl: user.coverUrl!,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: AppTheme.premiumGradient,
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 45,
                              backgroundColor: scheme.primaryContainer,
                              backgroundImage: user.avatarUrl != null
                                  ? CachedNetworkImageProvider(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null
                                  ? Icon(LucideIcons.user,
                                      size: 40,
                                      color: scheme.onPrimaryContainer)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user.displayName ?? 'Anonymous User',
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  user.email,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (isMe)
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                          alpha: 0.2), // Subtle background for visibility
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(LucideIcons.edit2,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen()),
                      ),
                      tooltip: 'Edit Profile',
                    ),
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat(context, '${notebooks.length}',
                              'Notebooks', LucideIcons.book),
                          _buildStat(context, '${friendsState.friends.length}',
                              'Friends', LucideIcons.users),
                          _buildStat(context, '${groupsState.groups.length}',
                              'Groups', LucideIcons.layers),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                    const SizedBox(height: 32),

                    Text(
                      'Recent Activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (activityState.isLoading &&
                        activityState.activities.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else if (activityState.activities.isEmpty)
                      _buildEmptyActivity(theme)
                    else
                      ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activityState.activities.take(5).length,
                        itemBuilder: (context, index) {
                          final activity = activityState.activities[index];
                          return _buildActivityItem(context, activity);
                        },
                      ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 32),

                    if (isMe) ...[
                      Text(
                        'Account Settings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildActionTile(
                        context,
                        icon: LucideIcons.shield,
                        title: 'Privacy and Security',
                        onTap: () => context.push('/security'),
                      ),
                      _buildActionTile(
                        context,
                        icon: LucideIcons.bell,
                        title: 'Notifications',
                        onTap: () => context.push('/notifications'),
                      ),
                      _buildActionTile(
                        context,
                        icon: LucideIcons.logOut,
                        title: 'Sign Out',
                        color: Colors.red,
                        onTap: () async {
                          await ref
                              .read(customAuthStateProvider.notifier)
                              .signOut();
                          if (context.mounted) context.go('/login');
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyActivity(ThemeData theme) {
    return PremiumCard(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              LucideIcons.activity,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No recent activity',
              style: TextStyle(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, dynamic activity) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () {},
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getActivityIcon(activity.activityType),
                size: 20,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.yMMMd().add_jm().format(activity.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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

  IconData _getActivityIcon(dynamic type) {
    final typeStr = type.toString().toLowerCase();
    if (typeStr.contains('notebook')) return LucideIcons.book;
    if (typeStr.contains('friend')) return LucideIcons.userPlus;
    if (typeStr.contains('group')) return LucideIcons.layers;
    if (typeStr.contains('ebook')) return LucideIcons.bookOpen;
    return LucideIcons.activity;
  }

  Widget _buildStat(
      BuildContext context, String value, String label, IconData icon) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: scheme.primary, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? scheme.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color ?? scheme.primary, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: color ?? scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Icon(LucideIcons.chevronRight,
              size: 16, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
