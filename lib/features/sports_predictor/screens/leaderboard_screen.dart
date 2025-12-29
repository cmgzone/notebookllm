import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/sports_models.dart';
import '../providers/live_sports_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.read(leaderboardProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Timeframe selector
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: ['daily', 'weekly', 'monthly', 'allTime'].map((tf) {
                final isSelected = state.timeframe == tf;
                final label = tf == 'allTime'
                    ? 'All Time'
                    : tf[0].toUpperCase() + tf.substring(1);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (_) => ref
                          .read(leaderboardProvider.notifier)
                          .setTimeframe(tf),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Top 3 podium
          if (state.entries.length >= 3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 2nd place
                  Expanded(
                      child: _PodiumCard(entry: state.entries[1], position: 2)),
                  const SizedBox(width: 8),
                  // 1st place
                  Expanded(
                      child: _PodiumCard(entry: state.entries[0], position: 1)),
                  const SizedBox(width: 8),
                  // 3rd place
                  Expanded(
                      child: _PodiumCard(entry: state.entries[2], position: 3)),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.2),

          const SizedBox(height: 16),

          // Rest of leaderboard
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount:
                        state.entries.length > 3 ? state.entries.length - 3 : 0,
                    itemBuilder: (context, index) {
                      final entry = state.entries[index + 3];
                      return _LeaderboardTile(entry: entry)
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: index * 50));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final int position;

  const _PodiumCard({required this.entry, required this.position});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final height = position == 1
        ? 180.0
        : position == 2
            ? 150.0
            : 130.0;
    final medal = position == 1
        ? '🥇'
        : position == 2
            ? '🥈'
            : '🥉';
    final color = position == 1
        ? Colors.amber
        : position == 2
            ? Colors.grey.shade400
            : Colors.brown.shade300;

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(medal, style: TextStyle(fontSize: position == 1 ? 32 : 24)),
          const SizedBox(height: 4),
          CircleAvatar(
            radius: position == 1 ? 24 : 20,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              entry.username[0].toUpperCase(),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: position == 1 ? 18 : 14),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.username,
            style: text.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${entry.winRate.toStringAsFixed(1)}%',
            style: text.titleSmall
                ?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          if (entry.badges.isNotEmpty)
            Text(entry.badges.take(3).join(' '),
                style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;

  const _LeaderboardTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: text.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.secondaryContainer,
            child: Text(entry.username[0].toUpperCase()),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(entry.username,
                        style: text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (entry.badges.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(entry.badges.first,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                Text(
                  '${entry.totalPredictions} predictions • ${entry.wins}W-${entry.losses}L',
                  style: text.labelSmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),

          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.winRate.toStringAsFixed(1)}%',
                style: text.titleSmall?.copyWith(
                    color: Colors.green, fontWeight: FontWeight.bold),
              ),
              Text(
                '+\$${entry.profit.toStringAsFixed(0)}',
                style: text.labelSmall?.copyWith(color: scheme.outline),
              ),
            ],
          ),

          // Streak
          if (entry.streak > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.flame, size: 12, color: Colors.orange),
                  Text('${entry.streak}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
