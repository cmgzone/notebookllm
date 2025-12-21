import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'tutor_session.dart';
import 'tutor_provider.dart';

/// Screen showing all tutor sessions for a notebook
class TutorSessionsScreen extends ConsumerWidget {
  final String notebookId;

  const TutorSessionsScreen({super.key, required this.notebookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSessions = ref.watch(tutorProvider);
    final sessions =
        allSessions.where((s) => s.notebookId == notebookId).toList();
    // Sort by most recent first
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutor Sessions'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'New Session',
            onPressed: () => _startNewSession(context),
          ),
        ],
      ),
      body: sessions.isEmpty
          ? _buildEmptyState(context, scheme, text)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _buildSessionCard(
                    context, ref, session, scheme, text, index);
              },
            ),
      floatingActionButton: sessions.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _startNewSession(context),
              icon: const Icon(LucideIcons.graduationCap),
              label: const Text('New Session'),
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
                LucideIcons.graduationCap,
                size: 64,
                color: scheme.onPrimaryContainer,
              ),
            ).animate().scale(delay: 200.ms),
            const SizedBox(height: 24),
            Text(
              'No Tutor Sessions Yet',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 12),
            Text(
              'Start a tutoring session to learn\nthrough interactive Q&A!',
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _startNewSession(context),
              icon: const Icon(LucideIcons.sparkles),
              label: const Text('Start Tutoring'),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    WidgetRef ref,
    TutorSession session,
    ColorScheme scheme,
    TextTheme text,
    int index,
  ) {
    final accuracy = session.accuracy * 100;
    final isComplete = session.isComplete;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _resumeSession(context, session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Accuracy indicator
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: session.questionsAsked > 0 ? accuracy / 100 : 0,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        accuracy >= 80
                            ? Colors.green
                            : accuracy >= 50
                                ? Colors.orange
                                : scheme.primary,
                      ),
                      strokeWidth: 4,
                    ),
                  ),
                  if (session.questionsAsked > 0)
                    Text(
                      '${accuracy.round()}%',
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    )
                  else
                    Icon(
                      LucideIcons.graduationCap,
                      size: 24,
                      color: scheme.primary,
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Session info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.topic,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isComplete)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Completed',
                              style: text.labelSmall?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildInfoChip(
                          scheme,
                          text,
                          LucideIcons.helpCircle,
                          '${session.questionsAsked} Q',
                        ),
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          scheme,
                          text,
                          LucideIcons.checkCircle,
                          '${session.correctAnswers} correct',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            session.style.displayName,
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            session.difficulty.displayName,
                            style: text.labelSmall?.copyWith(
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _confirmDelete(context, ref, session);
                  } else if (value == 'resume') {
                    _resumeSession(context, session);
                  }
                },
                itemBuilder: (context) => [
                  if (!isComplete)
                    const PopupMenuItem(
                      value: 'resume',
                      child: Row(
                        children: [
                          Icon(LucideIcons.play, size: 18),
                          SizedBox(width: 12),
                          Text('Resume'),
                        ],
                      ),
                    ),
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

  Widget _buildInfoChip(
    ColorScheme scheme,
    TextTheme text,
    IconData icon,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: scheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: text.bodySmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  void _startNewSession(BuildContext context) {
    context.push(
      '/notebook/$notebookId/tutor',
      extra: <String, dynamic>{},
    );
  }

  void _resumeSession(BuildContext context, TutorSession session) {
    context.push(
      '/notebook/$notebookId/tutor',
      extra: <String, dynamic>{'sessionId': session.id},
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, TutorSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text(
            'Are you sure you want to delete this session on "${session.topic}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(tutorProvider.notifier).deleteSession(session.id);
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
