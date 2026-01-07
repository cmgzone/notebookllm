import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../social_provider.dart';
import '../models/activity.dart';

class SocialLeaderboardScreen extends ConsumerStatefulWidget {
  const SocialLeaderboardScreen({super.key});

  @override
  ConsumerState<SocialLeaderboardScreen> createState() =>
      _SocialLeaderboardScreenState();
}

class _SocialLeaderboardScreenState
    extends ConsumerState<SocialLeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(leaderboardProvider.notifier).loadLeaderboard());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leaderboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: Column(
        children: [
          _buildFilters(state, theme),
          if (state.userRank != null)
            _buildUserRankCard(state.userRank!, theme),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.entries.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.entries.length,
                        itemBuilder: (context, index) {
                          return _LeaderboardTile(
                            entry: state.entries[index],
                            isTop3: index < 3,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(LeaderboardState state, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Type toggle
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'global',
                  label: Text('Global'),
                  icon: Icon(Icons.public)),
              ButtonSegment(
                  value: 'friends',
                  label: Text('Friends'),
                  icon: Icon(Icons.people)),
            ],
            selected: {state.type},
            onSelectionChanged: (selected) {
              ref
                  .read(leaderboardProvider.notifier)
                  .loadLeaderboard(type: selected.first);
            },
          ),
          const SizedBox(height: 12),
          // Period and metric
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: state.period,
                  decoration: const InputDecoration(
                    labelText: 'Period',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Today')),
                    DropdownMenuItem(value: 'weekly', child: Text('This Week')),
                    DropdownMenuItem(
                        value: 'monthly', child: Text('This Month')),
                    DropdownMenuItem(
                        value: 'all_time', child: Text('All Time')),
                  ],
                  onChanged: (v) => ref
                      .read(leaderboardProvider.notifier)
                      .loadLeaderboard(period: v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: state.metric,
                  decoration: const InputDecoration(
                    labelText: 'Metric',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'xp', child: Text('XP')),
                    DropdownMenuItem(value: 'quizzes', child: Text('Quizzes')),
                    DropdownMenuItem(
                        value: 'flashcards', child: Text('Flashcards')),
                    DropdownMenuItem(value: 'streak', child: Text('Streak')),
                  ],
                  onChanged: (v) => ref
                      .read(leaderboardProvider.notifier)
                      .loadLeaderboard(metric: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserRankCard(UserRank rank, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _RankStat(
              label: 'Your Rank', value: rank.rank > 0 ? '#${rank.rank}' : '-'),
          _RankStat(label: 'Score', value: '${rank.score}'),
          _RankStat(label: 'Total Users', value: '${rank.totalUsers}'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No rankings yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Complete activities to appear on the leaderboard',
              style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _RankStat extends StatelessWidget {
  final String label;
  final String value;

  const _RankStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isTop3;

  const _LeaderboardTile({required this.entry, required this.isTop3});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: entry.isCurrentUser ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: _buildRankBadge(theme),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.username,
                style: TextStyle(
                  fontWeight:
                      entry.isCurrentUser ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (entry.isFriend)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Friend',
                    style: TextStyle(fontSize: 10, color: Colors.blue)),
              ),
            if (entry.isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('You',
                    style: TextStyle(
                        fontSize: 10, color: theme.colorScheme.onPrimary)),
              ),
          ],
        ),
        trailing: Text(
          '${entry.score}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildRankBadge(ThemeData theme) {
    if (isTop3) {
      final colors = [Colors.amber, Colors.grey[400]!, Colors.brown[300]!];
      final icons = ['🥇', '🥈', '🥉'];
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors[entry.rank - 1],
          shape: BoxShape.circle,
        ),
        child: Center(
          child:
              Text(icons[entry.rank - 1], style: const TextStyle(fontSize: 20)),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${entry.rank}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
