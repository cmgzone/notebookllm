import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../components/premium_card.dart';
import 'agent_notebook_badge.dart';

class NotebookCard extends StatelessWidget {
  const NotebookCard({
    super.key,
    required this.title,
    required this.sourceCount,
    required this.notebookId,
    this.coverImage,
    this.onPlay,
    this.onCoverTap,
    this.isAgentNotebook = false,
    this.agentName,
    this.agentStatus = 'active',
  });

  final String title;
  final int sourceCount;
  final String notebookId;
  final String? coverImage;
  final VoidCallback? onPlay;
  final VoidCallback? onCoverTap;
  final bool isAgentNotebook;
  final String? agentName;
  final String agentStatus;

  Widget? _buildCoverImage() {
    if (coverImage == null || coverImage!.isEmpty) return null;

    try {
      if (coverImage!.startsWith('data:image/svg+xml')) {
        return null; // SVG data URIs not supported by default Image.memory
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
        return CachedNetworkImage(
          imageUrl: coverImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
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

    return PremiumCard(
      onTap: () => context.go('/notebook/$notebookId'),
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 250, // Enforce height
        child: Stack(
          children: [
            // Background (if no cover)
            if (!hasCover)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary.withValues(alpha: 0.1),
                        scheme.secondary.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ),

            // Cover Image
            if (hasCover) Positioned.fill(child: coverWidget),

            // Gradient Overlay for text readability on images
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

            // Content
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
                                color:
                                    hasCover ? Colors.white : scheme.onSurface,
                                shadows: hasCover
                                    ? const [
                                        Shadow(
                                            color: Colors.black54,
                                            blurRadius: 4)
                                      ]
                                    : null,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Play Button
                      Container(
                        decoration: BoxDecoration(
                          color: hasCover
                              ? Colors.white.withValues(alpha: 0.2)
                              : scheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          tooltip: 'Play Audio Overview',
                          onPressed: onPlay ?? () => _showAudioPreview(context),
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
                  // Footer Stats
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
                            Icon(Icons.source,
                                size: 16,
                                color:
                                    hasCover ? Colors.white : scheme.secondary),
                            const SizedBox(width: 6),
                            Text(
                              '$sourceCount',
                              style: TextStyle(
                                color:
                                    hasCover ? Colors.white : scheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // AI/Agent Badge
                      if (isAgentNotebook && agentName != null)
                        AgentNotebookBadge(
                          agentName: agentName!,
                          status: agentStatus,
                          compact: true,
                          onCoverImage: hasCover,
                        )
                      else
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
                              Icon(Icons.auto_awesome,
                                  size: 14,
                                  color: hasCover
                                      ? Colors.white
                                      : scheme.tertiary),
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
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioPreview(BuildContext context) {
    // (Kept existing visual logic but simplified)
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
