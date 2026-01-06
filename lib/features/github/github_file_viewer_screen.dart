import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/github/github_service.dart';
import 'github_provider.dart';
import 'github_notebook_selector.dart';

/// Screen for viewing a file from GitHub
class GitHubFileViewerScreen extends ConsumerStatefulWidget {
  final GitHubRepo repo;
  final String filePath;

  const GitHubFileViewerScreen({
    super.key,
    required this.repo,
    required this.filePath,
  });

  @override
  ConsumerState<GitHubFileViewerScreen> createState() =>
      _GitHubFileViewerScreenState();
}

class _GitHubFileViewerScreenState
    extends ConsumerState<GitHubFileViewerScreen> {
  GitHubFile? _file;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = await ref.read(githubProvider.notifier).getFileContent(
            widget.filePath,
            owner: widget.repo.owner,
            repo: widget.repo.name,
          );

      if (file == null) {
        setState(() {
          _error = 'File not found or could not be loaded';
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _file = file;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load file: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName),
            Text(
              widget.filePath,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_file != null) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy Content',
              onPressed: () => _copyContent(),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: 'Open in GitHub',
              onPressed: () => _openInGitHub(),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add_source',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Add as Source'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy_url',
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 20),
                      SizedBox(width: 8),
                      Text('Copy URL'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading ${widget.filePath.split('/').last}...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadFile,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_file == null) {
      return const Center(
        child: Text('File not found'),
      );
    }

    return Column(
      children: [
        // File info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              Icon(_getFileIcon(widget.filePath), size: 16),
              const SizedBox(width: 8),
              Text(
                _getLanguageFromPath(widget.filePath),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                _formatFileSize(_file!.size),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(width: 16),
              Text(
                '${_file!.content?.split('\n').length ?? 0} lines',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),

        // Code content
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildCodeView(),
            ),
          ),
        ),
      ],
    );
  }

  String _getLanguageFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart':
        return 'Dart';
      case 'js':
        return 'JavaScript';
      case 'ts':
        return 'TypeScript';
      case 'jsx':
        return 'JSX';
      case 'tsx':
        return 'TSX';
      case 'py':
        return 'Python';
      case 'java':
        return 'Java';
      case 'kt':
        return 'Kotlin';
      case 'swift':
        return 'Swift';
      case 'json':
        return 'JSON';
      case 'yaml':
      case 'yml':
        return 'YAML';
      case 'md':
        return 'Markdown';
      case 'html':
        return 'HTML';
      case 'css':
        return 'CSS';
      case 'sql':
        return 'SQL';
      case 'sh':
        return 'Shell';
      default:
        return 'Plain Text';
    }
  }

  Widget _buildCodeView() {
    final content = _file!.content ?? '';
    final lines = content.split('\n');
    final lineNumberWidth = lines.length.toString().length * 10.0 + 16;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line numbers
        Container(
          width: lineNumberWidth,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              right: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
              lines.length,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Code content
        Padding(
          padding: const EdgeInsets.all(8),
          child: SelectableText(
            _file!.content ?? '',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getFileIcon(String path) {
    final ext = path.split('.').last.toLowerCase();
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
      case 'html':
      case 'css':
        return Icons.web;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _copyContent() {
    if (_file != null && _file!.content != null) {
      Clipboard.setData(ClipboardData(text: _file!.content!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content copied to clipboard')),
      );
    }
  }

  void _openInGitHub() {
    final url =
        'https://github.com/${widget.repo.owner}/${widget.repo.name}/blob/${widget.repo.defaultBranch}/${widget.filePath}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GitHub URL copied to clipboard')),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'add_source':
        _showAddSourceDialog();
        break;
      case 'copy_url':
        _openInGitHub();
        break;
    }
  }

  void _showAddSourceDialog() {
    showGitHubNotebookSelector(
      context,
      filePath: widget.filePath,
    );
  }
}
