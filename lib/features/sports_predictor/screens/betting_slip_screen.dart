import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../models/sports_models.dart';
import '../providers/live_sports_provider.dart';
import '../providers/sports_analytics_provider.dart';

class BettingSlipScreen extends ConsumerStatefulWidget {
  const BettingSlipScreen({super.key});

  @override
  ConsumerState<BettingSlipScreen> createState() => _BettingSlipScreenState();
}

class _BettingSlipScreenState extends ConsumerState<BettingSlipScreen> {
  final _stakeController = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _stakeController.addListener(() {
      final stake = double.tryParse(_stakeController.text) ?? 0;
      ref.read(bettingSlipProvider.notifier).setStake(stake);
    });
  }

  @override
  void dispose() {
    _stakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bettingSlipProvider);
    final bankroll = ref.watch(bankrollProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Betting Slip'),
        actions: [
          if (state.selections.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              onPressed: () =>
                  ref.read(bettingSlipProvider.notifier).clearSlip(),
            ),
        ],
      ),
      body: state.selections.isEmpty
          ? _EmptySlip()
          : Column(
              children: [
                // Selections list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.selections.length,
                    itemBuilder: (context, index) {
                      final selection = state.selections[index];
                      return _SelectionCard(
                        selection: selection,
                        onRemove: () => ref
                            .read(bettingSlipProvider.notifier)
                            .removeSelection(selection.matchId),
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: index * 50));
                    },
                  ),
                ),

                // Slip summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Slip type toggle
                        Row(
                          children: [
                            Expanded(
                              child: SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                      value: 'single', label: Text('Singles')),
                                  ButtonSegment(
                                      value: 'accumulator',
                                      label: Text('Acca')),
                                ],
                                selected: {state.slipType},
                                onSelectionChanged: (v) => ref
                                    .read(bettingSlipProvider.notifier)
                                    .setSlipType(v.first),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stake input
                        Row(
                          children: [
                            Text('Stake:', style: text.bodyMedium),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _stakeController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  prefixText: '\$',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...([5, 10, 25, 50]).map((amount) => Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: ActionChip(
                                    label: Text('\$$amount',
                                        style: const TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      _stakeController.text = amount.toString();
                                    },
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Summary
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                scheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Selections:', style: text.bodySmall),
                                  Text('${state.selectionCount}',
                                      style: text.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              if (state.slipType == 'accumulator') ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Odds:', style: text.bodySmall),
                                    Text(state.totalOdds.toStringAsFixed(2),
                                        style: text.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Potential Win:',
                                      style: text.titleSmall),
                                  Text(
                                    '\$${state.potentialWin.toStringAsFixed(2)}',
                                    style: text.titleMedium?.copyWith(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Place bet button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: state.stake > 0 &&
                                    state.stake <= bankroll.balance
                                ? () => _placeBet(context, ref, state)
                                : null,
                            icon: const Icon(LucideIcons.check),
                            label: Text(state.stake > bankroll.balance
                                ? 'Insufficient Balance'
                                : 'Place Bet (\$${state.stake.toStringAsFixed(2)})'),
                          ),
                        ),
                        if (bankroll.entries.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Balance: \$${bankroll.balance.toStringAsFixed(2)}',
                              style: text.labelSmall
                                  ?.copyWith(color: scheme.outline),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _placeBet(BuildContext context, WidgetRef ref, BettingSlipState state) {
    final slip = ref.read(bettingSlipProvider.notifier).buildSlip();

    // Deduct from bankroll
    ref.read(bankrollProvider.notifier).placeBet(
          state.stake,
          '${state.slipType == 'accumulator' ? 'Acca' : 'Single'}: ${state.selections.map((s) => s.selection).join(', ')}',
          slip.id,
        );

    // Add to prediction history
    for (final _ in state.selections) {
      // This would normally add each selection to history
    }

    // Clear slip
    ref.read(bettingSlipProvider.notifier).clearSlip();

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Bet placed! Potential win: \$${slip.potentialWin.toStringAsFixed(2)}'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _EmptySlip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.fileText, size: 64, color: scheme.outline),
          const SizedBox(height: 16),
          Text('Your slip is empty',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Add selections from predictions or live matches',
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
            label: const Text('View Predictions'),
          ),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final SlipSelection selection;
  final VoidCallback onRemove;

  const _SelectionCard({required this.selection, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dateFormat = DateFormat('MMM d, HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${selection.homeTeam} vs ${selection.awayTeam}',
                    style:
                        text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 18, color: scheme.error),
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              dateFormat.format(selection.matchDate),
              style: text.labelSmall?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(selection.betType, style: text.labelSmall),
                ),
                const SizedBox(width: 8),
                Text(selection.selection,
                    style:
                        text.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    selection.odds.toStringAsFixed(2),
                    style: text.titleSmall?.copyWith(
                        color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
