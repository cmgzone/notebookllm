import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'quiz_provider.dart';
import '../subscription/services/credit_manager.dart';

/// Bottom sheet for generating quizzes from sources
class QuizGeneratorSheet extends ConsumerStatefulWidget {
  final String notebookId;
  final String? sourceId;

  const QuizGeneratorSheet({
    super.key,
    required this.notebookId,
    this.sourceId,
  });

  @override
  ConsumerState<QuizGeneratorSheet> createState() => _QuizGeneratorSheetState();
}

class _QuizGeneratorSheetState extends ConsumerState<QuizGeneratorSheet> {
  final _titleController = TextEditingController();
  int _questionCount = 10;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Knowledge Quiz';
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
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.clipboardCheck,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Quiz',
                        style: text.titleLarge,
                      ),
                      Text(
                        'AI will create multiple-choice questions',
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
                    labelText: 'Quiz Title',
                    hintText: 'Enter a title for this quiz',
                    prefixIcon: const Icon(LucideIcons.type),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Question count slider
                Text(
                  'Number of Questions: $_questionCount',
                  style: text.titleSmall,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _questionCount.toDouble(),
                  min: 5,
                  max: 20,
                  divisions: 15,
                  label: _questionCount.toString(),
                  onChanged: _isGenerating
                      ? null
                      : (value) {
                          setState(() => _questionCount = value.round());
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
                label: Text(_isGenerating ? 'Generating...' : 'Generate Quiz'),
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
          content: Text('Please enter a quiz title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check and consume credits
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.generateQuiz,
      feature: 'generate_quiz',
    );
    if (!hasCredits) return;

    setState(() => _isGenerating = true);

    try {
      final quiz = await ref.read(quizProvider.notifier).generateFromSources(
            notebookId: widget.notebookId,
            title: _titleController.text.trim(),
            sourceId: widget.sourceId,
            questionCount: _questionCount,
          );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Created quiz with ${quiz.questions.length} questions!'),
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
