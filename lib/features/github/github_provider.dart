import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/github/github_service.dart';
import '../../core/api/api_service.dart';
import 'github_source_provider.dart';

/// State class for GitHub integration
class GitHubState {
  final GitHubConnection? connection;
  final List<GitHubRepo> repos;
  final List<GitHubTreeItem> currentTree;
  final GitHubRepo? selectedRepo;
  final String? currentPath;
  final bool isLoading;
  final String? error;

  const GitHubState({
    this.connection,
    this.repos = const [],
    this.currentTree = const [],
    this.selectedRepo,
    this.currentPath,
    this.isLoading = false,
    this.error,
  });

  bool get isConnected => connection?.connected ?? false;

  GitHubState copyWith({
    GitHubConnection? connection,
    List<GitHubRepo>? repos,
    List<GitHubTreeItem>? currentTree,
    GitHubRepo? selectedRepo,
    String? currentPath,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSelectedRepo = false,
    bool clearCurrentPath = false,
  }) {
    return GitHubState(
      connection: connection ?? this.connection,
      repos: repos ?? this.repos,
      currentTree: currentTree ?? this.currentTree,
      selectedRepo:
          clearSelectedRepo ? null : (selectedRepo ?? this.selectedRepo),
      currentPath: clearCurrentPath ? null : (currentPath ?? this.currentPath),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for GitHub state management
class GitHubNotifier extends StateNotifier<GitHubState> {
  final GitHubService _githubService;
  final Ref _ref;

  GitHubNotifier(this._githubService, this._ref) : super(const GitHubState());

  /// Check GitHub connection status
  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final connection = await _githubService.getStatus();
      state = state.copyWith(connection: connection, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        connection: GitHubConnection(connected: false),
        isLoading: false,
      );
    }
  }

  /// Connect with Personal Access Token
  Future<bool> connectWithToken(String token) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final connection = await _githubService.connectWithToken(token);
      state = state.copyWith(connection: connection, isLoading: false);
      await loadRepos();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  /// Disconnect GitHub
  /// Also invalidates all GitHub source caches (Requirements: 1.3, 1.4)
  Future<void> disconnect() async {
    state = state.copyWith(isLoading: true);

    try {
      await _githubService.disconnect();

      // Invalidate all GitHub source caches
      _ref.read(githubSourceProvider.notifier).onGitHubDisconnected();

      state = state.copyWith(
        connection: GitHubConnection(connected: false),
        repos: [],
        currentTree: [],
        isLoading: false,
        clearSelectedRepo: true,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Load repositories
  Future<void> loadRepos({
    String type = 'all',
    String sort = 'updated',
  }) async {
    if (!state.isConnected) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repos = await _githubService.listRepos(type: type, sort: sort);
      state = state.copyWith(repos: repos, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Select a repository and load its tree
  Future<void> selectRepo(GitHubRepo repo) async {
    state = state.copyWith(
      selectedRepo: repo,
      isLoading: true,
      clearError: true,
      clearCurrentPath: true,
    );

    try {
      final tree = await _githubService.getRepoTree(repo.owner, repo.name);
      state = state.copyWith(currentTree: tree, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        currentTree: [],
        isLoading: false,
      );
    }
  }

  /// Get file content
  Future<GitHubFile?> getFileContent(String path,
      {String? owner, String? repo}) async {
    final repoOwner = owner ?? state.selectedRepo?.owner;
    final repoName = repo ?? state.selectedRepo?.name;

    if (repoOwner == null || repoName == null) {
      state = state.copyWith(error: 'Repository information not available');
      return null;
    }

    state = state.copyWith(clearError: true);

    try {
      final file = await _githubService.getFileContent(
        repoOwner,
        repoName,
        path,
      );
      return file;
    } catch (e) {
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(error: errorMessage);
      return null;
    }
  }

  /// Validate that a file exists in the repository
  Future<bool> validateFileExists(
      String owner, String repo, String path) async {
    try {
      await _githubService.getFileContent(owner, repo, path);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get README
  Future<String?> getReadme() async {
    if (state.selectedRepo == null) return null;

    try {
      return await _githubService.getReadme(
        state.selectedRepo!.owner,
        state.selectedRepo!.name,
      );
    } catch (e) {
      return null;
    }
  }

  /// Search code
  Future<List<Map<String, dynamic>>> searchCode(String query) async {
    try {
      return await _githubService.searchCode(
        query,
        repo: state.selectedRepo != null
            ? '${state.selectedRepo!.owner}/${state.selectedRepo!.name}'
            : null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  /// Add file as source to notebook
  Future<bool> addAsSource({
    required String notebookId,
    required String path,
  }) async {
    if (state.selectedRepo == null) return false;

    try {
      await _githubService.addAsSource(
        notebookId: notebookId,
        owner: state.selectedRepo!.owner,
        repo: state.selectedRepo!.name,
        path: path,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Analyze repository with AI
  Future<Map<String, dynamic>?> analyzeRepo({
    String? focus,
    List<String>? includeFiles,
  }) async {
    if (state.selectedRepo == null) return null;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _githubService.analyzeRepo(
        state.selectedRepo!.owner,
        state.selectedRepo!.name,
        focus: focus,
        includeFiles: includeFiles,
      );
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Get items at a specific path level
  List<GitHubTreeItem> getItemsAtPath(String? path) {
    if (path == null || path.isEmpty) {
      return state.currentTree
          .where((item) => !item.path.contains('/'))
          .toList();
    }

    final prefix = '$path/';
    return state.currentTree.where((item) {
      if (!item.path.startsWith(prefix)) return false;
      final remaining = item.path.substring(prefix.length);
      return !remaining.contains('/');
    }).toList();
  }

  /// Navigate to path
  void navigateToPath(String? path) {
    state = state.copyWith(currentPath: path, clearCurrentPath: path == null);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for GitHub state
final githubProvider =
    StateNotifierProvider<GitHubNotifier, GitHubState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return GitHubNotifier(GitHubService(apiService), ref);
});
