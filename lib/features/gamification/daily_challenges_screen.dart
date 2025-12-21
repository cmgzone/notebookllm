import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'daily_challenge.dart';
import 'gamification_provider.dart';

class DailyChallengesScreen extends ConsumerWidget {
  const DailyChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(gamificationProvider);
    final todaysChallenges = state.todaysChallenges;
    final completedCount = state.completedTodayCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Challenges'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            _HeaderCard(
              stats: state.stats,
              completedCount: completedCount,
              totalCount: todaysChallenges.length,
            ).animate().fadeIn().slideY(begin: -0.2),

            const SizedBox(height: 24),

            // Today's challenges
            Row(
              children: [
                Icon(Icons.today, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  "Today's Challenges",
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (todaysChallenges.isEmpty)
              _EmptyState()
            else
              ...todaysChallenges.asMap().entries.map((entry) {
                return _ChallengeCard(
                  challenge: entry.value,
                  index: entry.key,
                )
                    .animate(delay: Duration(milliseconds: entry.key * 100))
                    .fadeIn()
                    .slideX(begin: 0.1);
              }),

            const SizedBox(height: 32),

            // Streak info
            _StreakCard(stats: state.stats)
                .animate(delay: 300.ms)
                .fadeIn()
                .slideY(begin: 0.2),

            const SizedBox(height: 24),

            // Tips section
            _TipsSection().animate(delay: 400.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final UserStats stats;
  final int completedCount;
  final int totalCount;

  const _HeaderCard({
    required this.stats,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final allComplete = completedCount == totalCount && totalCount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allComplete
              ? [Colors.green, Colors.teal]
              : [scheme.primary, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (allComplete ? Colors.green : scheme.primary)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  allComplete ? Icons.celebration : Icons.flag,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allComplete ? 'All Complete!' : 'Keep Going!',
                      style: text.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      allComplete
                          ? 'You crushed today\'s challenges!'
                          : '$completedCount of $totalCount challenges done',
                      style: text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: totalCount > 0 ? completedCount / totalCount : 0,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          // XP info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeaderStat(
                icon: Icons.star,
                value: '${stats.totalXp}',
                label: 'Total XP',
              ),
              _HeaderStat(
                icon: Icons.trending_up,
                value: 'Lv ${stats.level}',
                label: 'Level',
              ),
              _HeaderStat(
                icon: Icons.local_fire_department,
                value: '${stats.currentStreak}',
                label: 'Streak',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
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

class _ChallengeCard extends StatelessWidget {
  final DailyChallenge challenge;
  final int index;

  const _ChallengeCard({
    required this.challenge,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isComplete = challenge.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: isComplete
              ? LinearGradient(
                  colors: [
                    Colors.green.withValues(alpha: 0.1),
                    Colors.green.withValues(alpha: 0.05),
                  ],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isComplete
                      ? Colors.green.withValues(alpha: 0.2)
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isComplete ? Icons.check_circle : _getIcon(),
                  color: isComplete ? Colors.green : scheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            challenge.title,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: isComplete
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isComplete ? scheme.outline : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isComplete
                                ? Colors.green.withValues(alpha: 0.2)
                                : scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 14,
                                color:
                                    isComplete ? Colors.green : scheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${challenge.xpReward} XP',
                                style: text.labelSmall?.copyWith(
                                  color: isComplete
                                      ? Colors.green
                                      : scheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.description,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: challenge.progress,
                              minHeight: 8,
                              backgroundColor:
                                  scheme.outline.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation(
                                isComplete ? Colors.green : scheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${challenge.currentValue}/${challenge.targetValue}',
                          style: text.labelMedium?.copyWith(
                            color: isComplete ? Colors.green : scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (challenge.type) {
      case ChallengeType.reviewFlashcards:
        return Icons.style;
      case ChallengeType.completeQuiz:
        return Icons.quiz;
      case ChallengeType.addSource:
        return Icons.add_circle;
      case ChallengeType.chatWithAI:
        return Icons.chat;
      case ChallengeType.tutorSession:
        return Icons.school;
      case ChallengeType.createMindmap:
        return Icons.account_tree;
      case ChallengeType.perfectQuiz:
        return Icons.star;
      case ChallengeType.studyTime:
        return Icons.timer;
      case ChallengeType.deepResearch:
        return Icons.search;
      case ChallengeType.voiceMode:
        return Icons.mic;
    }
  }
}

class _StreakCard extends StatelessWidget {
  final UserStats stats;

  const _StreakCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Your Streak',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StreakStat(
                    value: stats.currentStreak,
                    label: 'Current',
                    color: Colors.orange,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: scheme.outline.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _StreakStat(
                    value: stats.longestStreak,
                    label: 'Best',
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Complete at least one activity daily to maintain your streak!',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.8),
                      ),
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
}

class _StreakStat extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _StreakStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_fire_department, color: color, size: 24),
            const SizedBox(width: 4),
            Text(
              '$value',
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          '$label days',
          style: text.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _TipsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final tips = [
      'Review flashcards daily to boost memory retention',
      'Take quizzes to test your understanding',
      'Use the AI tutor for personalized learning',
      'Create mind maps to visualize connections',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              'Tips to Complete Challenges',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 64,
            color: scheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No challenges yet',
            style: text.titleMedium?.copyWith(
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back tomorrow for new challenges!',
            style: text.bodyMedium?.copyWith(
              color: scheme.outline.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
