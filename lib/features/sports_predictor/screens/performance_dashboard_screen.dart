import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/sports_models.dart';
import '../providers/sports_analytics_provider.dart';

class PerformanceDashboardScreen extends ConsumerWidget {
  const PerformanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(predictionHistoryProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Performance Dashboard')),
      body: historyState.records.isEmpty
          ? _EmptyDashboard()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview cards
                  Row(
                    children: [
                      Expanded(
                          child: _StatCard(
                        title: 'Win Rate',
                        value: '${historyState.winRate.toStringAsFixed(1)}%',
                        icon: LucideIcons.percent,
                        color: Colors.blue,
                        subtitle:
                            '${historyState.wins}W - ${historyState.losses}L',
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                        title: 'ROI',
                        value:
                            '${historyState.roi >= 0 ? '+' : ''}${historyState.roi.toStringAsFixed(1)}%',
                        icon: LucideIcons.trendingUp,
                        color:
                            historyState.roi >= 0 ? Colors.green : Colors.red,
                        subtitle: 'Return on Investment',
                      )),
                    ],
                  ).animate().fadeIn().slideY(begin: -0.1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _StatCard(
                        title: 'Total Profit',
                        value:
                            '\$${historyState.totalProfit.toStringAsFixed(2)}',
                        icon: LucideIcons.dollarSign,
                        color: historyState.totalProfit >= 0
                            ? Colors.green
                            : Colors.red,
                        subtitle: 'From ${historyState.totalPredictions} bets',
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                        title: 'Avg Stake',
                        value:
                            '\$${(historyState.totalStaked / (historyState.totalPredictions > 0 ? historyState.totalPredictions : 1)).toStringAsFixed(2)}',
                        icon: LucideIcons.coins,
                        color: Colors.orange,
                        subtitle: 'Per prediction',
                      )),
                    ],
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1),

                  const SizedBox(height: 24),

                  // Performance by Sport
                  Text('Performance by Sport',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...historyState.bySport.entries.map((entry) {
                    final wins = entry.value
                        .where((r) => r.result == PredictionResult.won)
                        .length;
                    final total = entry.value
                        .where((r) => r.result != PredictionResult.pending)
                        .length;
                    final winRate = total > 0 ? (wins / total) * 100 : 0.0;
                    final profit =
                        entry.value.fold(0.0, (sum, r) => sum + r.profit);

                    return _PerformanceBar(
                      label: entry.key,
                      emoji: _getSportEmoji(entry.key),
                      winRate: winRate,
                      profit: profit,
                      total: entry.value.length,
                    );
                  }),

                  const SizedBox(height: 24),

                  // Performance by Bet Type
                  Text('Performance by Bet Type',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...historyState.byBetType.entries.map((entry) {
                    final wins = entry.value
                        .where((r) => r.result == PredictionResult.won)
                        .length;
                    final total = entry.value
                        .where((r) => r.result != PredictionResult.pending)
                        .length;
                    final winRate = total > 0 ? (wins / total) * 100 : 0.0;
                    final profit =
                        entry.value.fold(0.0, (sum, r) => sum + r.profit);

                    return _PerformanceBar(
                      label: entry.key,
                      emoji: _getBetTypeEmoji(entry.key),
                      winRate: winRate,
                      profit: profit,
                      total: entry.value.length,
                    );
                  }),

                  const SizedBox(height: 24),

                  // Performance by League
                  Text('Top Leagues',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...historyState.byLeague.entries.take(5).map((entry) {
                    final wins = entry.value
                        .where((r) => r.result == PredictionResult.won)
                        .length;
                    final total = entry.value
                        .where((r) => r.result != PredictionResult.pending)
                        .length;
                    final winRate = total > 0 ? (wins / total) * 100 : 0.0;
                    final profit =
                        entry.value.fold(0.0, (sum, r) => sum + r.profit);

                    return _PerformanceBar(
                      label: entry.key,
                      emoji: '🏆',
                      winRate: winRate,
                      profit: profit,
                      total: entry.value.length,
                    );
                  }),

                  const SizedBox(height: 24),

                  // Recent form
                  Text('Recent Form',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _RecentFormCard(
                      records: historyState.records.take(10).toList()),

                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  String _getSportEmoji(String sport) {
    return switch (sport.toLowerCase()) {
      'football' => '⚽',
      'basketball' => '🏀',
      'tennis' => '🎾',
      'baseball' => '⚾',
      'hockey' => '🏒',
      'american football' => '🏈',
      'golf' => '⛳',
      'boxing' => '🥊',
      'mma' => '🥋',
      'cricket' => '🏏',
      _ => '🎯',
    };
  }

  String _getBetTypeEmoji(String betType) {
    return switch (betType.toLowerCase()) {
      '1x2' => '🎯',
      'over/under' => '📊',
      'btts' => '⚽',
      'handicap' => '📈',
      'correct score' => '🔢',
      _ => '🎲',
    };
  }
}

class _EmptyDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.barChart3, size: 64, color: scheme.outline),
          const SizedBox(height: 16),
          Text('No Data Yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Start making predictions to see your performance analytics',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.outline),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/sports-predictor'),
            icon: const Icon(LucideIcons.target),
            label: const Text('Make Predictions'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: scheme.outline)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.outline)),
        ],
      ),
    );
  }
}

class _PerformanceBar extends StatelessWidget {
  final String label;
  final String emoji;
  final double winRate;
  final double profit;
  final int total;

  const _PerformanceBar({
    required this.label,
    required this.emoji,
    required this.winRate,
    required this.profit,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(label,
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500))),
              Text('$total bets',
                  style: text.labelSmall?.copyWith(color: scheme.outline)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: winRate / 100,
                    minHeight: 8,
                    backgroundColor: scheme.outline.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(
                        winRate >= 50 ? Colors.green : Colors.orange),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 50,
                child: Text('${winRate.toStringAsFixed(0)}%',
                    style: text.labelMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  '${profit >= 0 ? '+' : ''}\$${profit.toStringAsFixed(0)}',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: profit >= 0 ? Colors.green : Colors.red,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.1);
  }
}

class _RecentFormCard extends StatelessWidget {
  final List<PredictionRecord> records;

  const _RecentFormCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settledRecords = records
        .where((r) => r.result != PredictionResult.pending)
        .take(10)
        .toList();

    if (settledRecords.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('No settled predictions yet')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: settledRecords.map((r) {
              final isWin = r.result == PredictionResult.won;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isWin ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    isWin ? 'W' : 'L',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Last ${settledRecords.length} predictions',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
