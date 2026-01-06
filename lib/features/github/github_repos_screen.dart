import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/github/github_service.dart';
import 'github_provider.dart';
import 'github_file_browser_screen.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GitHubFileBrowserScreen(repo: repo),
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
