import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../virtual_betting.dart';
import '../virtual_betting_provider.dart';
import '../prediction.dart';

class VirtualBettingScreen extends ConsumerStatefulWidget {
  final SportsPrediction? prediction;

  const VirtualBettingScreen({super.key, this.prediction});

  @override
  ConsumerState<VirtualBettingScreen> createState() =>
      _VirtualBettingScreenState();
}

class _VirtualBettingScreenState extends ConsumerState<VirtualBettingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(virtualBettingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🎰 '),
            Text('Virtual Betting'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Badge(
                label: Text('${state.betSlip.length}'),
                isLabelVisible: state.betSlip.isNotEmpty,
                child: const Icon(LucideIcons.receipt),
              ),
              text: 'Bet Slip',
            ),
            Tab(
              icon: Badge(
                label: Text('${state.activeBets.length}'),
                isLabelVisible: state.activeBets.isNotEmpty,
                child: const Icon(LucideIcons.clock),
              ),
              text: 'Active',
            ),
            const Tab(icon: Icon(LucideIcons.wallet), text: 'Wallet'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BetSlipTab(prediction: widget.prediction),
          const _ActiveBetsTab(),
          const _WalletTab(),
        ],
      ),
    );
  }
}

class _BetSlipTab extends ConsumerWidget {
  final SportsPrediction? prediction;

