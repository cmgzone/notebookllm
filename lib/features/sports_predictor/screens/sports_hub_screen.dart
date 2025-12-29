import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SportsHubScreen extends ConsumerWidget {
  const SportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final features = [
      _FeatureItem(
        icon: LucideIcons.target,
        emoji: '🎯',
        title: 'Predictions',
        subtitle: 'AI-powered match predictions',
        route: '/sports-predictor',
        color: Colors.blue,
      ),
      _FeatureItem(
        icon: LucideIcons.radio,
        emoji: '📡',
        title: 'Live Scores',
        subtitle: 'Real-time match updates',
        route: '/sports-live',
        color: Colors.red,
      ),
      _FeatureItem(
        icon: LucideIcons.newspaper,
        emoji: '📰',
        title: 'Sports News',
        subtitle: 'AI-curated news feed',
        route: '/sports-news',
        color: Colors.orange,
      ),
      _FeatureItem(
        icon: LucideIcons.history,
        emoji: '📊',
        title: 'My History',
        subtitle: 'Track your predictions',
        route: '/sports-history',
        color: Colors.purple,
      ),
      _FeatureItem(
        icon: LucideIcons.wallet,
        emoji: '💰',
        title: 'Bankroll',
        subtitle: 'Virtual betting tracker',
        route: '/sports-bankroll',
        color: Colors.green,
      ),
      _FeatureItem(
        icon: LucideIcons.barChart3,
        emoji: '📈',
        title: 'Dashboard',
        subtitle: 'Performance analytics',
        route: '/sports-dashboard',
        color: Colors.teal,
      ),
      _FeatureItem(
        icon: LucideIcons.trophy,
        emoji: '🏆',
        title: 'Leaderboard',
        subtitle: 'Compete with others',
        route: '/sports-leaderboard',
        color: Colors.amber,
      ),
      _FeatureItem(
        icon: LucideIcons.users,
        emoji: '👥',
        title: 'Tipsters',
        subtitle: 'Follow expert picks',
        route: '/sports-tipsters',
        color: Colors.indigo,
      ),
      _FeatureItem(
        icon: LucideIcons.heart,
        emoji: '❤️',
        title: 'Favorites',
        subtitle: 'Your favorite teams',
        route: '/sports-favorites',
        color: Colors.pink,
      ),
      _FeatureItem(
        icon: LucideIcons.fileText,
        emoji: '📋',
        title: 'Betting Slip',
        subtitle: 'Build your bets',
        route: '/sports-slip',
        color: Colors.cyan,
      ),
      _FeatureItem(
        icon: LucideIcons.search,
        emoji: '🔍',
        title: 'Match Preview',
        subtitle: 'Detailed analysis',
        route: '/sports-preview',
        color: Colors.deepOrange,
      ),
      _FeatureItem(
        icon: LucideIcons.messageCircle,
        emoji: '💬',
        title: 'AI Chat',
        subtitle: 'Ask the AI agent',
        route: '/sports-predictor/chat',
        color: Colors.blueGrey,
      ),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.secondary],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Text('⚽', style: TextStyle(fontSize: 36)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sports Hub',
                                  style: text.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'AI-Powered Sports Analytics',
                                  style: text.bodySmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ).animate().fadeIn().slideX(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final feature = features[index];
                  return _FeatureCard(feature: feature, index: index);
                },
                childCount: features.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;
  final String route;
  final Color color;

  _FeatureItem({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.color,
  });
}

class _FeatureCard extends StatefulWidget {
  final _FeatureItem feature;
  final int index;

  const _FeatureCard({required this.feature, required this.index});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => Navigator.pushNamed(context, widget.feature.route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.diagonal3Values(
          _isPressed ? 0.95 : 1.0,
          _isPressed ? 0.95 : 1.0,
          1.0,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.feature.color.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.feature.color
                  .withValues(alpha: _isPressed ? 0.3 : 0.15),
              blurRadius: _isPressed ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.feature.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(widget.feature.emoji,
                    style: const TextStyle(fontSize: 24)),
              ),
              const Spacer(),
              Text(
                widget.feature.title,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                widget.feature.subtitle,
                style: text.bodySmall?.copyWith(color: scheme.outline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: widget.index * 50))
        .scale(begin: const Offset(0.8, 0.8));
  }
}
