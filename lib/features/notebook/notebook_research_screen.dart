import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/ai/deep_research_service.dart';
import '../sources/source_provider.dart';
import '../subscription/services/credit_manager.dart';

class NotebookResearchScreen extends ConsumerStatefulWidget {
  final String notebookId;

  const NotebookResearchScreen({super.key, required this.notebookId});

  @override
  ConsumerState<NotebookResearchScreen> createState() =>
      _NotebookResearchScreenState();
}

class _NotebookResearchScreenState
    extends ConsumerState<NotebookResearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isResearching = false;
  List<ResearchUpdate> _researchUpdates = [];
  ResearchUpdate? _finalResult;

  ResearchDepth _selectedDepth = ResearchDepth.standard;
  ResearchTemplate _selectedTemplate = ResearchTemplate.general;

  final List<String> _searchedSites = [];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String? _extractDomain(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return null;
    }
  }

  String _getFaviconUrl(String domain) {
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
  }

  Future<void> _performResearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final creditAmount = _selectedDepth == ResearchDepth.deep
        ? CreditCosts.deepResearch * 2
        : CreditCosts.deepResearch;

    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: creditAmount,
      feature: 'deep_research',
    );
    if (!hasCredits) return;

    setState(() {
      _isResearching = true;
      _researchUpdates = [];
      _finalResult = null;
      _searchedSites.clear();
    });

    ref
        .read(deepResearchServiceProvider)
        .research(
          query: query,
          notebookId: widget.notebookId, // Save to THIS notebook
          depth: _selectedDepth,
          template: _selectedTemplate,
        )
        .listen(
      (update) {
        if (!mounted) return;
        setState(() {
          _researchUpdates.add(update);

          if (update.sources != null) {
            for (final source in update.sources!) {
              final domain = _extractDomain(source.url);
              if (domain != null && !_searchedSites.contains(domain)) {
                _searchedSites.add(domain);
              }
            }
          }

          if (update.result != null) {
            _finalResult = update;
          }

          if (update.isComplete) {
            _finalResult = update;
            _isResearching = false;
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _isResearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Research failed: $e')),
        );
      },
    );
  }

  Future<void> _saveReportAsSource() async {
    if (_finalResult?.result == null) return;

    try {
      await ref.read(sourceProvider.notifier).addSource(
            title: 'Research: ${_searchController.text}',
            type: 'research',
            content: _finalResult!.result!,
            notebookId: widget.notebookId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Research saved to notebook!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Research'),
        actions: [
          if (_finalResult?.result != null)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save to Notebook',
              onPressed: _saveReportAsSource,
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
                Icon(Icons.auto_awesome,
                    color: scheme.primary.withValues(alpha: 0.8)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: 'What do you want to research?',
                      hintStyle: text.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                    ),
                    style: text.bodyMedium,
                    onSubmitted: (_) => _performResearch(),
                    enabled: !_isResearching,
                  ),
                ),
                if (_searchController.text.isNotEmpty && !_isResearching)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear(),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ).animate().slideY(begin: 0.2).fadeIn(),

          // Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Depth selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text('Depth: ', style: text.labelMedium),
                      const SizedBox(width: 8),
                      ...ResearchDepth.values.map((depth) {
                        final label = depth == ResearchDepth.quick
                            ? 'Quick'
                            : depth == ResearchDepth.standard
                                ? 'Standard'
                                : 'Deep';
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label,
                                style: const TextStyle(fontSize: 12)),
                            selected: _selectedDepth == depth,
                            onSelected: _isResearching
                                ? null
                                : (selected) {
                                    if (selected) {
                                      setState(() => _selectedDepth = depth);
                                    }
                                  },
                            selectedColor: scheme.primaryContainer,
                            showCheckmark: false,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Template selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text('Template: ', style: text.labelMedium),
                      const SizedBox(width: 8),
                      ...ResearchTemplate.values.map((template) {
                        final label = switch (template) {
                          ResearchTemplate.general => 'General',
                          ResearchTemplate.academic => 'Academic',
                          ResearchTemplate.productComparison => 'Compare',
                          ResearchTemplate.marketAnalysis => 'Market',
                          ResearchTemplate.howToGuide => 'How-To',
                          ResearchTemplate.prosAndCons => 'Pros/Cons',
                          ResearchTemplate.shopping => 'Shopping',
                        };
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label,
                                style: const TextStyle(fontSize: 12)),
                            selected: _selectedTemplate == template,
                            onSelected: _isResearching
                                ? null
                                : (selected) {
                                    if (selected) {
                                      setState(
                                          () => _selectedTemplate = template);
                                    }
                                  },
                            selectedColor: scheme.primaryContainer,
                            showCheckmark: false,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: 0.2, delay: 100.ms).fadeIn(),

          const SizedBox(height: 16),

          // Research button
          if (!_isResearching && _finalResult == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _searchController.text.trim().isEmpty
                      ? null
                      : _performResearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Start Research'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 16),

          // Results area
          Expanded(child: _buildResultsArea(scheme, text)),
        ],
      ),
    );
  }

  Widget _buildResultsArea(ColorScheme scheme, TextTheme text) {
    if (_researchUpdates.isEmpty && !_isResearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Deep Research', style: text.headlineSmall),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'AI-powered research that searches the web, analyzes sources, and generates a comprehensive report saved directly to this notebook.',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          if (_isResearching) ...[
            _buildProgressSection(scheme, text),
            const SizedBox(height: 16),
          ],

          // Searched sites
          if (_searchedSites.isNotEmpty) ...[
            Text('Sources Found:', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _searchedSites.map((domain) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundImage: NetworkImage(_getFaviconUrl(domain)),
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                  label: Text(domain, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Final report
          if (_finalResult?.result != null) ...[
            Row(
              children: [
                Icon(Icons.article, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Research Report', style: text.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _saveReportAsSource,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: MarkdownBody(
                data: _finalResult!.result!,
                selectable: true,
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrl(Uri.parse(href),
                        mode: LaunchMode.externalApplication);
                  }
                },
                imageBuilder: (uri, title, alt) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: uri.toString(),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: scheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 100,
                          color: scheme.surfaceContainerHighest,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image, color: scheme.outline),
                                const SizedBox(height: 4),
                                Text(
                                  alt ?? 'Image failed to load',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // Related Videos section
          if (_finalResult?.videos != null &&
              _finalResult!.videos!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.video_library, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Related Videos', style: text.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _finalResult!.videos!.length,
                itemBuilder: (context, index) {
                  final videoUrl = _finalResult!.videos![index];
                  final videoId = _extractYouTubeId(videoUrl);
                  if (videoId == null) return const SizedBox.shrink();

                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < _finalResult!.videos!.length - 1 ? 12 : 0,
                    ),
                    child: _VideoCard(
                      videoId: videoId,
                      onPlay: () => _showVideoPlayer(videoId),
                    ),
                  );
                },
              ),
            ),
          ],

          // Error state
          if (_finalResult?.error != null && _finalResult?.result == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _finalResult!.error!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(ColorScheme scheme, TextTheme text) {
    final latestUpdate =
        _researchUpdates.isNotEmpty ? _researchUpdates.last : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: latestUpdate?.progress,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  latestUpdate?.status ?? 'Starting research...',
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
          if (latestUpdate != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: latestUpdate.progress,
              backgroundColor: scheme.outline.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 4),
            Text(
              '${(latestUpdate.progress * 100).toInt()}% complete',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn();
  }

  String? _extractYouTubeId(String url) {
    // Handle various YouTube URL formats
    final regexes = [
      RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/v/([a-zA-Z0-9_-]{11})'),
    ];

    for (final regex in regexes) {
      final match = regex.firstMatch(url);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  void _showVideoPlayer(String videoId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: _InlineYouTubePlayer(videoId: videoId),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final String videoId;
  final VoidCallback onPlay;

  const _VideoCard({required this.videoId, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

    return GestureDetector(
      onTap: onPlay,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(Icons.video_library,
                      color: scheme.outline, size: 48),
                ),
              ),
              // Play button overlay
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              // Gradient overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.play_circle_outline,
                          color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Tap to play',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineYouTubePlayer extends StatefulWidget {
  final String videoId;

  const _InlineYouTubePlayer({required this.videoId});

  @override
  State<_InlineYouTubePlayer> createState() => _InlineYouTubePlayerState();
}

class _InlineYouTubePlayerState extends State<_InlineYouTubePlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Close button
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        // YouTube Player
        YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.red,
          progressColors: const ProgressBarColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
