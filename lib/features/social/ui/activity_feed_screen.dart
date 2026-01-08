import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../social_provider.dart';
import '../models/activity.dart';
import 'package:timeago/timeago.dart' as timeago;

class ActivityFeedScreen extends ConsumerStatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  ConsumerState<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ConsumerState<ActivityFeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    debugPrint('[ActivityFeedScreen] initState called');
    Future.microtask(() {
      debugPrint('[ActivityFeedScreen] Loading feed...');
      ref.read(activityFeedProvider.notifier).loadFeed(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = ref.read(activityFeedProvider);
      if (!state.isLoading && state.hasMore) {
        ref.read(activityFeedProvider.notifier).loadFeed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityFeedProvider);
    debugPrint(
        '[ActivityFeedScreen] build - isLoading: ${state.isLoading}, activities: ${state.activities.length}, error: ${state.error}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              debugPrint('[ActivityFeedScreen] Manual refresh triggered');
              ref.read(activityFeedProvider.notifier).loadFeed(refresh: true);
            },
          ),
        ],
      ),
      body: state.error != null
          ? _buildErrorState(state.error!)
          : state.isLoading && state.activities.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.activities.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(activityFeedProvider.notifier)
                          .loadFeed(refresh: true),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            state.activities.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= state.activities.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          return _ActivityCard(
                            activity: state.activities[index],
                            onReact: (type) => ref
                                .read(activityFeedProvider.notifier)
                                .addReaction(state.activities[index].id, type),
                            onRemoveReaction: () => ref
                                .read(activityFeedProvider.notifier)
                                .removeReaction(state.activities[index].id),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading feed',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(activityFeedProvider.notifier)
                  .loadFeed(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dynamic_feed_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add friends to see their activity',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Activity activity;
  final Function(String) onReact;
  final VoidCallback onRemoveReaction;

  const _ActivityCard({
    required this.activity,
    required this.onReact,
    required this.onRemoveReaction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: activity.avatarUrl != null
                      ? NetworkImage(activity.avatarUrl!)
                      : null,
                  child: activity.avatarUrl == null
                      ? Text(activity.username?[0].toUpperCase() ?? '?')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.username ?? 'Unknown',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        timeago.format(activity.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Text(activity.icon, style: const TextStyle(fontSize: 24)),
              ],
            ),
            const SizedBox(height: 12),
            Text(activity.title, style: theme.textTheme.bodyLarge),
            if (activity.description != null) ...[
              const SizedBox(height: 4),
              Text(activity.description!,
                  style: TextStyle(color: Colors.grey[600])),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _ReactionButton(
                  icon: '👍',
                  isSelected: activity.userReaction == 'like',
                  onTap: () => activity.userReaction == 'like'
                      ? onRemoveReaction()
                      : onReact('like'),
                ),
                _ReactionButton(
                  icon: '🎉',
                  isSelected: activity.userReaction == 'celebrate',
                  onTap: () => activity.userReaction == 'celebrate'
                      ? onRemoveReaction()
                      : onReact('celebrate'),
                ),
                _ReactionButton(
                  icon: '💪',
                  isSelected: activity.userReaction == 'support',
                  onTap: () => activity.userReaction == 'support'
                      ? onRemoveReaction()
                      : onReact('support'),
                ),
                _ReactionButton(
                  icon: '❤️',
                  isSelected: activity.userReaction == 'love',
                  onTap: () => activity.userReaction == 'love'
                      ? onRemoveReaction()
                      : onReact('love'),
                ),
                const Spacer(),
                if (activity.reactionCount > 0)
                  Text(
                    '${activity.reactionCount} reactions',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.primary)
              : null,
        ),
        child: Text(icon, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
