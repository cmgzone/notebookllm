import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notebook/notebook_provider.dart';
import 'github_provider.dart';
import 'github_source_provider.dart';

/// Dialog for selecting a notebook to add a GitHub file as source
/// Requirements: 1.1 - Create GitHub_Source in selected notebook
class GitHubNotebookSelector extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;
  final String? owner;
  final String? repo;
  final String? branch;

  const GitHubNotebookSelector({
    super.key,
    required this.filePath,
    required this.fileName,
    this.owner,
    this.repo,
    this.branch,
  });

  @override
  ConsumerState<GitHubNotebookSelector> createState() =>
      _GitHubNotebookSelectorState();
}

class _GitHubNotebookSelectorState
    extends ConsumerState<GitHubNotebookSelector> {
  bool _isAdding = false;
  String? _selectedNotebookId;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final notebooks = ref.watch(notebookProvider);
    final githubState = ref.watch(githubProvider);
    final scheme = Theme.of(context).colorScheme;

    // Get owner and repo from props or from selected repo in github state
    final owner = widget.owner ?? githubState.selectedRepo?.owner;
    final repo = widget.repo ?? githubState.selectedRepo?.name;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle_outline, color: scheme.primary),
          const SizedBox(width: 8),
          const Text('Add as Source'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info card
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
                  Icon(
                    _getFileIcon(widget.fileName),
                    color: scheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (owner != null && repo != null)
                          Text(
                            '$owner/$repo',
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
            if (githubState.error != null && _error == null) ...[
              const SizedBox(height: 8),
              Text(
                githubState.error!,
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ],
          ],
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
              : () => _addAsSource(owner, repo),
          icon: _isAdding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add, size: 18),
          label: Text(_isAdding ? 'Adding...' : 'Add Source'),
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

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart':
        return Icons.flutter_dash;
      case 'js':
      case 'ts':
      case 'jsx':
      case 'tsx':
        return Icons.javascript;
      case 'py':
        return Icons.code;
      case 'java':
      case 'kt':
        return Icons.android;
      case 'swift':
        return Icons.apple;
      case 'json':
      case 'yaml':
      case 'yml':
        return Icons.data_object;
      case 'md':
      case 'txt':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _addAsSource(String? owner, String? repo) async {
    if (_selectedNotebookId == null) return;

    if (owner == null || repo == null) {
      setState(() {
        _error = 'Repository information not available';
      });
      return;
    }

    setState(() {
      _isAdding = true;
      _error = null;
    });

    try {
      // Use the GitHubSourceProvider for better state management
      final source =
          await ref.read(githubSourceProvider.notifier).addGitHubSource(
                notebookId: _selectedNotebookId!,
                owner: owner,
                repo: repo,
                path: widget.filePath,
                branch: widget.branch,
              );

      if (mounted) {
        if (source != null) {
          Navigator.pop(context, true);
          _showSuccessSnackBar(context, source);
        } else {
          // Check for error in provider state
          final addError = ref.read(githubSourceAddErrorProvider);
          setState(() {
            _isAdding = false;
            _error = addError ?? 'Failed to add source';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdding = false;
          _error = e.toString();
        });
      }
    }
  }

  void _showSuccessSnackBar(BuildContext context, GitHubSource source) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Added "${widget.fileName}" to notebook',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Language: ${source.metadata.language}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Could navigate to the source detail screen
          },
        ),
      ),
    );
  }
}

/// Shows the notebook selector dialog and returns true if source was added
/// Requirements: 1.1 - Show notebook selector when adding source
Future<bool> showGitHubNotebookSelector(
  BuildContext context, {
  required String filePath,
  String? owner,
  String? repo,
  String? branch,
}) async {
  final fileName = filePath.split('/').last;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => GitHubNotebookSelector(
      filePath: filePath,
      fileName: fileName,
      owner: owner,
      repo: repo,
      branch: branch,
    ),
  );

  return result ?? false;
}
