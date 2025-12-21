import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/ebook_project.dart';
import '../models/branding_config.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/ebook_export_service.dart';
import '../services/ebook_narration_service.dart';
import 'ebook_editor_screen.dart';
import '../../../core/extensions/color_compat.dart';

class EbookReaderScreen extends ConsumerWidget {
  const EbookReaderScreen({super.key, required this.project});
  final EbookProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = project.branding;
    final primaryColor = branding.primaryColor;

    return Scaffold(
      floatingActionButton:
          _NarrationFab(project: project, primaryColor: primaryColor),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(project.title),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            expandedHeight: 300,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EbookEditorScreen(project: project),
                    ),
                  );
                },
                tooltip: 'Edit Ebook',
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () async {
                  try {
                    final pdfBytes = await ref
                        .read(ebookExportServiceProvider)
                        .exportToPdf(project);
                    final tempDir = await getTemporaryDirectory();
                    final file = File(
                        '${tempDir.path}/${project.title.replaceAll(' ', '_')}.pdf');
                    await file.writeAsBytes(pdfBytes);
                    await Share.shareXFiles([XFile(file.path)],
                        text: 'Check out my ebook: ${project.title}');
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export failed: $e')),
                      );
                    }
                  }
                },
                tooltip: 'Export PDF',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: project.coverImageUrl != null
                  ? Image.network(
                      project.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: primaryColor),
                    )
                  : Container(color: primaryColor),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chapter = project.chapters[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chapter ${index + 1}',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        chapter.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 24),
                      if (chapter.images.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            chapter.images.first.url,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      MarkdownBody(
                        data: chapter.content,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(Theme.of(context))
                                .copyWith(
                          p: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          h1: TextStyle(color: primaryColor),
                          h2: TextStyle(color: primaryColor),
                          h3: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          strong: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          em: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontStyle: FontStyle.italic,
                          ),
                          listBullet: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const Divider(height: 64),
                    ],
                  );
                },
                childCount: project.chapters.length,
              ),
            ),
          ),
          // Sources Section
          if (project.notebookId != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sources',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    const Text(
                        'This ebook was grounded in your personal notebook sources.'),
                  ],
                ),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}

class _NarrationFab extends ConsumerWidget {
  final EbookProject project;
  final Color primaryColor;

  const _NarrationFab({
    required this.project,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrationStatus = ref.watch(ebookNarrationProvider);
    final isPlaying = narrationStatus.state == NarrationState.playing;
    final isPaused = narrationStatus.state == NarrationState.paused;

    if (isPlaying || isPaused) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current chapter indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              'Ch. ${narrationStatus.currentChapterIndex + 1}/${project.chapters.length}',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous chapter
              FloatingActionButton.small(
                heroTag: 'prev',
                onPressed: narrationStatus.currentChapterIndex > 0
                    ? () => ref
                        .read(ebookNarrationProvider.notifier)
                        .skipToChapter(narrationStatus.currentChapterIndex - 1)
                    : null,
                backgroundColor: primaryColor.withValues(alpha: 0.8),
                child: const Icon(Icons.skip_previous, color: Colors.white),
              ),
              const SizedBox(width: 8),
              // Play/Pause
              FloatingActionButton.extended(
                heroTag: 'play',
                onPressed: () {
                  if (isPlaying) {
                    ref.read(ebookNarrationProvider.notifier).pause();
                  } else {
                    ref.read(ebookNarrationProvider.notifier).resume();
                  }
                },
                backgroundColor: primaryColor,
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                label: Text(
                  isPlaying ? 'Pause' : 'Resume',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              // Next chapter
              FloatingActionButton.small(
                heroTag: 'next',
                onPressed: narrationStatus.currentChapterIndex <
                        project.chapters.length - 1
                    ? () => ref
                        .read(ebookNarrationProvider.notifier)
                        .skipToChapter(narrationStatus.currentChapterIndex + 1)
                    : null,
                backgroundColor: primaryColor.withValues(alpha: 0.8),
                child: const Icon(Icons.skip_next, color: Colors.white),
              ),
              const SizedBox(width: 8),
              // Stop
              FloatingActionButton.small(
                heroTag: 'stop',
                onPressed: () =>
                    ref.read(ebookNarrationProvider.notifier).stop(),
                backgroundColor: Colors.red,
                child: const Icon(Icons.stop, color: Colors.white),
              ),
            ],
          ),
        ],
      );
    }

    // Default state - start narration
    return FloatingActionButton.extended(
      onPressed: () => _showNarrationDialog(context, ref),
      icon: const Icon(Icons.headphones),
      label: const Text('Narrate'),
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    );
  }

  void _showNarrationDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start Audiobook',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose where to start narration',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondaryText,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.play_arrow, color: primaryColor),
              title: const Text('From Beginning'),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(ebookNarrationProvider.notifier)
                    .startNarration(project);
              },
            ),
            const Divider(),
            Text(
              'Or select a chapter:',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: project.chapters.length,
                itemBuilder: (context, index) {
                  final chapter = project.chapters[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                    title: Text(
                      chapter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref
                          .read(ebookNarrationProvider.notifier)
                          .startNarration(project, startChapter: index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
