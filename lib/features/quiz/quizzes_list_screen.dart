import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'quiz.dart';
import 'quiz_provider.dart';
import 'quiz_generator_sheet.dart';

/// Screen showing all quizzes for a notebook
class QuizzesListScreen extends ConsumerWidget {
  final String notebookId;

  const QuizzesListScreen({super.key, required this.notebookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allQuizzes = ref.watch(quizProvider);
    final quizzes =
        allQuizzes.where((q) => q.notebookId == notebookId).toList();

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizzes'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _showGeneratorSheet(context),
          ),
        ],
      ),
      body: quizzes.isEmpty
          ? _buildEmptyState(context, scheme, text)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: quizzes.length,
              itemBuilder: (context, index) {
                final quiz = quizzes[index];
                return _buildQuizCard(context, ref, quiz, scheme, text, index);
              },
            ),
      floatingActionButton: quizzes.isEmpty
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
                color: scheme.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.clipboardCheck,
                size: 64,
                color: scheme.onTertiaryContainer,
              ),
            ).animate().scale(delay: 200.ms),
            const SizedBox(height: 24),
            Text(
              'No Quizzes Yet',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 12),
            Text(
              'Generate quizzes from your sources\nto test your knowledge!',
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _showGeneratorSheet(context),
              icon: const Icon(LucideIcons.sparkles),
              label: const Text('Generate Quiz'),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(
    BuildContext context,
    WidgetRef ref,
    Quiz quiz,
    ColorScheme scheme,
    TextTheme text,
    int index,
  ) {
    final bestPercent = quiz.bestScore != null
        ? ((quiz.bestScore! / quiz.questions.length) * 100).round()
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/quiz/${quiz.id}/play'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Best score indicator
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bestPercent != null
                      ? (bestPercent >= 70
                          ? Colors.green.withValues(alpha: 0.15)
                          : bestPercent >= 50
                              ? Colors.orange.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15))
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: bestPercent != null
                      ? Text(
                          '$bestPercent%',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: bestPercent >= 70
                                ? Colors.green
                                : bestPercent >= 50
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        )
                      : Icon(
                          LucideIcons.play,
                          color: scheme.primary,
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Quiz info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.helpCircle,
                          size: 14,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${quiz.questions.length} questions',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        if (quiz.timesAttempted > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            LucideIcons.repeat,
                            size: 14,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${quiz.timesAttempted} attempts',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _confirmDelete(context, ref, quiz);
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

  void _showGeneratorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => QuizGeneratorSheet(notebookId: notebookId),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Quiz quiz) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz?'),
        content: Text('Are you sure you want to delete "${quiz.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(quizProvider.notifier).deleteQuiz(quiz.id);
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
