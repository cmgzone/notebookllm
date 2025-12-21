import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../agents/ebook_orchestrator.dart';
import '../models/ebook_project.dart';
import 'ebook_reader_screen.dart';

class EbookGenerationView extends ConsumerWidget {
  const EbookGenerationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(ebookOrchestratorProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (project == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Auto-navigate when complete or show error
    ref.listen(ebookOrchestratorProvider, (prev, next) {
      if (next?.status == EbookStatus.completed) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => EbookReaderScreen(project: next!)),
        );
      } else if (next?.status == EbookStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next!.currentPhase}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creating "${project.title}"',
                style:
                    text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Our agents are working on your ebook...',
                style: text.bodyLarge
                    ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: project.status == EbookStatus.error
                      ? scheme.errorContainer
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (project.status == EbookStatus.error)
                      Icon(Icons.error_outline,
                          size: 16, color: scheme.onErrorContainer)
                    else
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(scheme.onPrimaryContainer),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        project.currentPhase,
                        style: text.bodyMedium?.copyWith(
                          color: project.status == EbookStatus.error
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().shimmer(),

              // Retry button on error
              if (project.status == EbookStatus.error) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back & Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 48),

              // Agents Status
              _AgentStatusRow(
                icon: LucideIcons.search,
                label: 'Research Agent',
                status: _getResearchStatus(project),
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              _AgentStatusRow(
                icon: LucideIcons.penTool,
                label: 'Content Agent',
                status: _getContentStatus(project),
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              _AgentStatusRow(
                icon: LucideIcons.palette,
                label: 'Designer Agent',
                status: _getDesignerStatus(project),
                color: Colors.purple,
              ),

              const Spacer(),

              // Progress Log
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LIVE LOG',
                        style: text.labelSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (project.chapters.isNotEmpty)
                      ...project.chapters.map((c) {
                        if (c.isGenerating) {
                          return Text('• Writing chapter: ${c.title}...',
                              style: text.bodySmall);
                        }
                        if (c.content.isNotEmpty) {
                          return Text('✓ Completed: ${c.title}',
                              style: text.bodySmall
                                  ?.copyWith(color: Colors.green));
                        }
                        return const SizedBox.shrink();
                      }),
                    if (project.chapters.isEmpty)
                      Text('• Initializing agents...', style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getResearchStatus(EbookProject p) {
    if (p.chapters.isNotEmpty) return 'Completed';
    return 'Gathering facts...';
  }

  String _getContentStatus(EbookProject p) {
    if (p.chapters.isEmpty) return 'Waiting...';
    final completed = p.chapters.where((c) => c.content.isNotEmpty).length;
    if (completed == p.chapters.length) return 'Completed';
    return 'Writing ($completed/${p.chapters.length})';
  }

  String _getDesignerStatus(EbookProject p) {
    if (p.coverImageUrl != null) return 'Cover Ready';
    if (p.chapters.isNotEmpty) return 'Designing...';
    return 'Waiting...';
  }
}

class _AgentStatusRow extends StatelessWidget {
  const _AgentStatusRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isWaiting = status == 'Waiting...';
    final isCompleted = status == 'Completed' || status == 'Cover Ready';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(status, style: text.bodyMedium),
          ],
        ),
        const Spacer(),
        if (!isWaiting && !isCompleted)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        if (isCompleted) const Icon(Icons.check_circle, color: Colors.green),
      ],
    ).animate().fadeIn().slideX();
  }
}
