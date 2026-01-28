import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'add_source_sheet.dart';
import 'source_provider.dart';
import 'source.dart';
import 'source_detail_screen.dart';
import '../../core/theme/theme_provider.dart';

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sources = ref.watch(sourceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sources'),
        actions: [
          Consumer(builder: (context, ref, _) {
            final mode = ref.watch(themeModeProvider);
            return IconButton(
              icon: Icon(mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
              tooltip: mode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
              onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            );
          }),
          IconButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const AddSourceSheet(),
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add or manage sources', style: text.titleLarge),
            const SizedBox(height: 16),
            const Wrap(spacing: 8, runSpacing: 8, children: [
              _SourceChip(label: 'Google Drive'),
              _SourceChip(label: 'File'),
              _SourceChip(label: 'Web URL'),
              _SourceChip(label: 'YouTube'),
              _SourceChip(label: 'Audio (transcript)'),
            ]),
            const SizedBox(height: 24),
            if (sources.isEmpty) const _EmptySources() else _SourcesList(sources: sources),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => context.go('/search'),
            heroTag: 'web_search',
            backgroundColor: scheme.secondary,
            child: const Icon(Icons.search),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const AddSourceSheet(),
              ),
            ),
            heroTag: 'add_source',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _SourcesList extends StatelessWidget {
  const _SourcesList({required this.sources});
  final List<Source> sources;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: sources
          .map((s) => Card(
                child: ListTile(
                  leading: Icon(_iconForType(s.type), color: scheme.primary),
                  title: Text(s.title),
                  subtitle: Text('${s.type} • ${s.addedAt.day}/${s.addedAt.month}/${s.addedAt.year}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SourceDetailScreen(sourceId: s.id),
                        ),
                      );
                    },
                  ),
                ),
              ))
          .toList(),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'drive':
        return Icons.drive_folder_upload;
      case 'file':
        return Icons.attach_file;
      case 'url':
        return Icons.link;
      case 'youtube':
        return Icons.video_library;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.source;
    }
  }
}

class _EmptySources extends StatelessWidget {
  const _EmptySources();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.folder_open, color: scheme.primary),
          const SizedBox(width: 12),
          const Expanded(child: Text('No sources yet — add one to begin')),
        ],
      ),
    );
  }
}