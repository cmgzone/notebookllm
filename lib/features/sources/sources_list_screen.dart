import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'source_provider.dart';
import 'add_source_sheet.dart';
import '../../ui/widgets/source_card.dart';
import 'source_detail_screen.dart';
import 'source_filter_provider.dart';
import 'enhanced_text_note_sheet.dart';
import 'source_preview_sheet.dart';
import 'bulk_tag_sheet.dart';

class SourcesListScreen extends ConsumerStatefulWidget {
  const SourcesListScreen({super.key});

  @override
  ConsumerState<SourcesListScreen> createState() => _SourcesListScreenState();
}

class _SourcesListScreenState extends ConsumerState<SourcesListScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode(String initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(initialId);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List sources) {
    setState(() {
      if (_selectedIds.length == sources.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(sources.map((s) => s.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count sources?'),
        content: const Text(
            'This action cannot be undone. All selected sources and their notes will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final notifier = ref.read(sourceProvider.notifier);
      for (final id in _selectedIds.toList()) {
        await notifier.deleteSource(id);
      } // In a real app, use a bulk delete API
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count sources deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _exitSelectionMode();
      }
    }
  }

  Future<void> _bulkTag() async {
    final newTags = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BulkTagSheet(),
    );

    if (newTags != null && newTags.isNotEmpty) {
      final notifier = ref.read(sourceProvider.notifier);
      final sources =
          ref.read(sourceProvider); // Get current state to access existing tags

      int updatedCount = 0;
      // For each selected source
      for (final id in _selectedIds) {
        try {
          final source = sources.firstWhere((s) => s.id == id);
          // Merge existing tags with new tags (deduplicated)
          final updatedTags = {...source.tagIds, ...newTags}.toList();
          await notifier.updateSource(sourceId: id, tagIds: updatedTags);
          updatedCount++;
        } catch (e) {
          debugPrint('Error updating tags for source $id: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tags applied to $updatedCount sources'),
            backgroundColor: Colors.green,
          ),
        );
        _exitSelectionMode();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSources = ref.watch(sourceProvider);
    final filter = ref.watch(sourceFilterProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Apply filters
    var sources = allSources.where((source) {
      // Search filter
      if (filter.searchQuery.isNotEmpty) {
        final query = filter.searchQuery.toLowerCase();
        if (!source.title.toLowerCase().contains(query) &&
            !source.content.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Type filter
      if (filter.selectedTypes.isNotEmpty &&
          !filter.selectedTypes.contains(source.type)) {
        return false;
      }

      // Tag filter
      if (filter.selectedTags.isNotEmpty) {
        final hasTag =
            source.tagIds.any((id) => filter.selectedTags.contains(id));
        if (!hasTag) return false;
      }

      return true;
    }).toList();

    // Apply sorting
    sources.sort((a, b) {
      int comparison;
      switch (filter.sortBy) {
        case 'title':
          comparison = a.title.compareTo(b.title);
          break;
        case 'type':
          comparison = a.type.compareTo(b.type);
          break;
        case 'date':
        default:
          comparison = a.addedAt.compareTo(b.addedAt);
      }
      return filter.ascending ? comparison : -comparison;
    });

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) async {
        if (_isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelectionMode,
                )
              : null,
          title: _isSelectionMode
              ? Text('${_selectedIds.length} selected')
              : const Text('My Sources'),
          actions: [
            if (_isSelectionMode) ...[
              IconButton(
                icon: Icon(
                  _selectedIds.length == sources.length
                      ? Icons.deselect
                      : Icons.select_all,
                ),
                tooltip: _selectedIds.length == sources.length
                    ? 'Deselect All'
                    : 'Select All',
                onPressed: () => _selectAll(sources),
              ),
              IconButton(
                icon: const Icon(Icons.label_outline),
                tooltip: 'Tag Selected',
                onPressed: _selectedIds.isEmpty ? null : _bulkTag,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete Selected',
                onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFilterSheet(context, ref),
                tooltip: 'Filter & Sort',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    ref.read(sourceProvider.notifier).loadSources(),
                tooltip: 'Refresh',
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            // Search bar (Hide in selection mode to save space/confusion?) - Keeping for now
            if (!_isSelectionMode)
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search sources...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: filter.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => ref
                                .read(sourceFilterProvider.notifier)
                                .setSearchQuery(''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => ref
                      .read(sourceFilterProvider.notifier)
                      .setSearchQuery(value),
                ),
              ),
            // Active filters chips
            if (!_isSelectionMode &&
                (filter.selectedTypes.isNotEmpty ||
                    filter.selectedTags.isNotEmpty))
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...filter.selectedTypes.map((type) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(type),
                            onDeleted: () => ref
                                .read(sourceFilterProvider.notifier)
                                .toggleType(type),
                          ),
                        )),
                    if (filter.selectedTypes.isNotEmpty ||
                        filter.selectedTags.isNotEmpty)
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(sourceFilterProvider.notifier).reset(),
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear all'),
                      ),
                  ],
                ),
              ),
            // Sources list
            Expanded(
              child: sources.isEmpty
                  ? (allSources.isEmpty
                      ? _buildEmptyState(context, scheme, text)
                      : _buildNoResultsState(context, scheme, text))
                  : _buildSourcesList(context, ref, sources),
            ),
          ],
        ),
        floatingActionButton: _isSelectionMode
            ? null // Hide FAB in selection mode
            : FloatingActionButton.extended(
                onPressed: () => _showAddSourceSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Source'),
              ),
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
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                Icons.source,
                size: 80,
                color: scheme.primary.withValues(alpha: 0.5),
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              'No sources yet',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 12),
            Text(
              'Add your first source to get started.\nSupports YouTube, Google Drive, web URLs, and more!',
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _showAddSourceSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Source'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ).animate().slideY(begin: 0.2, delay: 600.ms).fadeIn(),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesList(BuildContext context, WidgetRef ref, List sources) {
    return RefreshIndicator(
      onRefresh: () => ref.read(sourceProvider.notifier).loadSources(),
      child: ListView.builder(
        key: ValueKey(sources.length),
        padding: const EdgeInsets.all(16),
        itemCount: sources.length,
        itemBuilder: (context, index) {
          final source = sources[index];
          final isSelected = _selectedIds.contains(source.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SourceCard(
              source: source,
              isSelectionMode: _isSelectionMode,
              isSelected: isSelected,
              onSelectionChanged: (_) => _toggleSelection(source.id),
              onLongPress: () => _enterSelectionMode(source.id),
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(source.id);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SourceDetailScreen(sourceId: source.id),
                    ),
                  );
                }
              },
              onPreview: () => _showPreviewSheet(context, source),
              onEdit: source.type == 'text'
                  ? () => _showEditSheet(context, source)
                  : null,
              onDelete: () => _confirmDelete(context, ref, source),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoResultsState(
      BuildContext context, ColorScheme scheme, TextTheme text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No sources found',
              style: text.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search query',
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const AddSourceSheet(),
      ),
    );
  }

