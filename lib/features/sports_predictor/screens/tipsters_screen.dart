import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/sports_models.dart';
import '../providers/match_analysis_provider.dart';

class TipstersScreen extends ConsumerWidget {
  const TipstersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tipstersProvider);
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tipsters'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Discover'),
              Tab(text: 'Following'),
            ],
          ),
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Discover tab
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.tipsters.length,
                    itemBuilder: (context, index) {
                      return _TipsterCard(
                        tipster: state.tipsters[index],
                        onFollow: () => ref
                            .read(tipstersProvider.notifier)
                            .followTipster(state.tipsters[index].id),
                        onUnfollow: () => ref
                            .read(tipstersProvider.notifier)
                            .unfollowTipster(state.tipsters[index].id),
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: index * 50));
                    },
                  ),

                  // Following tab
                  state.following.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.users,
                                  size: 64, color: scheme.outline),
                              const SizedBox(height: 16),
                              Text('Not following anyone yet',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(
                                'Follow tipsters to see their picks',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: scheme.outline),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.following.length,
                          itemBuilder: (context, index) {
                            return _TipsterCard(
                              tipster: state.following[index],
                              onFollow: () => ref
                                  .read(tipstersProvider.notifier)
                                  .followTipster(state.following[index].id),
                              onUnfollow: () => ref
                                  .read(tipstersProvider.notifier)
                                  .unfollowTipster(state.following[index].id),
                            );
                          },
                        ),
                ],
              ),
      ),
    );
  }
}

class _TipsterCard extends StatelessWidget {
  final Tipster tipster;
  final VoidCallback onFollow;
  final VoidCallback onUnfollow;

  const _TipsterCard({
    required this.tipster,
    required this.onFollow,
    required this.onUnfollow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

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
                  radius: 28,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    tipster.username[0].toUpperCase(),
                    style:
                        text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(tipster.username,
                              style: text.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          if (tipster.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(LucideIcons.badgeCheck,
                                size: 18, color: Colors.blue),
                          ],
                        ],
                      ),
                      Text(
                        '${tipster.followers} followers • ${tipster.totalTips} tips',
                        style: text.labelSmall?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
                tipster.isFollowing
                    ? OutlinedButton(
                        onPressed: onUnfollow, child: const Text('Following'))
                    : FilledButton(
                        onPressed: onFollow, child: const Text('Follow')),
              ],
            ),
            const SizedBox(height: 12),
            Text(tipster.bio,
                style: text.bodySmall
                    ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.8))),
            const SizedBox(height: 12),

            // Stats
            Row(
              children: [
                _StatChip(
                  icon: LucideIcons.percent,
                  label: 'Win Rate',
                  value: '${tipster.winRate.toStringAsFixed(1)}%',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: LucideIcons.trendingUp,
                  label: 'ROI',
                  value: '+${tipster.roi.toStringAsFixed(1)}%',
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Specialties
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tipster.specialties
                  .map((s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color)),
              Text(value,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
