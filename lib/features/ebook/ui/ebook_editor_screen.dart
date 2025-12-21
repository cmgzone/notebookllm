import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ebook_project.dart';
import '../agents/ebook_orchestrator.dart';
import '../agents/editor_agent.dart';

class EbookEditorScreen extends ConsumerStatefulWidget {
  const EbookEditorScreen({super.key, required this.project});
  final EbookProject project;

  @override
  ConsumerState<EbookEditorScreen> createState() => _EbookEditorScreenState();
}

class _EbookEditorScreenState extends ConsumerState<EbookEditorScreen> {
  late EbookProject _project;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  Future<void> _refineChapter(int index, String instruction) async {
    final chapter = _project.chapters[index];

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI is refining your chapter...')),
    );

    try {
      final refinedContent = await ref
          .read(editorAgentProvider)
          .refineText(chapter.content, instruction);

      setState(() {
        final updatedChapters = [..._project.chapters];
        updatedChapters[index] = chapter.copyWith(content: refinedContent);
        _project = _project.copyWith(chapters: updatedChapters);
      });

      // Update global state
      ref.read(ebookOrchestratorProvider.notifier).setProject(_project);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refinement complete!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refining: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Ebook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              // Save changes to orchestrator (already done in local state, but explicit save action is good UX)
              ref.read(ebookOrchestratorProvider.notifier).setProject(_project);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _project.chapters.length,
        itemBuilder: (context, index) {
          final chapter = _project.chapters[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              title: Text('Chapter ${index + 1}: ${chapter.title}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: chapter.title,
                        decoration: const InputDecoration(labelText: 'Title'),
                        onChanged: (v) {
                          final updatedChapters = [..._project.chapters];
                          updatedChapters[index] = chapter.copyWith(title: v);
                          _project =
                              _project.copyWith(chapters: updatedChapters);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: chapter.content,
                        decoration: const InputDecoration(labelText: 'Content'),
                        maxLines: 10,
                        onChanged: (v) {
                          final updatedChapters = [..._project.chapters];
                          updatedChapters[index] = chapter.copyWith(content: v);
                          _project =
                              _project.copyWith(chapters: updatedChapters);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.auto_fix_high),
                            label: const Text('Simplify'),
                            onPressed: () => _refineChapter(index,
                                "Simplify this text for a general audience."),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.short_text),
                            label: const Text('Summarize'),
                            onPressed: () => _refineChapter(index,
                                "Summarize this chapter into a concise paragraph."),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
