import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NotebookCard extends StatelessWidget {
  const NotebookCard({
    super.key,
    required this.title,
    required this.sourceCount,
    required this.notebookId,
    this.coverImage,
    this.onPlay,
    this.onCoverTap,
  });

  final String title;
  final int sourceCount;
  final String notebookId;
  final String? coverImage;
  final VoidCallback? onPlay;
  final VoidCallback? onCoverTap;

  Widget? _buildCoverImage() {
    if (coverImage == null || coverImage!.isEmpty) return null;

    try {
      if (coverImage!.startsWith('data:image/svg+xml')) {
        return null;
      } else if (coverImage!.startsWith('data:')) {
        final base64Data = coverImage!.split(',').last;
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } else if (coverImage!.startsWith('http')) {
        return Image.network(
          coverImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverWidget = _buildCoverImage();
    final hasCover = coverWidget != null;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/notebook/$notebookId'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: hasCover
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.1),
                      scheme.secondary.withValues(alpha: 0.05),
                    ],
                  ),
          ),
          child: Stack(
            children: [
              // Cover image background
              if (hasCover) Positioned.fill(child: coverWidget),

              // Overlay gradient for readability when cover exists
              if (hasCover)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),

              // Premium background pattern (only when no cover)
              if (!hasCover)
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ).animate().scale(duration: 1000.ms).fadeIn(),

              // Glassmorphism effect (only when no cover)
              if (!hasCover)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: hasCover
                                      ? Colors.white
                                      : scheme.onSurface,
                                  shadows: hasCover
                                      ? [
                                          Shadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.5),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: hasCover
                                ? Colors.white.withValues(alpha: 0.2)
                                : scheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            tooltip: 'Play Audio Overview',
                            onPressed:
                                onPlay ?? () => _showAudioPreview(context),
                            icon: Icon(
                              Icons.play_circle_fill,
                              color: hasCover ? Colors.white : scheme.primary,
                              size: 28,
                            ),
                          ),
                        ).animate().scale(duration: 500.ms).fadeIn(),
                      ],
                    ),
                    const Spacer(),

                    // Premium stats row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: hasCover
                                ? Colors.white.withValues(alpha: 0.2)
                                : scheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.source,
                                size: 16,
                                color:
                                    hasCover ? Colors.white : scheme.secondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$sourceCount',
                                style: TextStyle(
                                  color: hasCover
                                      ? Colors.white
                                      : scheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ).animate().slideX(begin: -0.2).fadeIn(),

                        const Spacer(),

                        // AI indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: hasCover
                                ? Colors.white.withValues(alpha: 0.2)
                                : scheme.tertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color:
                                    hasCover ? Colors.white : scheme.tertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AI',
                                style: TextStyle(
                                  color:
                                      hasCover ? Colors.white : scheme.tertiary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ).animate().slideX(begin: 0.2).fadeIn(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(duration: 600.ms).fadeIn();
  }

  void _showAudioPreview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Audio Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Generate an AI-powered audio summary of "$title"',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.go('/studio');
              },
              icon: const Icon(Icons.mic_none),
              label: const Text('Generate Audio'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
