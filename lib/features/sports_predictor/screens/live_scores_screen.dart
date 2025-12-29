import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/sports_models.dart';
import '../providers/live_sports_provider.dart';

class LiveScoresScreen extends ConsumerStatefulWidget {
  const LiveScoresScreen({super.key});

  @override
  ConsumerState<LiveScoresScreen> createState() => _LiveScoresScreenState();
}

class _LiveScoresScreenState extends ConsumerState<LiveScoresScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _sports = ['Football', 'Basketball', 'Tennis', 'Baseball', 'Hockey'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveScoresProvider.notifier).fetchLiveScores();
      ref.read(liveScoresProvider.notifier).startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveScoresProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('LIVE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
            const SizedBox(width: 8),
            const Text('Live Scores'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: state.isLoading
                ? null
                : () => ref.read(liveScoresProvider.notifier).fetchLiveScores(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Live'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Finished'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Sport filter
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _sports.length,
              itemBuilder: (context, index) {
                final sport = _sports[index];
                final isSelected = sport == state.selectedSport;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(sport),
                    selected: isSelected,
                    onSelected: (_) =>
                        ref.read(liveScoresProvider.notifier).setSport(sport),
                  ),
                );
              },
            ),
          ),

          // Content
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _MatchList(
                          matches: state.liveMatches,
                          emptyMessage: 'No live matches'),
                      _MatchList(
                          matches: state.upcomingMatches,
                          emptyMessage: 'No upcoming matches'),
                      _MatchList(
                          matches: state.finishedMatches,
                          emptyMessage: 'No finished matches'),
                    ],
                  ),
          ),

          // Last updated
          Container(
            padding: const EdgeInsets.all(8),
            color: scheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.clock, size: 14, color: scheme.outline),
                const SizedBox(width: 4),
                Text(
                  'Updated ${_formatTime(state.lastUpdated)}',
                  style: text.labelSmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _MatchList extends StatelessWidget {
  final List<LiveMatch> matches;
  final String emptyMessage;

  const _MatchList({required this.matches, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.calendar,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(emptyMessage, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _LiveMatchCard(match: matches[index]),
        ).animate().fadeIn(delay: Duration(milliseconds: index * 50));
      },
    );
  }
}

class _LiveMatchCard extends StatelessWidget {
  final LiveMatch match;

  const _LiveMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: scheme.surfaceContainerHighest,
            child: Row(
              children: [
                Text(match.league,
                    style: text.labelSmall?.copyWith(color: scheme.outline)),
                const Spacer(),
                if (match.isLive) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                        ).animate(onPlay: (c) => c.repeat()).fadeIn().fadeOut(),
                        const SizedBox(width: 4),
                        Text(match.minute ?? 'LIVE',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ] else
                  Text(_formatKickoff(match.kickoff), style: text.labelSmall),
              ],
            ),
          ),

          // Teams and score
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(match.homeTeam,
                          style: text.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 2),
                      const SizedBox(height: 4),
                      Text('HOME',
                          style:
                              text.labelSmall?.copyWith(color: scheme.outline)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: match.isLive
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    match.status == MatchStatus.scheduled
                        ? 'VS'
                        : match.scoreDisplay,
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: match.isLive ? scheme.onPrimaryContainer : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(match.awayTeam,
                          style: text.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 2),
                      const SizedBox(height: 4),
                      Text('AWAY',
                          style:
                              text.labelSmall?.copyWith(color: scheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Live odds
          if (match.currentOdds != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.2))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _OddsChip(
                      label: '1',
                      value: match.currentOdds!.homeWin,
                      change: match.currentOdds!.homeWinChange),
                  _OddsChip(
                      label: 'X',
                      value: match.currentOdds!.draw,
                      change: match.currentOdds!.drawChange),
                  _OddsChip(
                      label: '2',
                      value: match.currentOdds!.awayWin,
                      change: match.currentOdds!.awayWinChange),
                ],
              ),
            ),

          // Events
          if (match.events.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.2))),
              ),
              child: Column(
                children: match.events
                    .take(3)
                    .map((e) => _EventRow(event: e))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatKickoff(DateTime kickoff) {
    final now = DateTime.now();
    if (kickoff.day == now.day) {
      return '${kickoff.hour.toString().padLeft(2, '0')}:${kickoff.minute.toString().padLeft(2, '0')}';
    }
    return '${kickoff.day}/${kickoff.month} ${kickoff.hour}:${kickoff.minute.toString().padLeft(2, '0')}';
  }
}

class _OddsChip extends StatelessWidget {
  final String label;
  final double value;
  final double? change;

  const _OddsChip({required this.label, required this.value, this.change});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final changeColor =
        change == null ? null : (change! < 0 ? Colors.green : Colors.red);

    return Column(
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.outline)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value.toStringAsFixed(2),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (change != null) ...[
              const SizedBox(width: 4),
              Icon(
                  change! < 0
                      ? LucideIcons.trendingDown
                      : LucideIcons.trendingUp,
                  size: 12,
                  color: changeColor),
            ],
          ],
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final MatchEvent event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final icon = switch (event.type) {
      'goal' => '⚽',
      'card' => event.detail == 'red' ? '🟥' : '🟨',
      'substitution' => '🔄',
      _ => '📌',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(event.minute, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 8),
          Text(icon),
          const SizedBox(width: 8),
          Expanded(
              child: Text(event.player,
                  style: Theme.of(context).textTheme.bodySmall)),
          Text(event.team, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
