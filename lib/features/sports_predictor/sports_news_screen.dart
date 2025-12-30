import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sports_news.dart';
import 'sports_news_provider.dart';

class SportsNewsScreen extends ConsumerStatefulWidget {
  const SportsNewsScreen({super.key});

  @override
  ConsumerState<SportsNewsScreen> createState() => _SportsNewsScreenState();
}

class _SportsNewsScreenState extends ConsumerState<SportsNewsScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Auto-fetch news on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(sportsNewsProvider).news.isEmpty) {
        ref.read(sportsNewsProvider.notifier).fetchNews();
      }
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sportsNewsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(
                      math.cos(_backgroundController.value * 2 * math.pi),
                      math.sin(_backgroundController.value * 2 * math.pi),
                    ),
                    end: Alignment(
                      -math.cos(_backgroundController.value * 2 * math.pi),
                      -math.sin(_backgroundController.value * 2 * math.pi),
                    ),
                    colors: [
                      scheme.primary.withValues(alpha: 0.1),
                      scheme.secondary.withValues(alpha: 0.05),
                      scheme.tertiary.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              );
            },
          ),

          // Main content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App bar with 3D effect
              SliverAppBar(
                expandedHeight: 140,
                floating: true,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          scheme.secondary,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Floating particles
                        ...List.generate(5, (i) => _FloatingParticle(index: i)),
                        // Title
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Row(
                                  children: [
                                    Text('📰', style: TextStyle(fontSize: 32)),
                                    SizedBox(width: 12),
                                    Text(
                                      'Sports News',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ).animate().fadeIn().slideX(),
                                const SizedBox(height: 4),
                                Text(
                                  'AI-Powered Live Updates',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ).animate().fadeIn(delay: 200.ms).slideX(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon:
                        const Icon(LucideIcons.refreshCw, color: Colors.white),
                    onPressed: state.isLoading
                        ? null
                        : () =>
                            ref.read(sportsNewsProvider.notifier).fetchNews(),
                  ),
                ],
              ),

              // Category chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: NewsCategory.values.length,
                    itemBuilder: (context, index) {
                      final category = NewsCategory.values[index];
                      final isSelected = category == state.selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _AnimatedCategoryChip(
                          category: category,
                          isSelected: isSelected,
                          onTap: () {
                            ref
                                .read(sportsNewsProvider.notifier)
                                .setCategory(category);
                            if (state.news.isEmpty) {
                              ref
                                  .read(sportsNewsProvider.notifier)
                                  .fetchNews(category: category);
                            }
                          },
                        ),
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: index * 50))
                          .slideX();
                    },
                  ),
                ),
              ),

              // Loading state
              if (state.isLoading)
                SliverToBoxAdapter(
                  child: _LoadingAnimation(
                    status: state.currentStatus ?? 'Loading...',
                    progress: state.progress,
                    pulseController: _pulseController,
                  ),
                ),

              // Error state
              if (state.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _ErrorCard(error: state.error!),
                  ),
                ),

              // News cards
              if (!state.isLoading && state.filteredNews.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final news = state.filteredNews[index];
                        final isExpanded = _expandedIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _Interactive3DNewsCard(
                            news: news,
                            index: index,
                            isExpanded: isExpanded,
                            onTap: () {
                              setState(() {
                                _expandedIndex = isExpanded ? null : index;
                              });
                            },
                          ),
                        );
                      },
                      childCount: state.filteredNews.length,
                    ),
                  ),
                ),

              // Empty state
              if (!state.isLoading && state.news.isEmpty && state.error == null)
                SliverFillRemaining(
                  child: _EmptyState(
                    onRefresh: () =>
                        ref.read(sportsNewsProvider.notifier).fetchNews(),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloatingParticle extends StatelessWidget {
  final int index;

  const _FloatingParticle({required this.index});

  @override
  Widget build(BuildContext context) {
    final random = math.Random(index);
    final size = 20.0 + random.nextDouble() * 40;
    final left = random.nextDouble() * 300;
    final top = random.nextDouble() * 100;

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .moveY(
            begin: 0,
            end: -20,
            duration: Duration(seconds: 2 + index),
            curve: Curves.easeInOut,
          )
          .then()
          .moveY(
            begin: -20,
            end: 0,
            duration: Duration(seconds: 2 + index),
            curve: Curves.easeInOut,
          ),
    );
  }
}

class _AnimatedCategoryChip extends StatefulWidget {
  final NewsCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedCategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AnimatedCategoryChip> createState() => _AnimatedCategoryChipState();
}

class _AnimatedCategoryChipState extends State<_AnimatedCategoryChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.diagonal3Values(
          _isHovered ? 1.05 : 1.0,
          _isHovered ? 1.05 : 1.0,
          1.0,
        )
          ..setEntry(3, 2, 0.001)
          ..rotateX(_isHovered ? -0.05 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: widget.isSelected
              ? LinearGradient(colors: [scheme.primary, scheme.secondary])
              : null,
          color: widget.isSelected ? null : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.category.emoji),
            const SizedBox(width: 6),
            Text(
              widget.category.displayName,
              style: TextStyle(
                color: widget.isSelected ? Colors.white : scheme.onSurface,
                fontWeight:
                    widget.isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingAnimation extends StatelessWidget {
  final String status;
  final double progress;
  final AnimationController pulseController;

  const _LoadingAnimation({
    required this.status,
    required this.progress,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Animated loading orb
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              return Container(
                width: 100 + pulseController.value * 20,
                height: 100 + pulseController.value * 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.primary,
                      scheme.primary.withValues(alpha: 0.3),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary
                          .withValues(alpha: 0.5 - pulseController.value * 0.3),
                      blurRadius: 30 + pulseController.value * 20,
                      spreadRadius: pulseController.value * 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('📰', style: TextStyle(fontSize: 40)),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            status,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _Interactive3DNewsCard extends StatefulWidget {
  final SportsNews news;
  final int index;
  final bool isExpanded;
  final VoidCallback onTap;

  const _Interactive3DNewsCard({
    required this.news,
    required this.index,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_Interactive3DNewsCard> createState() => _Interactive3DNewsCardState();
}

class _Interactive3DNewsCardState extends State<_Interactive3DNewsCard> {
  double _rotateX = 0;
  double _rotateY = 0;
  bool _isPressed = false;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _rotateY = (details.localPosition.dx - 150) / 150 * 0.1;
      _rotateX = -(details.localPosition.dy - 100) / 100 * 0.1;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _rotateX = 0;
      _rotateY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final importanceColor = switch (widget.news.importance) {
      NewsImportance.breaking => Colors.red,
      NewsImportance.high => Colors.orange,
      NewsImportance.normal => scheme.primary,
      NewsImportance.low => scheme.outline,
    };

    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.diagonal3Values(
          _isPressed ? 0.98 : 1.0,
          _isPressed ? 0.98 : 1.0,
          1.0,
        )
          ..setEntry(3, 2, 0.001)
          ..rotateX(_rotateX)
          ..rotateY(_rotateY),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface,
                scheme.surfaceContainerHighest.withValues(alpha: 0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: importanceColor.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: Offset(_rotateY * 50, _rotateX * -50 + 10),
              ),
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with importance indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        importanceColor.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Importance badge
                      if (widget.news.importance == NewsImportance.breaking)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'BREAKING',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(duration: 1.seconds),
                      if (widget.news.importance == NewsImportance.breaking)
                        const SizedBox(width: 8),
                      // Category
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.news.category,
                          style: text.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Time
                      Text(
                        _formatTime(widget.news.publishedAt),
                        style: text.labelSmall?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),

                // Featured Image (if available)
                if (widget.news.imageUrl != null &&
                    widget.news.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(0)),
                    child: Image.network(
                      widget.news.imageUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 180,
                          color: scheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    ),
                  ),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    widget.news.title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: widget.isExpanded ? null : 2,
                    overflow: widget.isExpanded ? null : TextOverflow.ellipsis,
                  ),
                ),

                // Summary
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.news.summary,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.8),
                    ),
                    maxLines: widget.isExpanded ? null : 2,
                    overflow: widget.isExpanded ? null : TextOverflow.ellipsis,
                  ),
                ),

                // Expanded content
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),

                        // Video embed (if available)
                        if (widget.news.videoUrl != null &&
                            widget.news.videoUrl!.isNotEmpty)
                          _VideoEmbed(
                            videoUrl: widget.news.videoUrl!,
                            thumbnail: widget.news.videoThumbnail,
                          ),

                        // Image gallery (if multiple images)
                        if (widget.news.images.isNotEmpty)
                          _ImageGallery(images: widget.news.images),

                        Text(
                          widget.news.content,
                          style: text.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        // Tags
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.news.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#$tag',
                                style: text.labelSmall?.copyWith(
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        // Source link
                        if (widget.news.sourceUrl.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _launchUrl(widget.news.sourceUrl),
                            icon:
                                const Icon(LucideIcons.externalLink, size: 16),
                            label: Text('Read on ${widget.news.source}'),
                          ),
                      ],
                    ),
                  ),
                  crossFadeState: widget.isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.newspaper,
                        size: 14,
                        color: scheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.news.source,
                        style: text.labelSmall?.copyWith(color: scheme.outline),
                      ),
                      const Spacer(),
                      Icon(
                        widget.isExpanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 20,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: widget.index * 100))
        .slideY(begin: 0.1);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;

  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertCircle, color: scheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    ).animate().shake();
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Text('📰', style: TextStyle(fontSize: 64)),
          ).animate().scaleXY(curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'No News Yet',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            'Tap refresh to get the latest sports news',
            style: text.bodyMedium?.copyWith(color: scheme.outline),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('Load News'),
          ).animate().fadeIn(delay: 600.ms).scaleXY(),
        ],
      ),
    );
  }
}

