import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'chat_provider.dart';
import '../sources/source_detail_screen.dart';
import '../../ui/components/premium_card.dart';

class CitationDrawer extends ConsumerWidget {
  const CitationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatProvider);
    final citations = messages.expand((m) => m.citations).toList();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Drawer(
      width: 340,
      backgroundColor: Colors.transparent, // For glass effect
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.85),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.quote,
                            color: scheme.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text('Citations',
                          style: text.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.x),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (citations.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.bookOpen,
                              size: 64,
                              color: scheme.outline.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Citations will appear here when the AI grounds its answers in your sources.',
                              style: text.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: citations.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final c = citations[index];
                        return PremiumCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: scheme.primary,
                                    child: Text('${index + 1}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Source ${c.sourceId}',
                                      style: text.labelLarge
                                          ?.copyWith(color: scheme.primary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.externalLink,
                                        size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SourceDetailScreen(
                                              sourceId: c.sourceId),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: scheme.outline
                                          .withValues(alpha: 0.1)),
                                ),
                                child: Text(
                                  c.snippet,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyMedium?.copyWith(
                                      height: 1.5, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