  const _BetSlipTab({this.prediction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(virtualBettingProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        // Quick add from prediction
        if (prediction != null)
          SliverToBoxAdapter(
            child: _QuickBetCard(prediction: prediction!),
          ),

        // Bet slip items
        if (state.betSlip.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.receipt, size: 64, color: scheme.outline),
                  const SizedBox(height: 16),
                  Text('Bet slip is empty',
                      style: text.titleMedium?.copyWith(color: scheme.outline)),
                  const SizedBox(height: 8),
                  Text('Add selections from predictions',
                      style: text.bodyMedium?.copyWith(color: scheme.outline)),
                ],
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = state.betSlip[index];
                  return _BetSlipItemCard(item: item, index: index);
                },
                childCount: state.betSlip.length,
              ),
            ),
          ),

          // Summary
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Stake:', style: text.bodyMedium),
                      Text(
                        '${state.totalStake.toStringAsFixed(2)} 🪙',
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Potential Win:', style: text.bodyMedium),
                      Text(
                        '${state.totalPotentialWin.toStringAsFixed(2)} 🪙',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  if (state.betSlip.length > 1) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Accumulator Odds:', style: text.bodySmall),
                        Text(
                          state.accumulatorOdds.toStringAsFixed(2),
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => ref
                              .read(virtualBettingProvider.notifier)
                              .clearBetSlip(),
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: state.totalStake <= state.wallet.balance
                              ? () => _placeBets(context, ref)
                              : null,
                          icon: const Icon(LucideIcons.check),
                          label: const Text('Place Bets'),
                        ),
                      ),
                    ],
                  ),
                  if (state.totalStake > state.wallet.balance)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Insufficient balance',
                        style: text.labelSmall?.copyWith(color: scheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Future<void> _placeBets(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(virtualBettingProvider.notifier).placeBets();
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Bets placed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class _QuickBetCard extends ConsumerWidget {
  final SportsPrediction prediction;

  const _QuickBetCard({required this.prediction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Bet', style: text.titleSmall),
            const SizedBox(height: 8),
            Text(
              '${prediction.homeTeam} vs ${prediction.awayTeam}',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(prediction.league, style: text.bodySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _OddsChip(
                  label: '1',
                  sublabel: prediction.homeTeam,
                  odds: prediction.odds.homeWin,
                  onTap: () => ref
                      .read(virtualBettingProvider.notifier)
                      .addToBetSlip(
                          prediction, 'home', prediction.odds.homeWin),
                ),
                _OddsChip(
                  label: 'X',
                  sublabel: 'Draw',
                  odds: prediction.odds.draw,
                  onTap: () => ref
                      .read(virtualBettingProvider.notifier)
                      .addToBetSlip(prediction, 'draw', prediction.odds.draw),
                ),
                _OddsChip(
                  label: '2',
                  sublabel: prediction.awayTeam,
                  odds: prediction.odds.awayWin,
                  onTap: () => ref
                      .read(virtualBettingProvider.notifier)
                      .addToBetSlip(
                          prediction, 'away', prediction.odds.awayWin),
                ),
                if (prediction.odds.over25 != null)
                  _OddsChip(
                    label: 'O2.5',
                    sublabel: 'Over',
                    odds: prediction.odds.over25!,
                    onTap: () => ref
                        .read(virtualBettingProvider.notifier)
                        .addToBetSlip(
                            prediction, 'over25', prediction.odds.over25!),
                  ),
                if (prediction.odds.btts != null)
                  _OddsChip(
                    label: 'BTTS',
                    sublabel: 'Yes',
                    odds: prediction.odds.btts!,
                    onTap: () => ref
                        .read(virtualBettingProvider.notifier)
                        .addToBetSlip(
                            prediction, 'btts', prediction.odds.btts!),
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }
}

class _OddsChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final double odds;
  final VoidCallback onTap;

  const _OddsChip({
    required this.label,
    required this.sublabel,
    required this.odds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(odds.toStringAsFixed(2),
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.bold)),
              Text(sublabel,
                  style: TextStyle(fontSize: 10, color: scheme.outline),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _BetSlipItemCard extends ConsumerWidget {
  final BetSlipItem item;
  final int index;

  const _BetSlipItemCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.matchTitle,
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(item.displayBetType, style: text.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.odds.toStringAsFixed(2),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => ref
                      .read(virtualBettingProvider.notifier)
                      .removeFromBetSlip(item.predictionId, item.betType),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Stake',
                      prefixText: '🪙 ',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    controller:
                        TextEditingController(text: item.stake.toString()),
                    onChanged: (value) {
                      final stake = double.tryParse(value) ?? 10;
                      ref
                          .read(virtualBettingProvider.notifier)
                          .updateStake(item.predictionId, item.betType, stake);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Potential Win', style: text.labelSmall),
                    Text(
                      '${item.potentialWin.toStringAsFixed(2)} 🪙',
                      style: text.titleSmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 50)).slideX();
  }
}

class _ActiveBetsTab extends ConsumerWidget {
  const _ActiveBetsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(virtualBettingProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (state.activeBets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.clock, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            Text('No active bets',
                style: text.titleMedium?.copyWith(color: scheme.outline)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.activeBets.length,
      itemBuilder: (context, index) {
        final bet = state.activeBets[index];
        return _ActiveBetCard(bet: bet, index: index);
      },
    );
  }
}

class _ActiveBetCard extends ConsumerWidget {
  final VirtualBet bet;
  final int index;

  const _ActiveBetCard({required this.bet, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                const Icon(LucideIcons.clock, size: 16),
                const SizedBox(width: 8),
                Text('Pending', style: text.labelMedium),
                const Spacer(),
                Text(
                  bet.odds.toStringAsFixed(2),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(bet.matchTitle,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(bet.betType.toUpperCase(), style: text.bodySmall),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stake', style: text.labelSmall),
                    Text('${bet.stake.toStringAsFixed(2)} 🪙',
                        style: text.bodyMedium),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Potential Win', style: text.labelSmall),
                    Text(
                      '${bet.potentialWin.toStringAsFixed(2)} 🪙',
                      style: text.bodyMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Demo buttons to settle bet
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(virtualBettingProvider.notifier)
                        .settleBet(bet.id, false),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Lost'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => ref
                        .read(virtualBettingProvider.notifier)
                        .settleBet(bet.id, true),
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Won'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 50));
  }
}

class _WalletTab extends ConsumerWidget {
  const _WalletTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(virtualBettingProvider);
    final wallet = state.wallet;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        // Balance card
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('💰 Virtual Balance',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text(
                  '${wallet.balance.toStringAsFixed(2)} 🪙',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatColumn(
                      label: 'Won',
                      value: '+${wallet.totalWon.toStringAsFixed(0)}',
                      color: Colors.green,
                    ),
                    _StatColumn(
                      label: 'Lost',
                      value: '-${wallet.totalLost.toStringAsFixed(0)}',
                      color: Colors.red,
                    ),
                    _StatColumn(
                      label: 'ROI',
                      value: '${wallet.roi.toStringAsFixed(1)}%',
                      color: wallet.roi >= 0 ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn().scale(),
        ),

        // Actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addBonus(context, ref),
                    icon: const Icon(LucideIcons.gift),
                    label: const Text('Claim Bonus'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _resetWallet(context, ref),
                    icon: const Icon(LucideIcons.refreshCw),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // History
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Bet History',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ),

        if (state.betHistory.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('No bet history yet',
                    style: text.bodyMedium?.copyWith(color: scheme.outline)),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final bet = state.betHistory[index];
                return _HistoryItem(bet: bet);
              },
              childCount: state.betHistory.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _addBonus(BuildContext context, WidgetRef ref) {
    ref
        .read(virtualBettingProvider.notifier)
        .addBonus(100, 'Daily bonus claimed');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎁 +100 coins bonus added!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetWallet(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Wallet?'),
        content: const Text(
            'This will reset your balance to 1000 coins and clear all history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(virtualBettingProvider.notifier).resetWallet();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final VirtualBet bet;

  const _HistoryItem({required this.bet});

  @override
  Widget build(BuildContext context) {
    final isWon = bet.status == BetStatus.won;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isWon ? Colors.green : Colors.red,
        child: Icon(
          isWon ? LucideIcons.check : LucideIcons.x,
          color: Colors.white,
        ),
      ),
      title: Text(bet.matchTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${bet.betType} @ ${bet.odds.toStringAsFixed(2)}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isWon
                ? '+${bet.payout?.toStringAsFixed(0)} 🪙'
                : '-${bet.stake.toStringAsFixed(0)} 🪙',
            style: TextStyle(
              color: isWon ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
