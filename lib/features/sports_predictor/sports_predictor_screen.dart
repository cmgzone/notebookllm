import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'prediction.dart';
import 'sports_predictor_provider.dart';
import 'predictor_chat_screen.dart';
import 'virtual_betting_provider.dart';
import 'screens/virtual_betting_screen.dart';

class SportsPredictorScreen extends ConsumerStatefulWidget {
  const SportsPredictorScreen({super.key});

  @override
  ConsumerState<SportsPredictorScreen> createState() =>
      _SportsPredictorScreenState();
}

class _SportsPredictorScreenState extends ConsumerState<SportsPredictorScreen> {
  SportType _selectedSport = SportType.football;
  final _leagueController = TextEditingController();
  final _matchController = TextEditingController();

  @override
  void dispose() {
    _leagueController.dispose();
    _matchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sportsPredictorProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🎯 '),
            Text('Sports Predictor'),
          ],
        ),
        actions: [
          // Virtual Betting button
          IconButton(
            icon: Badge(
              label: Consumer(
                builder: (context, ref, _) {
                  final betSlip = ref.watch(virtualBettingProvider).betSlip;
                  return Text('${betSlip.length}');
                },
              ),
              isLabelVisible: true,
              child: const Icon(LucideIcons.wallet),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VirtualBettingScreen()),
            ),
            tooltip: 'Virtual Betting',
          ),
          // Chat with AI Agent button
          IconButton(
            icon: const Icon(LucideIcons.messageCircle),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PredictorChatScreen(
                  initialPredictions:
                      state.predictions.isNotEmpty ? state.predictions : null,
                ),
              ),
            ),
            tooltip: 'Chat with AI Agent',
          ),
          // Sports News button
          IconButton(
            icon: const Icon(LucideIcons.newspaper),
            onPressed: () => Navigator.pushNamed(context, '/sports-news'),
            tooltip: 'Sports News',
          ),
          if (state.predictions.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              onPressed: () =>
                  ref.read(sportsPredictorProvider.notifier).clearPredictions(),
              tooltip: 'Clear predictions',
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Sport Selection
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Sport',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: SportType.values.length,
                      itemBuilder: (context, index) {
                        final sport = SportType.values[index];
                        final isSelected = sport == _selectedSport;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedSport = sport),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 80,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: scheme.outline
                                            .withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(sport.emoji,
                                      style: const TextStyle(fontSize: 28)),
                                  const SizedBox(height: 4),
                                  Text(
                                    sport.displayName,
                                    style: text.labelSmall?.copyWith(
                                      color: isSelected
                                          ? scheme.onPrimary
                                          : scheme.onSurface,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // League input
                  TextField(
                    controller: _leagueController,
                    decoration: InputDecoration(
                      labelText: 'League (optional)',
                      hintText: 'e.g., Premier League, NBA, NFL',
                      prefixIcon: const Icon(LucideIcons.trophy),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Specific match input
                  TextField(
                    controller: _matchController,
                    decoration: InputDecoration(
                      labelText: 'Specific Match (optional)',
                      hintText: 'e.g., Manchester United vs Liverpool',
                      prefixIcon: const Icon(LucideIcons.swords),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Generate button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: state.isLoading ? null : _generatePredictions,
                      icon: state.isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : const Icon(LucideIcons.sparkles),
                      label: Text(state.isLoading
                          ? 'Analyzing...'
                          : 'Generate Predictions'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading status
          if (state.isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _LoadingCard(
                  status: state.currentStatus ?? 'Processing...',
                  progress: state.progress,
                  sources: state.researchSources,
                ),
              ),
            ),

          // Error
          if (state.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: scheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(LucideIcons.alertCircle, color: scheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Predictions list
          if (state.predictions.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Predictions (${state.predictions.length})',
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final prediction = state.predictions[index];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _PredictionCard(prediction: prediction),
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: index * 100));
                },
                childCount: state.predictions.length,
              ),
            ),
          ],

          // Empty state
          if (!state.isLoading &&
              state.predictions.isEmpty &&
              state.error == null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.target, size: 64, color: scheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'No predictions yet',
                      style: text.titleMedium?.copyWith(color: scheme.outline),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a sport and generate predictions',
                      style: text.bodyMedium?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PredictorChatScreen(
              initialPredictions:
                  state.predictions.isNotEmpty ? state.predictions : null,
            ),
          ),
        ),
        icon: const Icon(LucideIcons.messageCircle),
        label: const Text('Chat with AI'),
        backgroundColor: scheme.primary,
      ).animate().scale(delay: 300.ms),
    );
  }

  void _generatePredictions() {
    ref.read(sportsPredictorProvider.notifier).generatePredictions(
          sport: _selectedSport,
          league:
              _leagueController.text.isNotEmpty ? _leagueController.text : null,
          specificMatch:
              _matchController.text.isNotEmpty ? _matchController.text : null,
        );
  }
}

class _LoadingCard extends StatelessWidget {
  final String status;
  final double progress;
  final List<String> sources;

