import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../social_sharing_provider.dart';
import '../../../core/api/api_service.dart';
import '../../../core/sources/source_icon_helper.dart';

/// Screen to view a public notebook with its sources
/// Users can view source details and fork the notebook to their account
class PublicNotebookScreen extends ConsumerStatefulWidget {
  final String notebookId;

  const PublicNotebookScreen({super.key, required this.notebookId});

  @override
  ConsumerState<PublicNotebookScreen> createState() =>
      _PublicNotebookScreenState();
}

class _PublicNotebookScreenState extends ConsumerState<PublicNotebookScreen> {
  bool _isLoading = true;
  bool _isForking = false;
  String? _error;
  Map<String, dynamic>? _notebook;
  List<dynamic> _sources = [];
  Map<String, dynamic>? _owner;

  @override
  void initState() {
    super.initState();
    _loadNotebookDetails();
  }

  Future<void> _loadNotebookDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api
          .get('/social-sharing/public/notebooks/${widget.notebookId}');

      if (response['success'] == true) {
        setState(() {
          _notebook = response['notebook'];
          _sources = response['sources'] ?? [];
          _owner = response['owner'];
          _isLoading = false;
        });

        // Record view
        ref
            .read(socialSharingServiceProvider)
            .recordView('notebook', widget.notebookId);
      } else {
        setState(() {
          _error = 'Notebook not found or not public';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _forkNotebook() async {
    setState(() => _isForking = true);

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '/social-sharing/fork/notebook/${widget.notebookId}',
        {'includeSources': true},
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Notebook forked! ${response['sourcesCopied']} sources copied.'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  context.push('/notebook/${response['notebook']['id']}');
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fork: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isForking = false);
      }
    }
  }

  void _showSourceDetail(Map<String, dynamic> source) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _SourceDetailSheet(
          source: source,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _notebook == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(_error ?? 'Notebook not found',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final notebook = _notebook!;
    final title = notebook['title'] ?? 'Untitled';
    final description = notebook['description'];
    final sourceCount = _sources.length;
    final viewCount = notebook['view_count'] ?? 0;
    final likeCount = notebook['like_count'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share link functionality
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Header with owner info
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Owner info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: _owner?['avatarUrl'] != null
                            ? NetworkImage(_owner!['avatarUrl'])
                            : null,
                        child: _owner?['avatarUrl'] == null
                            ? Text(
                                (_owner?['username'] ?? '?')[0].toUpperCase())
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _owner?['username'] ?? 'Unknown',
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              'Created ${timeago.format(DateTime.parse(notebook['created_at']))}',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 16),
                  // Stats row
                  Row(
                    children: [
                      _StatBadge(
                          icon: Icons.source,
                          value: sourceCount,
                          label: 'sources'),
                      const SizedBox(width: 16),
                      _StatBadge(
                          icon: Icons.visibility,
                          value: viewCount,
                          label: 'views'),
                      const SizedBox(width: 16),
                      _StatBadge(
                          icon: Icons.favorite,
                          value: likeCount,
                          label: 'likes'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Sources header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Sources ($sourceCount)',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_sources.isNotEmpty)
                    TextButton.icon(
                      onPressed: _isForking ? null : _forkNotebook,
                      icon: _isForking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fork_right),
                      label: Text(_isForking ? 'Forking...' : 'Fork All'),
                    ),
                ],
              ),
            ),
          ),

          // Sources list
          if (_sources.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.source_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('No sources in this notebook',
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final source = _sources[index];
                    return _SourceCard(
                      source: source,
                      onTap: () => _showSourceDetail(source),
                    );
                  },
                  childCount: _sources.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(discoverProvider.notifier)
                        .likeNotebook(widget.notebookId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Liked!')),
                    );
                  },
                  icon: Icon(
                    notebook['user_liked'] == true
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: notebook['user_liked'] == true ? Colors.red : null,
                  ),
                  label: const Text('Like'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _isForking ? null : _forkNotebook,
                  icon: _isForking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.fork_right),
                  label:
                      Text(_isForking ? 'Forking...' : 'Fork to My Notebooks'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  final Map<String, dynamic> source;
  final VoidCallback onTap;

  const _SourceCard({required this.source, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = source['title'] ?? 'Untitled';
    final type = source['type'] ?? 'text';
    final summary = source['summary'];
    final contentPreview = source['content_preview'];
    final addedAt = source['created_at'] != null
        ? DateTime.parse(source['created_at'])
        : DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  SourceIconHelper.getIconForType(type),
                  color: _getTypeColor(type),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary ?? contentPreview ?? 'No preview available',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTypeColor(type).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getTypeColor(type),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(addedAt),
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'youtube':
        return Colors.red;
      case 'url':
        return Colors.blue;
      case 'drive':
        return Colors.green;
      case 'text':
        return Colors.orange;
      case 'audio':
        return Colors.purple;
      case 'image':
        return Colors.pink;
      case 'github':
        return Colors.grey.shade800;
      case 'code':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

class _SourceDetailSheet extends StatelessWidget {
  final Map<String, dynamic> source;
  final ScrollController scrollController;

  const _SourceDetailSheet({
    required this.source,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = source['title'] ?? 'Untitled';
    final type = source['type'] ?? 'text';
    final summary = source['summary'];
    final contentPreview = source['content_preview'];
    final content = source['content'];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getTypeColor(type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    SourceIconHelper.getIconForType(type),
                    color: _getTypeColor(type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTypeColor(type).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getTypeColor(type),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          // Content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                if (summary != null && summary.isNotEmpty) ...[
                  Text('Summary',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(summary),
                  ),
                  const SizedBox(height: 24),
                ],
                Text('Content Preview',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    content ?? contentPreview ?? 'No content available',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'youtube':
        return Colors.red;
      case 'url':
        return Colors.blue;
      case 'drive':
        return Colors.green;
      case 'text':
        return Colors.orange;
      case 'audio':
        return Colors.purple;
      case 'image':
        return Colors.pink;
      case 'github':
        return Colors.grey.shade800;
      case 'code':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
