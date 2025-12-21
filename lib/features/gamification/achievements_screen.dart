import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'achievement.dart';
import 'daily_challenge.dart';
import 'gamification_provider.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(gamificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${state.unlockedCount}/${state.totalAchievements}',
                style: text.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Stats header
          SliverToBoxAdapter(
            child: _StatsHeader(stats: state.stats),
          ),

          // Category filter
          SliverPersistentHeader(
            pinned: true,
            delegate: _CategoryHeaderDelegate(
              achievements: state.achievements,
            ),
          ),

          // Achievements grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final achievement = state.achievements[index];
                  return _AchievementCard(
                    achievement: achievement,
                    index: index,
                  );
                },
                childCount: state.achievements.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final UserStats stats;

  const _StatsHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Level badge
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${stats.level}',
                        style: text.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'LEVEL',
                        style: text.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stats.totalXp} XP',
                      style: text.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: stats.levelProgress,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.xpInCurrentLevel}/${stats.xpForNextLevel} to next level',
                      style: text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.local_fire_department,
                value: '${stats.currentStreak}',
                label: 'Day Streak',
              ),
              _StatItem(
                icon: Icons.emoji_events,
                value: '${stats.longestStreak}',
                label: 'Best Streak',
              ),
              _StatItem(
                icon: Icons.quiz,
                value: '${stats.quizzesCompleted}',
                label: 'Quizzes',
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<Achievement> achievements;

  _CategoryHeaderDelegate({required this.achievements});

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: AchievementCategory.values.map((category) {
            final count = achievements
                .where((a) => a.category == category && a.isUnlocked)
                .length;
            final total =
                achievements.where((a) => a.category == category).length;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(category.icon, size: 18),
                label: Text('${category.displayName} $count/$total'),
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 60;

  @override
  double get minExtent => 60;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final int index;

  const _AchievementCard({
    required this.achievement,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isUnlocked = achievement.isUnlocked;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isUnlocked ? null : scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Stack(
          children: [
            // Background gradient for unlocked
            if (isUnlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        achievement.tier.color.withValues(alpha: 0.1),
                        achievement.tier.color.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with tier color
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? achievement.tier.color.withValues(alpha: 0.2)
                          : scheme.outline.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isUnlocked
                            ? achievement.tier.color
                            : scheme.outline.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      achievement.icon,
                      size: 28,
                      color: isUnlocked
                          ? achievement.tier.color
                          : scheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    achievement.title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? null : scheme.outline,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Tier badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? achievement.tier.color.withValues(alpha: 0.2)
                          : scheme.outline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      achievement.tier.displayName,
                      style: text.labelSmall?.copyWith(
                        color: isUnlocked
                            ? achievement.tier.color
                            : scheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress bar
                  if (!isUnlocked) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: achievement.progress,
                        minHeight: 6,
                        backgroundColor: scheme.outline.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(scheme.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${achievement.currentValue}/${achievement.targetValue}',
                      style: text.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Unlocked',
                          style: text.labelSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Lock overlay
            if (!isUnlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.lock,
                  size: 16,
                  color: scheme.outline.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 50)).fadeIn().scale(
          begin: const Offset(0.9, 0.9),
        );
  }

  void _showDetails(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: achievement.isUnlocked
                    ? achievement.tier.color.withValues(alpha: 0.2)
                    : scheme.outline.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: achievement.isUnlocked
                      ? achievement.tier.color
                      : scheme.outline,
                  width: 3,
                ),
              ),
              child: Icon(
                achievement.icon,
                size: 40,
                color: achievement.isUnlocked
                    ? achievement.tier.color
                    : scheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              achievement.title,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: achievement.tier.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${achievement.tier.displayName} • +${achievement.tier.xpReward} XP',
                style: TextStyle(
                  color: achievement.tier.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              achievement.description,
              style: text.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (!achievement.isUnlocked) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: achievement.progress,
                  minHeight: 12,
                  backgroundColor: scheme.outline.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Progress: ${achievement.currentValue}/${achievement.targetValue}',
                style: text.bodyMedium?.copyWith(color: scheme.outline),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Unlocked ${_formatDate(achievement.unlockedAt!)}',
                    style: text.bodyMedium?.copyWith(color: Colors.green),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
