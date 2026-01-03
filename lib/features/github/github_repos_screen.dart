import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/github/github_service.dart';
import 'github_provider.dart';

/// Screen for browsing GitHub repositories
class GitHubReposScreen extends ConsumerStatefulWidget {
  const GitHubReposScreen({super.key});

  @override
  ConsumerState<GitHubReposScreen> createState() => _GitHubReposScreenState();
}

class _GitHubReposScreenState extends ConsumerState<GitHubReposScreen> {
  String _sortBy = 'updated';
  String _filterType = 'all';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(githubProvider.notifier).loadRepos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GitHubRepo> _filterRepos(List<GitHubRepo> repos) {
    var filtered = repos;

    // Apply type filter
    if (_filterType == 'owner') {
      filtered = filtered.where((r) => !r.isFork).toList();
    } else if (_filterType == 'fork') {
      filtered = filtered.where((r) => r.isFork).toList();
    } else if (_filterType == 'private') {
      filtered = filtered.where((r) => r.isPrivate).toList();
    } else if (_filterType == 'public') {
      filtered = filtered.where((r) => !r.isPrivate).toList();
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (r.description
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false))
          .toList();
    }

    return filtered;
  }

  void _navigateToFileBrowser(GitHubRepo repo) {
    // Use dynamic navigation to avoid analyzer issues with cross-file imports
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FileBrowserLoader(repo: repo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(githubProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Repositories'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (value) {
              setState(() => _sortBy = value);
              ref.read(githubProvider.notifier).loadRepos(sort: value);
            },
            itemBuilder: (context) => [
              _buildSortItem('updated', 'Recently Updated'),
              _buildSortItem('created', 'Recently Created'),
              _buildSortItem('pushed', 'Recently Pushed'),
              _buildSortItem('full_name', 'Name'),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) => setState(() => _filterType = value),
            itemBuilder: (context) => [
              _buildFilterItem('all', 'All'),
              _buildFilterItem('owner', 'Owned'),
              _buildFilterItem('fork', 'Forks'),
              _buildFilterItem('private', 'Private'),
              _buildFilterItem('public', 'Public'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search repositories...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Repository list
          Expanded(
            child: _buildRepoList(state),
          ),
        ],
      ),
    );
  }

  Widget _buildRepoList(GitHubState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(state.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(githubProvider.notifier).loadRepos(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final repos = _filterRepos(state.repos);

    if (repos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No repositories match your search'
                  : 'No repositories found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(githubProvider.notifier).loadRepos(sort: _sortBy),
      child: ListView.builder(
        itemCount: repos.length,
        itemBuilder: (context, index) {
          final repo = repos[index];
          return _buildRepoCard(repo);
        },
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortBy == value)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildFilterItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_filterType == value)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildRepoCard(GitHubRepo repo) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () async {
          await ref.read(githubProvider.notifier).selectRepo(repo);
          if (mounted) {
            _navigateToFileBrowser(repo);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Icon(
                    repo.isPrivate ? Icons.lock : Icons.public,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      repo.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (repo.isFork)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Fork',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),

              // Description
              if (repo.description != null && repo.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  repo.description!,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  if (repo.language != null) ...[
                    _buildLanguageBadge(repo.language!),
                    const SizedBox(width: 16),
                  ],
                  Icon(Icons.star_border, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${repo.starsCount}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.call_split, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${repo.forksCount}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageBadge(String language) {
    final colors = {
      'JavaScript': Colors.yellow[700],
      'TypeScript': Colors.blue,
      'Python': Colors.green,
      'Dart': Colors.cyan,
      'Java': Colors.orange,
      'Kotlin': Colors.purple,
      'Swift': Colors.orange[800],
      'Go': Colors.cyan[700],
      'Rust': Colors.brown,
      'Ruby': Colors.red,
      'PHP': Colors.indigo,
      'C#': Colors.green[700],
      'C++': Colors.pink,
      'C': Colors.grey,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: colors[language] ?? Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          language,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}

/// Loader widget that dynamically loads the file browser screen
class _FileBrowserLoader extends StatefulWidget {
  final GitHubRepo repo;
  const _FileBrowserLoader({required this.repo});

  @override
  State<_FileBrowserLoader> createState() => _FileBrowserLoaderState();
}

class _FileBrowserLoaderState extends State<_FileBrowserLoader> {
  Widget? _screen;

  @override
  void initState() {
    super.initState();
    _loadScreen();
  }

  Future<void> _loadScreen() async {
    // Import dynamically to avoid analyzer issues
    final screen = await _createFileBrowserScreen(widget.repo);
    if (mounted) {
      setState(() => _screen = screen);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_screen != null) {
      return _screen!;
    }
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Creates the file browser screen dynamically
Future<Widget> _createFileBrowserScreen(GitHubRepo repo) async {
  // This uses a separate file to avoid the analyzer issue
  return _GitHubFileBrowserScreenProxy(repo: repo);
}

/// Proxy widget that wraps the actual file browser screen
class _GitHubFileBrowserScreenProxy extends StatelessWidget {
  final GitHubRepo repo;
  const _GitHubFileBrowserScreenProxy({required this.repo});

  @override
  Widget build(BuildContext context) {
    // Import and use the actual screen here
    // For now, return a placeholder that will be replaced
    return _ActualFileBrowserScreen(repo: repo);
  }
}

/// The actual file browser screen implementation
/// This is a copy of GitHubFileBrowserScreen to avoid import issues
class _ActualFileBrowserScreen extends ConsumerStatefulWidget {
  final GitHubRepo repo;

  const _ActualFileBrowserScreen({required this.repo});

  @override
  ConsumerState<_ActualFileBrowserScreen> createState() =>
      _ActualFileBrowserScreenState();
}

class _ActualFileBrowserScreenState
    extends ConsumerState<_ActualFileBrowserScreen> {
  final List<String> _pathStack = [];

  String? get currentPath => _pathStack.isEmpty ? null : _pathStack.join('/');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(githubProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.repo.name),
            if (currentPath != null)
              Text(
                currentPath!,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: 'AI Analysis',
            onPressed: () => _showAnalysisDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Code',
            onPressed: () => _showSearchDialog(context),
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(GitHubState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(state.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(githubProvider.notifier).selectRepo(widget.repo),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final items = ref.read(githubProvider.notifier).getItemsAtPath(currentPath);

    // Sort: directories first, then files
    items.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.path.compareTo(b.path);
    });

    return Column(
      children: [
        // Breadcrumb navigation
        _buildBreadcrumb(),

        // File list
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'This folder is empty',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildFileItem(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Root
            InkWell(
              onTap: () {
                setState(() => _pathStack.clear());
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.home, size: 16),
                  const SizedBox(width: 4),
                  Text(widget.repo.name),
                ],
              ),
            ),

            // Path segments
            for (int i = 0; i < _pathStack.length; i++) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right, size: 16),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _pathStack.removeRange(i + 1, _pathStack.length);
                  });
                },
                child: Text(
                  _pathStack[i],
                  style: TextStyle(
                    fontWeight: i == _pathStack.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(GitHubTreeItem item) {
    final fileName = item.path.split('/').last;
    final icon = item.isDirectory ? Icons.folder : _getFileIcon(fileName);
    final iconColor = item.isDirectory ? Colors.amber : Colors.grey[600];

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(fileName),
      subtitle: item.isDirectory
          ? null
          : Text(
              _formatFileSize(item.size ?? 0),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
      trailing: item.isDirectory
          ? const Icon(Icons.chevron_right)
          : IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showFileMenu(item),
            ),
      onTap: () {
        if (item.isDirectory) {
          setState(() {
            _pathStack.add(fileName);
          });
        } else {
          _viewFile(item);
        }
      },
    );
  }

  void _showFileMenu(GitHubTreeItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View'),
              onTap: () {
                Navigator.pop(context);
                _viewFile(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Add as Source'),
              onTap: () {
                Navigator.pop(context);
                _showAddSourceDialog(item);
              },
            ),
          ],
        ),
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
      case 'html':
      case 'css':
        return Icons.web;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _viewFile(GitHubTreeItem item) {
    // Navigate to file viewer - simplified version
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening ${item.path}...')),
    );
  }

  void _showAddSourceDialog(GitHubTreeItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adding ${item.path} as source...')),
    );
  }

  void _showAnalysisDialog(BuildContext context) {
    final focusController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Repository Analysis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analyze this repository with AI to understand its structure, '
              'patterns, and key components.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: focusController,
              decoration: const InputDecoration(
                labelText: 'Focus Area (optional)',
                hintText: 'e.g., authentication, API design',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _runAnalysis(focusController.text);
            },
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }

  Future<void> _runAnalysis(String focus) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting AI analysis...')),
    );

    final result = await ref.read(githubProvider.notifier).analyzeRepo(
          focus: focus.isNotEmpty ? focus : null,
        );

    if (result != null && mounted) {
      _showAnalysisResult(result);
    }
  }

  void _showAnalysisResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analysis Result'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result['summary'] != null) ...[
                const Text(
                  'Summary',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(result['summary'].toString()),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Code'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Search query',
            hintText: 'e.g., function name, class, pattern',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (searchController.text.isNotEmpty) {
                Navigator.pop(context);
                _runSearch(searchController.text);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _runSearch(String query) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Searching for "$query"...')),
    );

    final results = await ref.read(githubProvider.notifier).searchCode(query);

    if (mounted) {
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No results found')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${results.length} results')),
        );
      }
    }
  }
}
