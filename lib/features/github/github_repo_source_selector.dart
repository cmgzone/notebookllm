import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/github/github_service.dart';
import '../notebook/notebook_provider.dart';
import '../sources/source_provider.dart';
import 'github_provider.dart';

/// Dialog for selecting a notebook to add an entire GitHub repo as sources
class GitHubRepoSourceSelector extends ConsumerStatefulWidget {
  final GitHubRepo repo;

  const GitHubRepoSourceSelector({
    super.key,
    required this.repo,
  });

  @override
  ConsumerState<GitHubRepoSourceSelector> createState() =>
      _GitHubRepoSourceSelectorState();
}

class _GitHubRepoSourceSelectorState
    extends ConsumerState<GitHubRepoSourceSelector> {
  bool _isAdding = false;
  String? _selectedNotebookId;
  String? _error;
  final _maxFilesController = TextEditingController();
  final _maxSizeKbController = TextEditingController();
  final _includeExtController = TextEditingController();
  final _excludeExtController = TextEditingController();

  @override
  void dispose() {
    _maxFilesController.dispose();
    _maxSizeKbController.dispose();
    _includeExtController.dispose();
    _excludeExtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notebooks = ref.watch(notebookProvider);
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_box_outlined, color: scheme.primary),
          const SizedBox(width: 8),
          const Text('Add Repo as Sources'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Repo info card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder, color: scheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.repo.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Branch: ${widget.repo.defaultBranch}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This will add repository files as sources (skips binary and very large files).',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a notebook:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              if (notebooks.isEmpty)
                _buildEmptyState(scheme)
              else
                _buildNotebookList(notebooks, scheme),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Advanced options',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
                children: [
                  Text(
                    'Defaults: max 200 files, max 200 KB per file.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _maxFilesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Max files',
                      hintText: 'e.g. 200',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _maxSizeKbController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Max file size (KB)',
                      hintText: 'e.g. 200',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _includeExtController,
                    decoration: const InputDecoration(
                      labelText: 'Include extensions (comma separated)',
                      hintText: 'e.g. dart,ts,md',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _excludeExtController,
                    decoration: const InputDecoration(
                      labelText: 'Exclude extensions (comma separated)',
                      hintText: 'e.g. png,jpg,lock',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'If include extensions are provided, exclude list is ignored.',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: scheme.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: scheme.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isAdding ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _selectedNotebookId == null || _isAdding
              ? null
              : _addRepoAsSources,
          icon: _isAdding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.playlist_add, size: 18),
          label: Text(_isAdding ? 'Adding...' : 'Add Sources'),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.folder_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No notebooks found',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a notebook first to add sources',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotebookList(List notebooks, ColorScheme scheme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 250),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: notebooks.length,
        itemBuilder: (context, index) {
          final notebook = notebooks[index];
          final isSelected = _selectedNotebookId == notebook.id;

          return Card(
            elevation: isSelected ? 2 : 0,
            color: isSelected
                ? scheme.primaryContainer.withValues(alpha: 0.3)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSelected
                  ? BorderSide(color: scheme.primary, width: 2)
                  : BorderSide.none,
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary.withValues(alpha: 0.2)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.book,
                  color: isSelected ? scheme.primary : Colors.grey[600],
                  size: 20,
                ),
              ),
              title: Text(
                notebook.title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? scheme.primary : null,
                ),
              ),
              subtitle: Text(
                '${notebook.sourceCount} sources',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: scheme.primary)
                  : Icon(
                      Icons.radio_button_unchecked,
                      color: scheme.outline.withValues(alpha: 0.5),
                    ),
              onTap: () {
                setState(() {
                  _selectedNotebookId = notebook.id;
                  _error = null;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _addRepoAsSources() async {
    if (_selectedNotebookId == null) return;

    setState(() {
      _isAdding = true;
      _error = null;
    });

    try {
      final maxFiles = _parseOptionalInt(_maxFilesController);
      final maxSizeKb = _parseOptionalInt(_maxSizeKbController);
      final maxFileSizeBytes = maxSizeKb != null ? maxSizeKb * 1024 : null;
      final includeExtensions = _parseExtensions(_includeExtController);
      final excludeExtensions = _parseExtensions(_excludeExtController);

      final result = await ref.read(githubProvider.notifier).addRepoAsSources(
            notebookId: _selectedNotebookId!,
            maxFiles: maxFiles,
            maxFileSizeBytes: maxFileSizeBytes,
            includeExtensions: includeExtensions,
            excludeExtensions: excludeExtensions,
          );

      if (!mounted) return;

      if (result == null || result['success'] != true) {
        setState(() {
          _isAdding = false;
          _error = result?['message']?.toString() ?? 'Failed to add sources';
        });
        return;
      }

      await ref.read(sourceProvider.notifier).loadSources();
      await ref.read(notebookProvider.notifier).refresh();

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      _showSuccessSnackBar(messenger, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdding = false;
          _error = e.toString();
        });
      }
    }
  }

  void _showSuccessSnackBar(
      ScaffoldMessengerState messenger, Map<String, dynamic> result) {
    final added = result['addedCount'] ?? 0;
    final skipped = result['skippedCount'] ?? 0;
    final limited = result['limited'] == true;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                limited
                    ? 'Added $added files, skipped $skipped (limit reached)'
                    : 'Added $added files, skipped $skipped',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

int? _parseOptionalInt(TextEditingController controller) {
  final text = controller.text.trim();
  if (text.isEmpty) return null;
  final value = int.tryParse(text);
  if (value == null || value <= 0) return null;
  return value;
}

List<String>? _parseExtensions(TextEditingController controller) {
  final text = controller.text.trim();
  if (text.isEmpty) return null;
  final items = text
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  return items.isEmpty ? null : items;
}

/// Shows the repo source selector dialog
Future<bool> showGitHubRepoSourceSelector(
  BuildContext context, {
  required GitHubRepo repo,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => GitHubRepoSourceSelector(repo: repo),
  );
  return result ?? false;
}
