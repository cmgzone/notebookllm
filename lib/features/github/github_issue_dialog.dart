import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'github_provider.dart';
import '../../core/api/api_service.dart';

/// Shows a dialog to create a GitHub issue from an AI suggestion
/// Requirements: 6.4 - Support creating GitHub issues with pre-filled title and body
Future<void> showGitHubIssueDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String body,
  String? owner,
  String? repo,
}) async {
  return showDialog(
    context: context,
    builder: (context) => GitHubIssueDialog(
      initialTitle: title,
      initialBody: body,
      initialOwner: owner,
      initialRepo: repo,
    ),
  );
}

class GitHubIssueDialog extends ConsumerStatefulWidget {
  final String initialTitle;
  final String initialBody;
  final String? initialOwner;
  final String? initialRepo;

  const GitHubIssueDialog({
    super.key,
    required this.initialTitle,
    required this.initialBody,
    this.initialOwner,
    this.initialRepo,
  });

  @override
  ConsumerState<GitHubIssueDialog> createState() => _GitHubIssueDialogState();
}

class _GitHubIssueDialogState extends ConsumerState<GitHubIssueDialog> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  String? _selectedOwner;
  String? _selectedRepo;
  bool _isLoading = false;
  bool _isCreating = false;
  List<Map<String, dynamic>> _repos = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
    _selectedOwner = widget.initialOwner;
    _selectedRepo = widget.initialRepo;
    _loadRepos();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadRepos() async {
    final githubState = ref.read(githubProvider);
    if (!githubState.isConnected) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/github/repos');

      if (response['success'] == true && response['repos'] != null) {
        setState(() {
          _repos = List<Map<String, dynamic>>.from(response['repos']);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading repos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createIssue() async {
    if (_selectedOwner == null || _selectedRepo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a repository')),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '/github/repos/$_selectedOwner/$_selectedRepo/issues',
        {
          'title': _titleController.text.trim(),
          'body': _bodyController.text.trim(),
        },
      );

      if (response['success'] == true && response['issue'] != null) {
        final issueUrl = response['issue']['html_url'] as String?;

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Issue created successfully!'),
              action: issueUrl != null
                  ? SnackBarAction(
                      label: 'View',
                      onPressed: () async {
                        final uri = Uri.parse(issueUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    )
                  : null,
            ),
          );
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to create issue');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _openInGitHub() async {
    if (_selectedOwner == null || _selectedRepo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a repository')),
      );
      return;
    }

    // Encode title and body for URL
    final title = Uri.encodeComponent(_titleController.text.trim());
    final body = Uri.encodeComponent(_bodyController.text.trim());

    final url =
        'https://github.com/$_selectedOwner/$_selectedRepo/issues/new?title=$title&body=$body';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final githubState = ref.watch(githubProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(LucideIcons.gitPullRequestDraft, color: scheme.primary),
          const SizedBox(width: 12),
          const Text('Create GitHub Issue'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GitHub connection check
              if (!githubState.isConnected) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connect GitHub to create issues directly',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Repository selector
              if (githubState.isConnected) ...[
                const Text(
                  'Repository',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    initialValue:
                        _selectedOwner != null && _selectedRepo != null
                            ? '$_selectedOwner/$_selectedRepo'
                            : null,
                    decoration: InputDecoration(
                      hintText: 'Select repository',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: _repos.map((repo) {
                      final fullName = repo['full_name'] as String;
                      return DropdownMenuItem(
                        value: fullName,
                        child: Text(fullName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final parts = value.split('/');
                        setState(() {
                          _selectedOwner = parts[0];
                          _selectedRepo = parts[1];
                        });
                      }
                    },
                  ),
                const SizedBox(height: 16),
              ],

              // Title field
              const Text(
                'Title',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Issue title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Body field
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bodyController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Issue description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (githubState.isConnected) ...[
          OutlinedButton.icon(
            onPressed: _openInGitHub,
            icon: const Icon(LucideIcons.externalLink, size: 16),
            label: const Text('Open in GitHub'),
          ),
          FilledButton.icon(
            onPressed: _isCreating ? null : _createIssue,
            icon: _isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.plus, size: 16),
            label: const Text('Create Issue'),
          ),
        ] else
          FilledButton.icon(
            onPressed: _openInGitHub,
            icon: const Icon(LucideIcons.externalLink, size: 16),
            label: const Text('Open in GitHub'),
          ),
      ],
    );
  }
}
