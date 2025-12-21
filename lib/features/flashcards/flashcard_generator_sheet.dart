import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'flashcard_provider.dart';
import '../subscription/services/credit_manager.dart';

/// Bottom sheet for generating flashcards from sources
class FlashcardGeneratorSheet extends ConsumerStatefulWidget {
  final String notebookId;
  final String? sourceId;

  const FlashcardGeneratorSheet({
    super.key,
    required this.notebookId,
    this.sourceId,
  });

  @override
  ConsumerState<FlashcardGeneratorSheet> createState() =>
      _FlashcardGeneratorSheetState();
}

class _FlashcardGeneratorSheetState
    extends ConsumerState<FlashcardGeneratorSheet> {
  final _titleController = TextEditingController();
  int _cardCount = 10;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Flashcard Deck';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.layers,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Flashcards',
                        style: text.titleLarge,
                      ),
                      Text(
                        'AI will create Q&A cards from your sources',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed:
                      _isGenerating ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(),

          // Settings
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title input
                TextField(
                  controller: _titleController,
                  enabled: !_isGenerating,
                  decoration: InputDecoration(
                    labelText: 'Deck Title',
                    hintText: 'Enter a title for this deck',
                    prefixIcon: const Icon(LucideIcons.type),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Card count slider
                Text(
                  'Number of Cards: $_cardCount',
                  style: text.titleSmall,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _cardCount.toDouble(),
                  min: 5,
                  max: 20,
                  divisions: 15,
                  label: _cardCount.toString(),
                  onChanged: _isGenerating
                      ? null
                      : (value) {
                          setState(() => _cardCount = value.round());
                        },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '5',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      '20',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Generate button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : _generate,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.sparkles),
                label: Text(_isGenerating ? 'Generating...' : 'Generate Cards'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a deck title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check and consume credits
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.generateFlashcards,
      feature: 'generate_flashcards',
    );
    if (!hasCredits) return;

    setState(() => _isGenerating = true);

    try {
      await ref.read(flashcardProvider.notifier).generateFromSources(
            notebookId: widget.notebookId,
            title: _titleController.text.trim(),
            sourceId: widget.sourceId,
            cardCount: _cardCount,
          );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created $_cardCount flashcards!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