  const _LoadingCard({
    required this.status,
    required this.progress,
    required this.sources,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress > 0 ? progress : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(status, style: text.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              borderRadius: BorderRadius.circular(4),
            ),
            if (sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Sources found: ${sources.length}',
                style: text.labelSmall?.copyWith(color: scheme.outline),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn();
  }
}

class _PredictionCard extends ConsumerWidget {
  final SportsPrediction prediction;

  const _PredictionCard({required this.prediction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dateFormat = DateFormat('MMM d, yyyy • HH:mm');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
              ),
            ),
            child: Row(
              children: [
                Text(
                  prediction.sport == 'Football' ? '⚽' : '🏆',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prediction.league,
                        style: text.labelSmall?.copyWith(color: Colors.white70),
                      ),
                      Text(
                        dateFormat.format(prediction.matchDate),
                        style: text.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                _ConfidenceBadge(confidence: prediction.confidence),
              ],
            ),
          ),

          // Teams
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _TeamLogo(
                        logoUrl: prediction.homeTeamLogo,
                        teamName: prediction.homeTeam,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        prediction.homeTeam,
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('HOME',
                          style:
                              text.labelSmall?.copyWith(color: scheme.outline)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('VS',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _TeamLogo(
                        logoUrl: prediction.awayTeamLogo,
                        teamName: prediction.awayTeam,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        prediction.awayTeam,
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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

          // Clickable Odds table for betting
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _BettableOddsTable(
              prediction: prediction,
              onBetSelected: (betType, odds) {
                ref
                    .read(virtualBettingProvider.notifier)
                    .addToBetSlip(prediction, betType, odds);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added to bet slip @ $odds'),
                    action: SnackBarAction(
                      label: 'View Slip',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              VirtualBettingScreen(prediction: prediction),
                        ),
                      ),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),

          // Analysis
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Analysis',
                    style:
                        text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(prediction.analysis, style: text.bodySmall),
                if (prediction.keyFactors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Key Factors',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: prediction.keyFactors.map((factor) {
                      return Chip(
                        label: Text(factor, style: text.labelSmall),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: scheme.surfaceContainerHighest,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Place Bet button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        VirtualBettingScreen(prediction: prediction),
                  ),
                ),
                icon: const Icon(LucideIcons.wallet, size: 18),
                label: const Text('Place Virtual Bet'),
              ),
            ),
          ),

          // Sources
          if (prediction.sources.isNotEmpty)
            ExpansionTile(
              title: Text('Sources (${prediction.sources.length})',
                  style: text.labelMedium),
              children: prediction.sources.take(5).map((source) {
                return ListTile(
                  dense: true,
                  title: Text(source.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(source.snippet,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  leading: const Icon(LucideIcons.link, size: 16),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _BettableOddsTable extends StatelessWidget {
  final SportsPrediction prediction;
  final Function(String betType, double odds) onBetSelected;

  const _BettableOddsTable({
    required this.prediction,
    required this.onBetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final odds = prediction.odds;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Main odds row - clickable
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _ClickableOddsCell(
                  label: '1',
                  value: odds.homeWin,
                  isHighlighted:
                      odds.homeWin < odds.draw && odds.homeWin < odds.awayWin,
                  onTap: () => onBetSelected('home', odds.homeWin),
                ),
                _ClickableOddsCell(
                  label: 'X',
                  value: odds.draw,
                  isHighlighted:
                      odds.draw < odds.homeWin && odds.draw < odds.awayWin,
                  onTap: () => onBetSelected('draw', odds.draw),
                ),
                _ClickableOddsCell(
                  label: '2',
                  value: odds.awayWin,
                  isHighlighted:
                      odds.awayWin < odds.homeWin && odds.awayWin < odds.draw,
                  onTap: () => onBetSelected('away', odds.awayWin),
                ),
              ],
            ),
          ),

          // Additional odds - clickable
          if (odds.over25 != null || odds.btts != null)
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
                  if (odds.over25 != null)
                    _ClickableSmallOddsChip(
                      label: 'Over 2.5',
                      value: odds.over25!,
                      onTap: () => onBetSelected('over25', odds.over25!),
                    ),
                  if (odds.under25 != null)
                    _ClickableSmallOddsChip(
                      label: 'Under 2.5',
                      value: odds.under25!,
                      onTap: () => onBetSelected('under25', odds.under25!),
                    ),
                  if (odds.btts != null)
                    _ClickableSmallOddsChip(
                      label: 'BTTS',
                      value: odds.btts!,
                      onTap: () => onBetSelected('btts', odds.btts!),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ClickableOddsCell extends StatelessWidget {
  final String label;
  final double value;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _ClickableOddsCell({
    required this.label,
    required this.value,
    this.isHighlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: isHighlighted ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: isHighlighted
                    ? null
                    : Border.all(color: scheme.outline.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    label,
                    style: text.labelSmall?.copyWith(
                      color: isHighlighted ? scheme.onPrimary : scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.toStringAsFixed(2),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          isHighlighted ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    LucideIcons.plus,
                    size: 12,
                    color: isHighlighted
                        ? scheme.onPrimary.withValues(alpha: 0.7)
                        : scheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClickableSmallOddsChip extends StatelessWidget {
  final String label;
  final double value;
  final VoidCallback onTap;

  const _ClickableSmallOddsChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Text(label, style: text.labelSmall),
              Text(value.toStringAsFixed(2),
                  style:
                      text.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              Icon(LucideIcons.plus, size: 10, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final percent = (confidence * 100).round();
    final color = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.5
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        '$percent%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  final String? logoUrl;
  final String teamName;

  const _TeamLogo({
    required this.logoUrl,
    required this.teamName,
  });

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? Image.network(
                logoUrl!,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallback(scheme);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: _size * 0.4,
                      height: _size * 0.4,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              )
            : _buildFallback(scheme),
      ),
    );
  }

  Widget _buildFallback(ColorScheme scheme) {
    final initials = _getInitials(teamName);
    return Container(
      color: scheme.primaryContainer,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: _size * 0.35,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '??';
    if (words.length == 1) {
      return words[0].substring(0, words[0].length.clamp(0, 2)).toUpperCase();
    }
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}
