import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../models/sports_models.dart';
import '../providers/sports_analytics_provider.dart';

class PredictionHistoryScreen extends ConsumerStatefulWidget {
  const PredictionHistoryScreen({super.key});

  @override
  ConsumerState<PredictionHistoryScreen> createState() =>
      _PredictionHistoryScreenState();
}

class _PredictionHistoryScreenState
    extends ConsumerState<PredictionHistoryScreen> {
  String _filter = 'all'; // all, pending, won, lost

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(predictionHistoryProvider);
    final scheme = Theme.of(context).colorScheme;

    final filteredRecords = _filter == 'all'
        ? state.records
        : state.records.where((r) => r.result.name == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prediction History'),
        actions: [
          if (state.records.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              onPressed: () => _showClearDialog(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          // Stats summary
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(colors: [scheme.primary, scheme.secondary]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                        label: 'Total',
                        value: state.totalPredictions.toString(),
                        color: Colors.white),
                    _StatItem(
                        label: 'Wins',
                        value: state.wins.toString(),
                        color: Colors.green.shade300),
                    _StatItem(
                        label: 'Losses',
                        value: state.losses.toString(),
                        color: Colors.red.shade300),
                    _StatItem(
                        label: 'Pending',
                        value: state.pending.toString(),
                        color: Colors.orange.shade300),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                        label: 'Win Rate',
                        value: '${state.winRate.toStringAsFixed(1)}%',
                        color: Colors.white),
                    _StatItem(
                      label: 'Profit',
                      value:
                          '${state.totalProfit >= 0 ? '+' : ''}${state.totalProfit.toStringAsFixed(2)}',
                      color: state.totalProfit >= 0
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                    ),
                    _StatItem(
                        label: 'ROI',
                        value: '${state.roi.toStringAsFixed(1)}%',
                        color: Colors.white),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.2),

          // Filter chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                    label: 'All',
                    value: 'all',
                    selected: _filter,
                    onSelected: (v) => setState(() => _filter = v)),
                _FilterChip(
                    label: 'Pending',
                    value: 'pending',
                    selected: _filter,
                    onSelected: (v) => setState(() => _filter = v)),
                _FilterChip(
                    label: 'Won',
                    value: 'won',
                    selected: _filter,
                    onSelected: (v) => setState(() => _filter = v)),
                _FilterChip(
                    label: 'Lost',
                    value: 'lost',
                    selected: _filter,
                    onSelected: (v) => setState(() => _filter = v)),
              ],
            ),
          ),

          // Records list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredRecords.isEmpty
                    ? _EmptyState(filter: _filter)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRecords.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PredictionRecordCard(
                              record: filteredRecords[index],
                              onUpdateResult: (result, score) {
                                ref
                                    .read(predictionHistoryProvider.notifier)
                                    .updateResult(filteredRecords[index].id,
                                        result, score);
                              },
                              onDelete: () {
                                ref
                                    .read(predictionHistoryProvider.notifier)
                                    .deletePrediction(
                                        filteredRecords[index].id);
                              },
                            ),
                          ).animate().fadeIn(
                              delay: Duration(milliseconds: index * 30));
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
            'Are you sure you want to clear all prediction history?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(predictionHistoryProvider.notifier).clearHistory();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onSelected;

  const _FilterChip(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected == value,
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.history,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            filter == 'all' ? 'No predictions yet' : 'No $filter predictions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Start making predictions to track your performance',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

class _PredictionRecordCard extends StatelessWidget {
  final PredictionRecord record;
  final Function(PredictionResult, String?) onUpdateResult;
  final VoidCallback onDelete;

  const _PredictionRecordCard({
    required this.record,
    required this.onUpdateResult,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dateFormat = DateFormat('MMM d, HH:mm');

    final resultColor = switch (record.result) {
      PredictionResult.won => Colors.green,
      PredictionResult.lost => Colors.red,
      PredictionResult.pending => Colors.orange,
      _ => scheme.outline,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            color: resultColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: resultColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    record.result.name.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(record.league, style: text.labelSmall),
                const Spacer(),
                Text(dateFormat.format(record.matchDate),
                    style: text.labelSmall?.copyWith(color: scheme.outline)),
              ],
            ),
          ),

          // Match info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${record.homeTeam} vs ${record.awayTeam}',
                          style: text.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(record.betType, style: text.labelSmall),
                          ),
                          const SizedBox(width: 8),
                          Text(record.selection,
                              style: text.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('@ ${record.odds.toStringAsFixed(2)}',
                              style: text.bodySmall
                                  ?.copyWith(color: scheme.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Stake: \$${record.stake.toStringAsFixed(2)}',
                        style: text.labelSmall),
                    if (record.result == PredictionResult.won)
                      Text('+\$${record.profit.toStringAsFixed(2)}',
                          style: text.titleSmall?.copyWith(
                              color: Colors.green, fontWeight: FontWeight.bold))
                    else if (record.result == PredictionResult.lost)
                      Text('-\$${record.stake.toStringAsFixed(2)}',
                          style: text.titleSmall?.copyWith(
                              color: Colors.red, fontWeight: FontWeight.bold))
                    else
                      Text(
                          'Potential: \$${record.potentialWin.toStringAsFixed(2)}',
                          style:
                              text.labelSmall?.copyWith(color: scheme.outline)),
                  ],
                ),
              ],
            ),
          ),

          // Actions for pending
          if (record.result == PredictionResult.pending)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showResultDialog(context),
                      icon: const Icon(LucideIcons.checkCircle, size: 16),
                      label: const Text('Update Result'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon:
                        Icon(LucideIcons.trash2, color: scheme.error, size: 20),
                  ),
                ],
              ),
            ),

          // Score for finished
          if (record.actualScore != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.2))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Final Score: ', style: text.labelSmall),
                  Text(record.actualScore!,
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showResultDialog(BuildContext context) {
    final scoreController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreController,
              decoration: const InputDecoration(
                labelText: 'Final Score (e.g., 2-1)',
                hintText: '2-1',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      onUpdateResult(
                          PredictionResult.won, scoreController.text);
                      Navigator.pop(context);
                    },
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.green),
                    child: const Text('Won'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      onUpdateResult(
                          PredictionResult.lost, scoreController.text);
                      Navigator.pop(context);
                    },
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Lost'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
        ],
      ),
    );
  }
}
