import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../models/sports_models.dart';
import '../providers/sports_analytics_provider.dart';

class BankrollScreen extends ConsumerStatefulWidget {
  const BankrollScreen({super.key});

  @override
  ConsumerState<BankrollScreen> createState() => _BankrollScreenState();
}

class _BankrollScreenState extends ConsumerState<BankrollScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bankrollProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bankroll Tracker'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => _showDepositDialog(context, ref),
                child: const Row(
                  children: [
                    Icon(LucideIcons.plus),
                    SizedBox(width: 8),
                    Text('Deposit')
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => _showWithdrawDialog(context, ref),
                child: const Row(
                  children: [
                    Icon(LucideIcons.minus),
                    SizedBox(width: 8),
                    Text('Withdraw')
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => _showResetDialog(context, ref),
                child: Row(
                  children: [
                    Icon(LucideIcons.refreshCw, color: scheme.error),
                    const SizedBox(width: 8),
                    Text('Reset', style: TextStyle(color: scheme.error))
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: state.entries.isEmpty
          ? _SetupBankroll(
              onSetup: (amount) =>
                  ref.read(bankrollProvider.notifier).setInitialBalance(amount))
          : CustomScrollView(
              slivers: [
                // Balance card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: state.profit >= 0
                            ? [Colors.green.shade700, Colors.green.shade500]
                            : [Colors.red.shade700, Colors.red.shade500],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (state.profit >= 0 ? Colors.green : Colors.red)
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text('Current Balance',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8))),
                        const SizedBox(height: 8),
                        Text(
                          '\$${state.balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _BalanceStat(
                              label: 'Initial',
                              value:
                                  '\$${state.initialBalance.toStringAsFixed(0)}',
                            ),
                            Container(
                                width: 1, height: 30, color: Colors.white24),
                            _BalanceStat(
                              label: 'Profit/Loss',
                              value:
                                  '${state.profit >= 0 ? '+' : ''}\$${state.profit.toStringAsFixed(2)}',
                            ),
                            Container(
                                width: 1, height: 30, color: Colors.white24),
                            _BalanceStat(
                              label: 'ROI',
                              value:
                                  '${state.profitPercent >= 0 ? '+' : ''}${state.profitPercent.toStringAsFixed(1)}%',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
                ),

                // Quick actions
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: LucideIcons.plus,
                            label: 'Deposit',
                            color: Colors.green,
                            onTap: () => _showDepositDialog(context, ref),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            icon: LucideIcons.minus,
                            label: 'Withdraw',
                            color: Colors.orange,
                            onTap: () => _showWithdrawDialog(context, ref),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Transaction history
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Transaction History',
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ),

                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = state.entries[index];
                      return _TransactionTile(entry: entry)
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: index * 30));
                    },
                    childCount: state.entries.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  void _showDepositDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final descController = TextEditingController(text: 'Deposit');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Amount', prefixText: '\$'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                ref
                    .read(bankrollProvider.notifier)
                    .deposit(amount, descController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Deposit'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final descController = TextEditingController(text: 'Withdrawal');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Amount', prefixText: '\$'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                ref
                    .read(bankrollProvider.notifier)
                    .withdraw(amount, descController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Bankroll'),
        content: const Text(
            'This will clear all transaction history. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(bankrollProvider.notifier).resetBankroll();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _SetupBankroll extends StatefulWidget {
  final Function(double) onSetup;

  const _SetupBankroll({required this.onSetup});

  @override
  State<_SetupBankroll> createState() => _SetupBankrollState();
}

class _SetupBankrollState extends State<_SetupBankroll> {
  final _controller = TextEditingController(text: '1000');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Text('💰', style: TextStyle(fontSize: 64)),
            ).animate().scale(curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text('Set Your Bankroll',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Enter your starting virtual bankroll to track your betting performance',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '\$',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [100, 500, 1000, 5000].map((amount) {
                return ActionChip(
                  label: Text('\$$amount'),
                  onPressed: () => _controller.text = amount.toString(),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                final amount = double.tryParse(_controller.text);
                if (amount != null && amount > 0) {
                  widget.onSetup(amount);
                }
              },
              icon: const Icon(LucideIcons.check),
              label: const Text('Start Tracking'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;

  const _BalanceStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final BankrollEntry entry;

  const _TransactionTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dateFormat = DateFormat('MMM d, HH:mm');

    final isPositive = entry.amount > 0;
    final icon = switch (entry.type) {
      'deposit' => LucideIcons.arrowDownCircle,
      'withdrawal' => LucideIcons.arrowUpCircle,
      'bet' => LucideIcons.target,
      'win' => LucideIcons.trophy,
      _ => LucideIcons.circle,
    };
    final color = isPositive ? Colors.green : Colors.red;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(entry.description,
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(dateFormat.format(entry.timestamp),
          style: text.labelSmall?.copyWith(color: scheme.outline)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isPositive ? '+' : ''}\$${entry.amount.toStringAsFixed(2)}',
            style: text.titleSmall
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            'Bal: \$${entry.balanceAfter.toStringAsFixed(2)}',
            style: text.labelSmall?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