/// Video embed widget with play button overlay
class _VideoEmbed extends StatelessWidget {
  final String videoUrl;
  final String? thumbnail;

  const _VideoEmbed({
    required this.videoUrl,
    this.thumbnail,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Extract YouTube video ID if it's a YouTube URL
    String? youtubeId;
    if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
      final uri = Uri.tryParse(videoUrl);
      if (uri != null) {
        if (videoUrl.contains('youtu.be')) {
          youtubeId =
              uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        } else {
          youtubeId = uri.queryParameters['v'];
        }
      }
    }

    final thumbnailUrl = thumbnail ??
        (youtubeId != null
            ? 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg'
            : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => _launchVideo(videoUrl),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: thumbnailUrl != null
                  ? Image.network(
                      thumbnailUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(scheme),
                    )
                  : _buildPlaceholder(scheme),
            ),
            // Play button overlay
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.play,
                color: Colors.white,
                size: 32,
              ),
            ).animate().scale(delay: 200.ms),
            // Video label
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.video, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Watch Video',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme scheme) {
    return Container(
      height: 200,
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(LucideIcons.video, size: 48),
      ),
    );
  }

  Future<void> _launchVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Image gallery widget for multiple images
class _ImageGallery extends StatelessWidget {
  final List<String> images;

  const _ImageGallery({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📸 Gallery',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < images.length - 1 ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => _showFullImage(context, images[index]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        images[index],
                        width: 160,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 160,
                          height: 120,
                          color: scheme.surfaceContainerHighest,
                          child: const Icon(LucideIcons.imageOff),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 160,
                            height: 120,
                            color: scheme.surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: index * 100));
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
