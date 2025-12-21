import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/search/search_provider.dart';
import '../../core/search/serper_service.dart';
import '../../features/sources/source_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/ai/deep_research_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'youtube_player_dialog.dart';
import '../subscription/services/credit_manager.dart';

class WebSearchScreen extends ConsumerStatefulWidget {
  const WebSearchScreen({super.key});

  @override
  ConsumerState<WebSearchScreen> createState() => _WebSearchScreenState();
}

class _WebSearchScreenState extends ConsumerState<WebSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isDeepResearch = false;
  final bool _useContextEngineering = false;
  bool _isResearching = false;
  List<DeepResearchUpdate> _researchUpdates = [];
  DeepResearchUpdate? _finalResult;
  SearchType _searchType = SearchType.web;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    if (_isDeepResearch) {
      _performDeepResearch(query);
    } else {
      // Check and consume credits for web search
      final hasCredits = await ref.tryUseCredits(
        context: context,
        amount: CreditCosts.webSearch,
        feature: 'web_search',
      );
      if (!hasCredits) return;

      ref.read(searchProvider.notifier).search(query, type: _searchType);
    }
  }

  Future<void> _performDeepResearch(String query) async {
    // Check and consume credits for deep research
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.deepResearch,
      feature: 'deep_research',
    );
    if (!hasCredits) return;

    setState(() {
      _isResearching = true;
      _researchUpdates = [];
      _finalResult = null;
    });

    ref
        .read(deepResearchServiceProvider)
        .research(query,
            notebookId: '', useContextEngineering: _useContextEngineering)
        .listen(
      (update) {
        if (!mounted) return;
        setState(() {
          _researchUpdates.add(update);
          if (update.progress >= 1.0) {
            _finalResult = update;
            _isResearching = false;
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _isResearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Research failed: $e')),
        );
      },
    );
  }

  void _addAsSource(SerperSearchResult result) async {
    try {
      // Fetch the page content
      final content =
          await ref.read(searchProvider.notifier).fetchPageContent(result.link);

      // Add as a source
      await ref.read(sourceProvider.notifier).addSource(
        title: result.title,
        type: 'web',
        content: '''Title: ${result.title}
URL: ${result.link}

Summary:
${result.snippet}

Content:
$content''',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${result.title}" as source'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => context.go('/sources'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding source: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Search'),
        actions: [
          Consumer(builder: (context, ref, _) {
            final mode = ref.watch(themeModeProvider);
            return IconButton(
              icon: Icon(
                  mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
              tooltip: mode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
              onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            );
          }),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search,
                    color: scheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: 'Search the web for sources...',
                      hintStyle: text.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                    ),
                    style: text.bodyMedium,
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear,
                        color: scheme.onSurface.withValues(alpha: 0.6)),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchProvider.notifier).clearResults();
                    },
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ).animate().slideY(begin: 0.2).fadeIn(),

          // Search filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Web Search'),
                  selected: !_isDeepResearch,
                  onSelected: (v) => setState(() => _isDeepResearch = !v),
                  backgroundColor: scheme.surface,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Deep Research'),
                  selected: _isDeepResearch,
                  onSelected: (v) => setState(() => _isDeepResearch = v),
                  backgroundColor: scheme.surface,
                ),
              ],
            ),
          ).animate().slideY(begin: 0.2, delay: 100.ms).fadeIn(),

          // Search type selector (when not in deep research mode)
          if (!_isDeepResearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, size: 16),
                          SizedBox(width: 4),
                          Text('Web'),
                        ],
                      ),
                      selected: _searchType == SearchType.web,
                      onSelected: (v) {
                        if (v) setState(() => _searchType = SearchType.web);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image, size: 16),
                          SizedBox(width: 4),
                          Text('Images'),
                        ],
                      ),
                      selected: _searchType == SearchType.images,
                      onSelected: (v) {
                        if (v) setState(() => _searchType = SearchType.images);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.newspaper, size: 16),
                          SizedBox(width: 4),
                          Text('News'),
                        ],
                      ),
                      selected: _searchType == SearchType.news,
                      onSelected: (v) {
                        if (v) setState(() => _searchType = SearchType.news);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.video_library, size: 16),
                          SizedBox(width: 4),
                          Text('Videos'),
                        ],
                      ),
                      selected: _searchType == SearchType.videos,
                      onSelected: (v) {
                        if (v) setState(() => _searchType = SearchType.videos);
                      },
                    ),
                  ],
                ),
              ),
            ).animate().slideY(begin: 0.2, delay: 150.ms).fadeIn(),

          const SizedBox(height: 16),

          if (searchState.verification != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verification: like=${searchState.verification['details']?['like']}, share=${searchState.verification['details']?['share']}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Search status
          if (_isDeepResearch)
            _buildDeepResearchUI(scheme, text)
          else if (searchState.status == SearchStatus.loading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Searching the web...'),
                  ],
                ),
              ),
            )
          else if (searchState.status == SearchStatus.error)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: scheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Search failed',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      searchState.error ?? 'Unknown error occurred',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _performSearch,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          else if (searchState.status == SearchStatus.success &&
              searchState.results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: scheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No results found',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try different keywords or check your internet connection',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else if (searchState.results.isNotEmpty)
            Expanded(
              child: _searchType == SearchType.images
                  ? GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: searchState.results.length,
                      itemBuilder: (context, index) {
                        final result = searchState.results[index];
                        return _ImageResultCard(
                          result: result,
                          onAddSource: () => _addAsSource(result),
                          onTap: () => _showImagePreview(context, result),
                        )
                            .animate()
                            .scale(
                              begin: const Offset(0.8, 0.8),
                              delay: Duration(milliseconds: index * 50),
                            )
                            .fadeIn();
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: searchState.results.length,
                      itemBuilder: (context, index) {
                        final result = searchState.results[index];
                        return _SearchResultCard(
                          result: result,
                          onAddSource: () => _addAsSource(result),
                          onShare: () => Share.share(result.link),
                          onVerify: () => ref
                              .read(searchProvider.notifier)
                              .verifyYouTube(result.link),
                        )
                            .animate()
                            .slideX(
                              begin: 0.2,
                              delay: Duration(milliseconds: index * 50),
                            )
                            .fadeIn();
                      },
                    ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.travel_explore,
                      size: 64,
                      color: scheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Search the Web',
                      style: text.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Find and add web sources to your notebook',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => _searchFocus.requestFocus(),
                      icon: const Icon(Icons.search),
                      label: const Text('Start Searching'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: searchState.status == SearchStatus.success &&
              searchState.results.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showAddAllDialog(context, searchState.results),
              icon: const Icon(Icons.add_circle_outline),
              label: Text('Add All (${searchState.results.length})'),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            )
          : null,
    );
  }

  void _showHelpDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Web Search Help'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to use web search:',
              style: text.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildHelpItem(
              icon: Icons.search,
              title: 'Search Tips',
              description:
                  'Use specific keywords and phrases for better results',
              scheme: scheme,
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              icon: Icons.add_circle_outline,
              title: 'Add Sources',
              description: 'Tap the + button to add search results as sources',
              scheme: scheme,
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              icon: Icons.filter_list,
              title: 'Filters',
              description: 'Use filters to narrow down results (coming soon)',
              scheme: scheme,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
    required ColorScheme scheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddAllDialog(
      BuildContext context, List<SerperSearchResult> results) {
    final text = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add All Sources?'),
        content: Text(
          'This will add ${results.length} web sources to your notebook. '
          'You can always remove them later.',
          style: text.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addAllSources(results);
            },
            child: const Text('Add All'),
          ),
        ],
      ),
    );
  }

  void _addAllSources(List<SerperSearchResult> results) async {
    int addedCount = 0;

    for (final result in results) {
      try {
        final content = await ref
            .read(searchProvider.notifier)
            .fetchPageContent(result.link);
        await ref.read(sourceProvider.notifier).addSource(
          title: result.title,
          type: 'web',
          content: '''Title: ${result.title}
URL: ${result.link}

Summary:
${result.snippet}

Content:
$content''',
        );
        addedCount++;
      } catch (e) {
        // Continue with other sources if one fails
        continue;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $addedCount of ${results.length} sources'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => context.go('/sources'),
          ),
        ),
      );
    }
  }

  Widget _buildDeepResearchUI(ColorScheme scheme, TextTheme text) {
    if (_researchUpdates.isEmpty && !_isResearching) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 64, color: scheme.primary),
              const SizedBox(height: 16),
              Text('Deep Research Agent', style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'I can browse the web, read pages, and\nwrite a comprehensive report for you.',
                textAlign: TextAlign.center,
                style: text.bodyMedium
                    ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_finalResult != null) ...[
            Card(
              color: scheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MarkdownBody(
                  data: _finalResult!.result!,
                  sizedImageBuilder: (config) {
                    if (config.alt == 'VIDEO') {
                      return _buildVideoCard(config.uri.toString());
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        config.uri.toString(),
                        width: config.width,
                        height: config.height,
                        errorBuilder: (c, e, s) => const SizedBox.shrink(),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _addReportAsSource(_finalResult!),
              icon: const Icon(Icons.add),
              label: const Text('Add Report to Notebook'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            if (_researchUpdates.isNotEmpty &&
                _researchUpdates.last.images != null &&
                _researchUpdates.last.images!.isNotEmpty) ...[
              Text('Visual Findings', style: text.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _researchUpdates.last.images!.length,
                  itemBuilder: (context, index) {
                    final imageUrl = _researchUpdates.last.images![index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 100,
                            height: 100,
                            color: scheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_researchUpdates.isNotEmpty &&
                _researchUpdates.last.videos != null &&
                _researchUpdates.last.videos!.isNotEmpty) ...[
              Text('Video Findings', style: text.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _researchUpdates.last.videos!.length,
                  itemBuilder: (context, index) {
                    final videoUrl = _researchUpdates.last.videos![index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 160,
                        child: _buildVideoCard(videoUrl, isPreview: true),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Research Log', style: text.titleSmall),
            const SizedBox(height: 8),
          ],
          ..._researchUpdates.map((update) {
            final isLast = update == _researchUpdates.last;
            return ListTile(
              leading: isLast && _isResearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.check_circle, size: 20, color: scheme.primary),
              title: Text(update.status, style: text.bodyMedium),
              dense: true,
            );
          }),
        ],
      ),
    );
  }

  void _addReportAsSource(DeepResearchUpdate result) async {
    await ref.read(sourceProvider.notifier).addSource(
          title: 'Research: ${_searchController.text}',
          type: 'report',
          content: result.result!,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report added to notebook')),
      );
      context.go('/sources');
    }
  }

  void _showImagePreview(BuildContext context, SerperSearchResult result) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Image
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: result.imageUrl != null
                    ? Image.network(
                        result.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(32),
                            color: Colors.grey[900],
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image,
                                    size: 64, color: Colors.white54),
                                SizedBox(height: 16),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            padding: const EdgeInsets.all(32),
                            color: Colors.grey[900],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        padding: const EdgeInsets.all(32),
                        color: Colors.grey[900],
                        child: const Icon(Icons.image_not_supported,
                            size: 64, color: Colors.white54),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // Image info card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.link,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _addAsSource(result);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add to Sources'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Share.share(result.link),
                        icon: const Icon(Icons.share),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(String url, {bool isPreview = false}) {
    final videoId = _extractVideoId(url);
    final thumbnailUrl =
        videoId != null ? 'https://img.youtube.com/vi/$videoId/0.jpg' : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (videoId != null) {
            _showVideoPlayer(context, videoId);
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (thumbnailUrl != null)
              Image.network(
                thumbnailUrl,
                width: isPreview ? null : double.infinity,
                height: isPreview ? 120 : 200,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  height: isPreview ? 120 : 200,
                  width: isPreview ? 160 : double.infinity,
                  color: Colors.black12,
                  child: const Center(child: Icon(Icons.video_library)),
                ),
              )
            else
              Container(
                height: isPreview ? 120 : 200,
                width: isPreview ? 160 : double.infinity,
                color: Colors.black12,
                child: const Center(child: Icon(Icons.video_library)),
              ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.play_arrow, color: Colors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoPlayer(BuildContext context, String videoId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: YouTubePlayerDialog(videoId: videoId),
      ),
    );
  }

  String? _extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    }
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return null;
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.onAddSource,
    required this.onShare,
    required this.onVerify,
  });

  final SerperSearchResult result;
  final VoidCallback onAddSource;
  final VoidCallback onShare;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showResultDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.title,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const SizedBox(height: 4),
                        Text(
                          result.link,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.public,
                      color: scheme.primary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                result.snippet,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAddSource,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Source'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(width: 8),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onShare,
                    icon: Icon(
                      Icons.share,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultDetails(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.title,
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              result.link,
              style: text.bodyMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Summary',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result.snippet,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onAddSource();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add as Source'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onShare();
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Image Result Card for grid display
class _ImageResultCard extends StatelessWidget {
  const _ImageResultCard({
    required this.result,
    required this.onAddSource,
    required this.onTap,
  });

  final SerperSearchResult result;
  final VoidCallback onAddSource;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image thumbnail
            Expanded(
              child: Container(
                width: double.infinity,
                color: scheme.surfaceContainerHighest,
                child: result.imageUrl != null
                    ? Image.network(
                        result.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: scheme.surfaceContainerHighest,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Image unavailable',
                                  style: text.bodySmall?.copyWith(
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: scheme.surfaceContainerHighest,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: scheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No preview',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            // Title and add button
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onAddSource,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