  void _showEditSheet(BuildContext context, source) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EnhancedTextNoteSheet(existingSource: source),
    );
  }

  void _showPreviewSheet(BuildContext context, source) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SourcePreviewSheet(source: source),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter & Sort',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Sort by',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Date'),
                  selected: ref.watch(sourceFilterProvider).sortBy == 'date',
                  onSelected: (_) =>
                      ref.read(sourceFilterProvider.notifier).setSortBy('date'),
                ),
                ChoiceChip(
                  label: const Text('Title'),
                  selected: ref.watch(sourceFilterProvider).sortBy == 'title',
                  onSelected: (_) => ref
                      .read(sourceFilterProvider.notifier)
                      .setSortBy('title'),
                ),
                ChoiceChip(
                  label: const Text('Type'),
                  selected: ref.watch(sourceFilterProvider).sortBy == 'type',
                  onSelected: (_) =>
                      ref.read(sourceFilterProvider.notifier).setSortBy('type'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Filter by type',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children:
                  ['text', 'url', 'youtube', 'drive', 'image', 'video', 'audio']
                      .map((type) => FilterChip(
                            label: Text(type),
                            selected: ref
                                .watch(sourceFilterProvider)
                                .selectedTypes
                                .contains(type),
                            onSelected: (_) => ref
                                .read(sourceFilterProvider.notifier)
                                .toggleType(type),
                          ))
                      .toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, source) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Source'),
        content: Text('Are you sure you want to delete "${source.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(sourceProvider.notifier).deleteSource(source.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Source deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
