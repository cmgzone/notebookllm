import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'gamification_provider.dart';
import 'achievement.dart';
import 'daily_challenge.dart';

/// Main hub for gamification features
class GamificationHubScreen extends ConsumerWidget {
  const GamificationHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gamificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress & Rewards'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level & XP Card
            _LevelCard(stats: state.stats)
                .animate()
                .fadeIn()
                .slideY(begin: -0.2),

            const SizedBox(height: 24),

            // Quick Stats Row
            Row(
              children: [
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.local_fire_department,
                    iconColor: Colors.orange,
                    value: '${state.stats.currentStreak}',
                    label: 'Day Streak',
                    onTap: () => context.push('/daily-challenges'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.emoji_events,
                    iconColor: Colors.amber,
                    value: '${state.unlockedCount}/${state.totalAchievements}',
                    label: 'Achievements',
                    onTap: () => context.push('/achievements'),
                  ),
                ),
              ],
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Daily Challenges Preview
            _SectionHeader(
              title: "Today's Challenges",
              icon: Icons.flag,
              actionLabel: 'View All',
              onAction: () => context.push('/daily-challenges'),
            ),
            const SizedBox(height: 12),
            _DailyChallengesPreview(challenges: state.todaysChallenges)
                .animate(delay: 200.ms)
                .fadeIn()
                .slideX(begin: 0.1),

            const SizedBox(height: 24),

            // Recent Achievements
            _SectionHeader(
              title: 'Recent Achievements',
              icon: Icons.workspace_premium,
              actionLabel: 'View All',
              onAction: () => context.push('/achievements'),
            ),
            const SizedBox(height: 12),
            _RecentAchievements(
              achievements:
                  state.achievements.where((a) => a.isUnlocked).toList()
                    ..sort((a, b) => (b.unlockedAt ?? DateTime(2000))
                        .compareTo(a.unlockedAt ?? DateTime(2000))),
            ).animate(delay: 300.ms).fadeIn().slideX(begin: 0.1),

            const SizedBox(height: 24),

            // Activity Stats
            const _SectionHeader(
              title: 'Your Activity',
              icon: Icons.insights,
            ),
            const SizedBox(height: 12),
            _ActivityStats(stats: state.stats)
                .animate(delay: 400.ms)
                .fadeIn()
                .slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final UserStats stats;

  const _LevelCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Level circle
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: stats.levelProgress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${stats.level}',
                          style: text.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'LEVEL',
                          style: text.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getLevelTitle(stats.level),
                      style: text.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${stats.totalXp} XP Total',
                      style: text.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.xpForNextLevel - stats.xpInCurrentLevel} XP to Level ${stats.level + 1}',
                      style: text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLevelTitle(int level) {
    if (level < 5) return 'Beginner';
    if (level < 10) return 'Learner';
    if (level < 20) return 'Scholar';
    if (level < 35) return 'Expert';
    if (level < 50) return 'Master';
    return 'Grandmaster';
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _QuickStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: text.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, color: scheme.primary, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _DailyChallengesPreview extends StatelessWidget {
  final List<dynamic> challenges;

  const _DailyChallengesPreview({required this.challenges});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (challenges.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No challenges today',
              style: text.bodyMedium?.copyWith(color: scheme.outline),
            ),
          ),
        ),
      );
    }

    final completedCount = challenges.where((c) => c.isCompleted).length;
    final progress =
        challenges.isNotEmpty ? completedCount / challenges.length : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$completedCount of ${challenges.length} Complete',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor:
                              scheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: completedCount == challenges.length
                        ? Colors.green.withValues(alpha: 0.1)
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    completedCount == challenges.length
                        ? Icons.check_circle
                        : Icons.flag,
                    color: completedCount == challenges.length
                        ? Colors.green
                        : scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...challenges.take(3).map((challenge) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        challenge.isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: challenge.isCompleted
                            ? Colors.green
                            : scheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          challenge.title,
                          style: text.bodyMedium?.copyWith(
                            decoration: challenge.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color:
                                challenge.isCompleted ? scheme.outline : null,
                          ),
                        ),
                      ),
                      Text(
                        '+${challenge.xpReward} XP',
                        style: text.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _RecentAchievements extends StatelessWidget {
  final List<Achievement> achievements;

  const _RecentAchievements({required this.achievements});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (achievements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.emoji_events, size: 48, color: scheme.outline),
                const SizedBox(height: 8),
                Text(
                  'No achievements yet',
                  style: text.bodyMedium?.copyWith(color: scheme.outline),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete activities to earn badges!',
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: achievements.take(5).length,
        itemBuilder: (context, index) {
          final achievement = achievements[index];
          return Container(
            width: 100,
            margin: EdgeInsets.only(right: index < 4 ? 12 : 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: achievement.tier.color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        achievement.icon,
                        color: achievement.tier.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      achievement.title,
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityStats extends StatelessWidget {
  final UserStats stats;

  const _ActivityStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ActivityRow(
              icon: Icons.quiz,
              label: 'Quizzes Completed',
              value: '${stats.quizzesCompleted}',
              color: Colors.blue,
            ),
            const Divider(),
            _ActivityRow(
              icon: Icons.style,
              label: 'Flashcards Reviewed',
              value: '${stats.flashcardsReviewed}',
              color: Colors.purple,
            ),
            const Divider(),
            _ActivityRow(
              icon: Icons.school,
              label: 'Tutor Sessions',
              value: '${stats.tutorSessionsCompleted}',
              color: Colors.green,
            ),
            const Divider(),
            _ActivityRow(
              icon: Icons.chat,
              label: 'AI Messages',
              value: '${stats.chatMessagesSent}',
              color: Colors.orange,
            ),
            const Divider(),
            _ActivityRow(
              icon: Icons.book,
              label: 'Notebooks Created',
              value: '${stats.notebooksCreated}',
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ActivityRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: text.bodyMedium),
          ),
          Text(
            value,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
