import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardGrid extends StatelessWidget {
  const DashboardGrid({super.key});

  @override
  Widget build(BuildContext context) {
    // Premium Bento Grid Layout
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explore AI Tools',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fadeIn().slideX(),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // simple responsive logic

                return Column(
                  children: [
                    // Top Row: 2 Big Cards
                    Row(
                      children: [
                        Expanded(
                          child: _BentoCard(
                            title: 'Wellness AI',
                            subtitle: 'Mental health & balance',
                            icon: LucideIcons.heartHandshake,
                            color: const Color(0xFFEC4899), // Pink
                            onTap: () => context.push('/wellness'),
                            height: 160,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BentoCard(
                            title: 'Ai Tutor',
                            subtitle: 'Master any subject',
                            icon: LucideIcons.graduationCap,
                            color: const Color(0xFF6366F1), // Indigo
                            onTap: () {
                              // Navigate to a generic tutor selection or first notebook
                              // For now, let's just go to language learning as a proxy or studio
                              context.push('/language-learning');
                            },
                            height: 160,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Middle Row: 3 Medium Cards
                    Row(
                      children: [
                        Expanded(
                          child: _BentoCard(
                            title: 'Code',
                            icon: LucideIcons.code,
                            color: const Color(0xFF22D3EE), // Cyan
                            onTap: () => context.push('/code-review'),
                            height: 120,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BentoCard(
                            title: 'Plan',
                            icon: LucideIcons.clipboardList,
                            color: const Color(0xFFF472B6), // Pink 400
                            onTap: () => context.push('/planning'),
                            height: 120,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BentoCard(
                            title: 'Social Hub',
                            icon: LucideIcons.users,
                            color: const Color(0xFF10B981), // Emerald
                            onTap: () => context.push('/social'),
                            height: 120,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BentoCard(
                            title: 'Stats',
                            icon: LucideIcons.trophy,
                            color: const Color(0xFFFBBF24), // Amber
                            onTap: () => context.push('/progress'),
                            height: 120,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Bottom Row: Wide Banner
                    _BentoCard(
                      title: 'Deep Research Agent',
                      subtitle: 'Analyze huge documents and web sources',
                      icon: LucideIcons.search,
                      color: const Color(0xFF8B5CF6), // Violet
                      onTap: () => context.push('/search'),
                      height: 100,
                      isWide: true,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double height;
  final bool compact;
  final bool isWide;

  const _BentoCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.height = 160,
    this.compact = false,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isDark
                ? scheme.surfaceContainer.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Decorative Gradient Blob
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: compact ? 80 : 120,
                    height: compact ? 80 : 120,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.3),
                          color.withValues(alpha: 0.0),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(compact ? 12 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Icon
                      Container(
                        padding: EdgeInsets.all(compact ? 8 : 12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(compact ? 12 : 16),
                        ),
                        child:
                            Icon(icon, color: color, size: compact ? 20 : 24),
                      ),

                      // Text - pushed to bottom by spaceBetween
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: compact ? 13 : 16,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null && !compact) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOut);
  }
}
