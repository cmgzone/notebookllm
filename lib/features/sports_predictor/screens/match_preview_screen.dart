import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/sports_models.dart';
import '../providers/match_analysis_provider.dart';

class MatchPreviewScreen extends ConsumerStatefulWidget {
  const MatchPreviewScreen({super.key});

  @override
  ConsumerState<MatchPreviewScreen> createState() => _MatchPreviewScreenState();
}

class _MatchPreviewScreenState extends ConsumerState<MatchPreviewScreen> {
  final _homeController = TextEditingController();
  final _awayController = TextEditingController();
  final _leagueController = TextEditingController();

  @override
  void dispose() {
    _homeController.dispose();
    _awayController.dispose();
    _leagueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewState = ref.watch(matchPreviewProvider);
    final h2hState = ref.watch(h2hProvider);
    final formState = ref.watch(teamFormProvider);
    final injuryState = ref.watch(injuryReportProvider);
    final weatherState = ref.watch(weatherProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Match Preview')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _homeController,
                      decoration: const InputDecoration(
                        labelText: 'Home Team',
                        hintText: 'e.g., Manchester United',
                        prefixIcon: Icon(LucideIcons.home),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _awayController,
                      decoration: const InputDecoration(
                        labelText: 'Away Team',
                        hintText: 'e.g., Liverpool',
                        prefixIcon: Icon(LucideIcons.plane),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _leagueController,
                      decoration: const InputDecoration(
                        labelText: 'League (optional)',
                        hintText: 'e.g., Premier League',
                        prefixIcon: Icon(LucideIcons.trophy),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            previewState.isLoading ? null : _generatePreview,
                        icon: previewState.isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: scheme.onPrimary),
                              )
                            : const Icon(LucideIcons.search),
                        label: Text(previewState.isLoading
                            ? 'Analyzing...'
                            : 'Generate Preview'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Loading state
            if (previewState.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    LinearProgressIndicator(value: previewState.progress),
                    const SizedBox(height: 8),
                    Text(previewState.currentStatus,
                        style: text.bodySmall?.copyWith(color: scheme.outline)),
                  ],
                ),
              ),

            // Preview content
            if (previewState.preview != null) ...[
              const SizedBox(height: 24),

              // Match header
              _MatchHeader(preview: previewState.preview!),

              const SizedBox(height: 16),

              // Prediction
              _PredictionCard(preview: previewState.preview!),

              const SizedBox(height: 16),

              // Analysis
              _AnalysisCard(preview: previewState.preview!),

              const SizedBox(height: 16),

              // Key stats
              _KeyStatsCard(stats: previewState.preview!.keyStats),

              const SizedBox(height: 16),

              // Betting tips
              _BettingTipsCard(tips: previewState.preview!.bettingTips),

              // H2H
              if (h2hState.data != null) ...[
                const SizedBox(height: 16),
                _H2HCard(h2h: h2hState.data!),
              ],

              // Team forms
              if (formState.homeForm != null && formState.awayForm != null) ...[
                const SizedBox(height: 16),
                _TeamFormsCard(
                    homeForm: formState.homeForm!,
                    awayForm: formState.awayForm!),
              ],

              // Injuries
              if (injuryState.homeInjuries != null ||
                  injuryState.awayInjuries != null) ...[
                const SizedBox(height: 16),
                _InjuriesCard(
                  homeInjuries: injuryState.homeInjuries,
                  awayInjuries: injuryState.awayInjuries,
                ),
              ],

              // Weather
              if (weatherState.weather != null) ...[
                const SizedBox(height: 16),
                _WeatherCard(weather: weatherState.weather!),
              ],
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _generatePreview() {
    final home = _homeController.text.trim();
    final away = _awayController.text.trim();
    final league = _leagueController.text.trim();

    if (home.isEmpty || away.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both team names')),
      );
      return;
    }

    ref.read(matchPreviewProvider.notifier).generatePreview(
          home,
          away,
          league.isNotEmpty ? league : 'League',
          DateTime.now().add(const Duration(days: 1)),
        );

    // Also fetch supporting data
    ref.read(h2hProvider.notifier).fetchH2H(home, away);
    ref.read(teamFormProvider.notifier).fetchTeamForms(home, away);
    ref.read(injuryReportProvider.notifier).fetchInjuries(home, away);
    ref.read(weatherProvider.notifier).fetchWeather('Stadium', DateTime.now());
  }
}

class _MatchHeader extends StatelessWidget {
  final MatchPreview preview;

  const _MatchHeader({required this.preview});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(preview.league,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  preview.homeTeam,
                  style: text.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('VS',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text(
                  preview.awayTeam,
                  style: text.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }
}

class _PredictionCard extends StatelessWidget {
  final MatchPreview preview;

  const _PredictionCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.target, color: Colors.green),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Prediction',
                      style: text.labelMedium?.copyWith(color: scheme.outline)),
                  Text(preview.prediction,
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(preview.confidence * 100).round()}%',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }
}

class _AnalysisCard extends StatelessWidget {
  final MatchPreview preview;

  const _AnalysisCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.fileText, size: 20),
                const SizedBox(width: 8),
                Text('Analysis',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(preview.analysis,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
}

class _KeyStatsCard extends StatelessWidget {
  final List<String> stats;

  const _KeyStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.barChart3, size: 20),
                const SizedBox(width: 8),
                Text('Key Statistics',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...stats.map((stat) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(LucideIcons.checkCircle,
                          size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(stat)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

class _BettingTipsCard extends StatelessWidget {
  final List<String> tips;

  const _BettingTipsCard({required this.tips});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.lightbulb,
                    size: 20, color: Colors.amber),
                const SizedBox(width: 8),
                Text('Betting Tips',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tips
                  .map((tip) => Chip(
                        label: Text(tip),
                        backgroundColor: Colors.amber.withValues(alpha: 0.2),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }
}

class _H2HCard extends StatelessWidget {
  final HeadToHead h2h;

  const _H2HCard({required this.h2h});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.swords, size: 20),
                const SizedBox(width: 8),
                Text('Head to Head',
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _H2HStat(
                    label: h2h.team1,
                    value: h2h.team1Wins.toString(),
                    color: Colors.blue),
                _H2HStat(
                    label: 'Draws',
                    value: h2h.draws.toString(),
                    color: Colors.grey),
                _H2HStat(
                    label: h2h.team2,
                    value: h2h.team2Wins.toString(),
                    color: Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            Text('Last ${h2h.recentMatches.length} meetings',
                style: text.labelSmall),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms);
  }
}

class _H2HStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _H2HStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _TeamFormsCard extends StatelessWidget {
  final TeamForm homeForm;
  final TeamForm awayForm;

  const _TeamFormsCard({required this.homeForm, required this.awayForm});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.activity, size: 20),
                const SizedBox(width: 8),
                Text('Recent Form',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _FormRow(form: homeForm, isHome: true),
            const SizedBox(height: 12),
            _FormRow(form: awayForm, isHome: false),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 600.ms);
  }
}

class _FormRow extends StatelessWidget {
  final TeamForm form;
  final bool isHome;

  const _FormRow({required this.form, required this.isHome});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(form.teamName,
              style: text.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        ...form.lastMatches.take(5).map((m) => Container(
              margin: const EdgeInsets.only(right: 4),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: m.resultColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(m.result,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            )),
        const Spacer(),
        Text('${form.formPoints} pts',
            style: text.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _InjuriesCard extends StatelessWidget {
  final InjuryReport? homeInjuries;
  final InjuryReport? awayInjuries;

  const _InjuriesCard({this.homeInjuries, this.awayInjuries});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Injury Report',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (homeInjuries != null) ...[
              Text(homeInjuries!.teamName,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              ...homeInjuries!.injuries
                  .take(3)
                  .map((i) => _InjuryRow(injury: i)),
              const SizedBox(height: 8),
            ],
            if (awayInjuries != null) ...[
              Text(awayInjuries!.teamName,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              ...awayInjuries!.injuries
                  .take(3)
                  .map((i) => _InjuryRow(injury: i)),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: 700.ms);
  }
}

class _InjuryRow extends StatelessWidget {
  final PlayerInjury injury;

  const _InjuryRow({required this.injury});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: injury.statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(injury.playerName,
                  style: Theme.of(context).textTheme.bodySmall)),
          Text(injury.injuryType,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final MatchWeather weather;

  const _WeatherCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(weather.icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(weather.condition,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '${weather.temperature.round()}°C • Wind: ${weather.windSpeed.round()} km/h • Humidity: ${weather.humidity}%',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: weather.impact == 'favorable'
                    ? Colors.green.withValues(alpha: 0.2)
                    : weather.impact == 'unfavorable'
                        ? Colors.red.withValues(alpha: 0.2)
                        : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(weather.impact.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 800.ms);
  }
}
