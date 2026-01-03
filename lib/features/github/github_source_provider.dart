import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../core/api/api_service.dart';

/// GitHub source metadata model matching backend GitHubSourceMetadata
class GitHubSourceMetadata {
  final String type;
  final String owner;
  final String repo;
  final String path;
  final String branch;
  final String commitSha;
  final String language;
  final int size;
  final String lastFetchedAt;
  final String githubUrl;
  final String? agentSessionId;
  final String? agentName;

  const GitHubSourceMetadata({
    required this.type,
    required this.owner,
    required this.repo,
    required this.path,
    required this.branch,
    required this.commitSha,
    required this.language,
    required this.size,
    required this.lastFetchedAt,
    required this.githubUrl,
    this.agentSessionId,
    this.agentName,
  });

  factory GitHubSourceMetadata.fromJson(Map<String, dynamic> json) {
    return GitHubSourceMetadata(
      type: json['type'] ?? 'github',
      owner: json['owner'] ?? '',
      repo: json['repo'] ?? '',
      path: json['path'] ?? '',
      branch: json['branch'] ?? 'main',
      commitSha: json['commitSha'] ?? '',
      language: json['language'] ?? 'text',
      size: json['size'] ?? 0,
      lastFetchedAt: json['lastFetchedAt'] ?? DateTime.now().toIso8601String(),
      githubUrl: json['githubUrl'] ?? '',
      agentSessionId: json['agentSessionId'],
      agentName: json['agentName'],
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'owner': owner,
        'repo': repo,
        'path': path,
        'branch': branch,
        'commitSha': commitSha,
        'language': language,
        'size': size,
        'lastFetchedAt': lastFetchedAt,
        'githubUrl': githubUrl,
        if (agentSessionId != null) 'agentSessionId': agentSessionId,
        if (agentName != null) 'agentName': agentName,
      };
}

/// GitHub source model
class GitHubSource {
  final String id;
  final String notebookId;
  final String type;
  final String title;
  final String content;
  final GitHubSourceMetadata metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GitHubSource({
    required this.id,
    required this.notebookId,
    required this.type,
    required this.title,
    required this.content,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GitHubSource.fromJson(Map<String, dynamic> json) {
    return GitHubSource(
      id: json['id'] ?? '',
      notebookId: json['notebookId'] ?? json['notebook_id'] ?? '',
      type: json['type'] ?? 'github',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      metadata: GitHubSourceMetadata.fromJson(
        json['metadata'] is Map<String, dynamic>
            ? json['metadata']
            : <String, dynamic>{},
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now()),
    );
  }

  /// Check if the source has updates based on commit SHA comparison
  bool hasUpdates(String newSha) => metadata.commitSha != newSha;

  /// Check if the cache is stale (older than 1 hour)
  bool get isCacheStale {
    final lastFetched = DateTime.tryParse(metadata.lastFetchedAt);
    if (lastFetched == null) return true;
    final age = DateTime.now().difference(lastFetched);
    return age.inHours >= 1;
  }

  GitHubSource copyWith({
    String? id,
    String? notebookId,
    String? type,
    String? title,
    String? content,
    GitHubSourceMetadata? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GitHubSource(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Result of checking for updates
class UpdateCheckResult {
  final bool hasUpdates;
  final String currentSha;
  final String? newSha;

  const UpdateCheckResult({
    required this.hasUpdates,
    required this.currentSha,
    this.newSha,
  });

  factory UpdateCheckResult.fromJson(Map<String, dynamic> json) {
    return UpdateCheckResult(
      hasUpdates: json['hasUpdates'] ?? false,
      currentSha: json['currentSha'] ?? '',
      newSha: json['newSha'],
    );
  }
}

/// State for a single GitHub source
class GitHubSourceState {
  final GitHubSource? source;
  final bool isLoading;
  final bool isRefreshing;
  final bool isCheckingUpdates;
  final String? error;
  final bool hasUpdates;
  final String? newSha;

  const GitHubSourceState({
    this.source,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isCheckingUpdates = false,
    this.error,
    this.hasUpdates = false,
    this.newSha,
  });

  GitHubSourceState copyWith({
    GitHubSource? source,
    bool? isLoading,
    bool? isRefreshing,
    bool? isCheckingUpdates,
    String? error,
    bool? hasUpdates,
    String? newSha,
    bool clearError = false,
    bool clearSource = false,
    bool clearNewSha = false,
  }) {
    return GitHubSourceState(
      source: clearSource ? null : (source ?? this.source),
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isCheckingUpdates: isCheckingUpdates ?? this.isCheckingUpdates,
      error: clearError ? null : (error ?? this.error),
      hasUpdates: hasUpdates ?? this.hasUpdates,
      newSha: clearNewSha ? null : (newSha ?? this.newSha),
    );
  }
}

/// State for managing multiple GitHub sources
class GitHubSourcesState {
  final Map<String, GitHubSourceState> sources;
  final bool isAddingSource;
  final String? addError;

  const GitHubSourcesState({
    this.sources = const {},
    this.isAddingSource = false,
    this.addError,
  });

  GitHubSourcesState copyWith({
    Map<String, GitHubSourceState>? sources,
    bool? isAddingSource,
    String? addError,
    bool clearAddError = false,
  }) {
    return GitHubSourcesState(
      sources: sources ?? this.sources,
      isAddingSource: isAddingSource ?? this.isAddingSource,
      addError: clearAddError ? null : (addError ?? this.addError),
    );
  }

  /// Get state for a specific source
  GitHubSourceState? getSourceState(String sourceId) => sources[sourceId];

  /// Check if any source is loading
  bool get hasLoadingSources =>
      sources.values.any((s) => s.isLoading || s.isRefreshing);
}

/// Notifier for GitHub source state management
/// Requirements: 1.1, 1.3, 1.4
class GitHubSourceNotifier extends StateNotifier<GitHubSourcesState> {
  final ApiService _api;

  GitHubSourceNotifier(this._api) : super(const GitHubSourcesState());

  /// Add a GitHub file as a source to a notebook
  /// Requirements: 1.1 - Create GitHub_Source in selected notebook
  /// Requirements: 1.2 - Store repository owner, repo name, file path, branch, and commit SHA
  Future<GitHubSource?> addGitHubSource({
    required String notebookId,
    required String owner,
    required String repo,
    required String path,
    String? branch,
  }) async {
    state = state.copyWith(isAddingSource: true, clearAddError: true);

    try {
      debugPrint(
          '[GitHubSource] Adding source: $owner/$repo/$path to notebook $notebookId');

      final response = await _api.post('/github/add-source', {
        'notebookId': notebookId,
        'owner': owner,
        'repo': repo,
        'path': path,
        if (branch != null) 'branch': branch,
      });

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to add GitHub source');
      }

      final sourceData = response['source'] as Map<String, dynamic>;
      final source = GitHubSource.fromJson(sourceData);

      // Add to state
      final newSources = Map<String, GitHubSourceState>.from(state.sources);
      newSources[source.id] = GitHubSourceState(source: source);

      state = state.copyWith(
        sources: newSources,
        isAddingSource: false,
      );

      debugPrint('[GitHubSource] Successfully added source: ${source.id}');
      return source;
    } catch (e) {
      debugPrint('[GitHubSource] Error adding source: $e');
      state = state.copyWith(
        isAddingSource: false,
        addError: e.toString(),
      );
      return null;
    }
  }

  /// Refresh a GitHub source with latest content from GitHub
  /// Requirements: 1.3 - Fetch latest content if cached version is older than 1 hour
  Future<GitHubSource?> refreshSource(String sourceId) async {
    // Update state to show refreshing
    _updateSourceState(
        sourceId, (s) => s.copyWith(isRefreshing: true, clearError: true));

    try {
      debugPrint('[GitHubSource] Refreshing source: $sourceId');

      final response = await _api.post('/github/sources/$sourceId/refresh', {});

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to refresh source');
      }

      final sourceData = response['source'] as Map<String, dynamic>;
      final source = GitHubSource.fromJson(sourceData);
      final hasUpdates = response['hasUpdates'] as bool? ?? false;

      // Update state with refreshed source
      _updateSourceState(
        sourceId,
        (s) => s.copyWith(
          source: source,
          isRefreshing: false,
          hasUpdates: hasUpdates,
          clearNewSha: true,
        ),
      );

      debugPrint('[GitHubSource] Successfully refreshed source: $sourceId');
      return source;
    } catch (e) {
      debugPrint('[GitHubSource] Error refreshing source: $e');
      _updateSourceState(
        sourceId,
        (s) => s.copyWith(
          isRefreshing: false,
          error: e.toString(),
        ),
      );
      return null;
    }
  }

  /// Check if a GitHub source has updates (commit SHA differs)
  /// Requirements: 1.4 - Display "File Updated" indicator if file has been modified
  Future<UpdateCheckResult?> checkForUpdates(String sourceId) async {
    // Update state to show checking
    _updateSourceState(
        sourceId, (s) => s.copyWith(isCheckingUpdates: true, clearError: true));

    try {
      debugPrint('[GitHubSource] Checking for updates: $sourceId');

      final response =
          await _api.get('/github/sources/$sourceId/check-updates');

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to check for updates');
      }

      final result = UpdateCheckResult.fromJson(response);

      // Update state with check result
      _updateSourceState(
        sourceId,
        (s) => s.copyWith(
          isCheckingUpdates: false,
          hasUpdates: result.hasUpdates,
          newSha: result.newSha,
        ),
      );

      debugPrint(
          '[GitHubSource] Update check complete: hasUpdates=${result.hasUpdates}');
      return result;
    } catch (e) {
      debugPrint('[GitHubSource] Error checking for updates: $e');
      _updateSourceState(
        sourceId,
        (s) => s.copyWith(
          isCheckingUpdates: false,
          error: e.toString(),
        ),
      );
      return null;
    }
  }

  /// Load a GitHub source by ID
  Future<GitHubSource?> loadSource(String sourceId) async {
    _updateSourceState(
        sourceId, (s) => s.copyWith(isLoading: true, clearError: true));

    try {
      debugPrint('[GitHubSource] Loading source: $sourceId');

      final response = await _api.get('/sources/$sourceId');

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load source');
      }

      final sourceData = response['source'] as Map<String, dynamic>;

      // Check if this is a GitHub source
      if (sourceData['type'] != 'github') {
        throw Exception('Source is not a GitHub source');
      }

      final source = GitHubSource.fromJson(sourceData);

      _updateSourceState(
        sourceId,
        (s) => s.copyWith(
          source: source,
          isLoading: false,
        ),
      );

      debugPrint('[GitHubSource] Successfully loaded source: $sourceId');
      return source;
    } catch (e) {
      debugPrint('[GitHubSource] Error loading source: $e');
      _updateSourceState(
        sourceId,
        (s) => s.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
      return null;
    }
  }

  /// Get source with content, refreshing if cache is stale
  /// Requirements: 1.3 - Fetch latest content if cached version is older than 1 hour
  Future<GitHubSource?> getSourceWithContent(String sourceId) async {
    final currentState = state.sources[sourceId];
    final currentSource = currentState?.source;

    // If we have a cached source and it's fresh, return it
    if (currentSource != null && !currentSource.isCacheStale) {
      debugPrint('[GitHubSource] Returning cached source: $sourceId');
      return currentSource;
    }

    // Otherwise, refresh from GitHub
    return refreshSource(sourceId);
  }

  /// Clear the update indicator for a source
  void clearUpdateIndicator(String sourceId) {
    _updateSourceState(
      sourceId,
      (s) => s.copyWith(hasUpdates: false, clearNewSha: true),
    );
  }

  /// Clear error for a source
  void clearError(String sourceId) {
    _updateSourceState(sourceId, (s) => s.copyWith(clearError: true));
  }

  /// Clear the add error
  void clearAddError() {
    state = state.copyWith(clearAddError: true);
  }

  /// Remove a source from state (after deletion)
  void removeSource(String sourceId) {
    final newSources = Map<String, GitHubSourceState>.from(state.sources);
    newSources.remove(sourceId);
    state = state.copyWith(sources: newSources);
  }

  /// Invalidate cache for all sources (e.g., after GitHub disconnect)
  void invalidateAllCaches() {
    final newSources = <String, GitHubSourceState>{};
    for (final entry in state.sources.entries) {
      newSources[entry.key] = entry.value.copyWith(
        hasUpdates: true,
        clearSource: true,
      );
    }
    state = state.copyWith(sources: newSources);
  }

  /// Helper to update state for a specific source
  void _updateSourceState(
    String sourceId,
    GitHubSourceState Function(GitHubSourceState) updater,
  ) {
    final currentState = state.sources[sourceId] ?? const GitHubSourceState();
    final newSources = Map<String, GitHubSourceState>.from(state.sources);
    newSources[sourceId] = updater(currentState);
    state = state.copyWith(sources: newSources);
  }
}

/// Provider for GitHub source state management
final githubSourceProvider =
    StateNotifierProvider<GitHubSourceNotifier, GitHubSourcesState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return GitHubSourceNotifier(apiService);
});

/// Provider to get a specific source's state
final githubSourceStateProvider =
    Provider.family<GitHubSourceState?, String>((ref, sourceId) {
  final state = ref.watch(githubSourceProvider);
  return state.getSourceState(sourceId);
});

/// Provider to check if a source has updates
final githubSourceHasUpdatesProvider =
    Provider.family<bool, String>((ref, sourceId) {
  final state = ref.watch(githubSourceStateProvider(sourceId));
  return state?.hasUpdates ?? false;
});

/// Provider to check if a source is loading
final githubSourceIsLoadingProvider =
    Provider.family<bool, String>((ref, sourceId) {
  final state = ref.watch(githubSourceStateProvider(sourceId));
  return state?.isLoading ?? false;
});

/// Provider to check if a source is refreshing
final githubSourceIsRefreshingProvider =
    Provider.family<bool, String>((ref, sourceId) {
  final state = ref.watch(githubSourceStateProvider(sourceId));
  return state?.isRefreshing ?? false;
});

/// Provider to get the error for a source
final githubSourceErrorProvider =
    Provider.family<String?, String>((ref, sourceId) {
  final state = ref.watch(githubSourceStateProvider(sourceId));
  return state?.error;
});

/// Provider to check if adding a source is in progress
final githubSourceIsAddingProvider = Provider<bool>((ref) {
  final state = ref.watch(githubSourceProvider);
  return state.isAddingSource;
});

/// Provider to get the add error
final githubSourceAddErrorProvider = Provider<String?>((ref) {
  final state = ref.watch(githubSourceProvider);
  return state.addError;
});

/// Provider to get all sources with updates
final githubSourcesWithUpdatesProvider = Provider<List<String>>((ref) {
  final state = ref.watch(githubSourceProvider);
  return state.sources.entries
      .where((e) => e.value.hasUpdates)
      .map((e) => e.key)
      .toList();
});

/// Provider to get the count of sources with updates
final githubSourcesUpdateCountProvider = Provider<int>((ref) {
  final sourcesWithUpdates = ref.watch(githubSourcesWithUpdatesProvider);
  return sourcesWithUpdates.length;
});

/// Extension to integrate with the main GitHub provider for cache invalidation
extension GitHubSourceCacheInvalidation on GitHubSourceNotifier {
  /// Called when GitHub is disconnected to invalidate all cached sources
  /// Requirements: 1.3, 1.4 - Handle cache invalidation
  void onGitHubDisconnected() {
    debugPrint('[GitHubSource] GitHub disconnected, invalidating all caches');
    invalidateAllCaches();
  }
}

/// Helper function to check if a source is a GitHub source
bool isGitHubSource(Map<String, dynamic> sourceData) {
  return sourceData['type'] == 'github' ||
      (sourceData['metadata'] is Map &&
          sourceData['metadata']['type'] == 'github');
}

/// Helper function to extract GitHub metadata from a source
GitHubSourceMetadata? extractGitHubMetadata(Map<String, dynamic> sourceData) {
  if (!isGitHubSource(sourceData)) return null;

  final metadata = sourceData['metadata'];
  if (metadata is! Map<String, dynamic>) return null;

  return GitHubSourceMetadata.fromJson(metadata);
}
