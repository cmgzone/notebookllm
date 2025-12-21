import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'flashcard.dart';
import 'flashcard_provider.dart';
import 'flashcard_generator_sheet.dart';

/// Screen showing all flashcard decks for a notebook
class FlashcardsListScreen extends ConsumerWidget {
  final String notebookId;

  const FlashcardsListScreen({super.key, required this.notebookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDecks = ref.watch(flashcardProvider);
    final decks = allDecks.where((d) => d.notebookId == notebookId).toList();

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcard Decks'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _showGeneratorSheet(context),
          ),
        ],
      ),
      body: decks.isEmpty
          ? _buildEmptyState(context, scheme, text)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: decks.length,
              itemBuilder: (context, index) {
                final deck = decks[index];
                return _buildDeckCard(context, ref, deck, scheme, text, index);
              },
            ),
      floatingActionButton: decks.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showGeneratorSheet(context),
              icon: const Icon(LucideIcons.sparkles),
              label: const Text('Generate'),
            ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, ColorScheme scheme, TextTheme text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.layers,
                size: 64,
                color: scheme.onPrimaryContainer,
              ),
            ).animate().scale(delay: 200.ms),
            const SizedBox(height: 24),
            Text(
              'No Flashcards Yet',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 12),
            Text(
              'Generate flashcards from your sources\nto start studying!',
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _showGeneratorSheet(context),
              icon: const Icon(LucideIcons.sparkles),
              label: const Text('Generate Flashcards'),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckCard(
    BuildContext context,
    WidgetRef ref,
    FlashcardDeck deck,
    ColorScheme scheme,
    TextTheme text,
    int index,
  ) {
    final masteryPercent = _calculateMastery(deck);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/flashcards/${deck.id}/study'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Mastery indicator
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: masteryPercent / 100,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        masteryPercent >= 80
                            ? Colors.green
                            : masteryPercent >= 50
                                ? Colors.orange
                                : scheme.primary,
                      ),
                      strokeWidth: 4,
                    ),
                  ),
                  Text(
                    '${masteryPercent.round()}%',
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Deck info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${deck.cards.length} cards',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _confirmDelete(context, ref, deck);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(LucideIcons.trash2, size: 18),
                        SizedBox(width: 12),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn().slideX(begin: 0.1);
  }

  double _calculateMastery(FlashcardDeck deck) {
    if (deck.cards.isEmpty) return 0;
    final totalReviews =
        deck.cards.fold<int>(0, (sum, c) => sum + c.timesReviewed);
    if (totalReviews == 0) return 0;
    final totalCorrect =
        deck.cards.fold<int>(0, (sum, c) => sum + c.timesCorrect);
    return (totalCorrect / totalReviews) * 100;
  }

  void _showGeneratorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FlashcardGeneratorSheet(notebookId: notebookId),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, FlashcardDeck deck) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deck?'),
        content: Text('Are you sure you want to delete "${deck.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(flashcardProvider.notifier).deleteDeck(deck.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
