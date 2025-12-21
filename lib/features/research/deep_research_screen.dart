import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/ai/deep_research_service.dart';
import '../notebook/notebook_provider.dart';
import '../sources/source_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../subscription/services/credit_manager.dart';

class DeepResearchScreen extends ConsumerStatefulWidget {
  const DeepResearchScreen({super.key});

  @override
  ConsumerState<DeepResearchScreen> createState() => _DeepResearchScreenState();
}

class _DeepResearchScreenState extends ConsumerState<DeepResearchScreen> {
  final _queryController = TextEditingController();
  bool _isResearching = false;
  bool _useContextEngineering = false;
  String? _selectedNotebookId;
  String? _result;
  List<ResearchSource>? _sources;
  List<String>? _videos;
  List<String>? _images;
  String _status = '';
  double _progress = 0.0;

  // Streaming state for live site icons
  final List<String> _searchedSites = [];
  String? _currentSearchQuery;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String? _getYouTubeThumbnail(String url) {
    String? videoId;

    // Handle youtube.com/watch?v=VIDEO_ID
    if (url.contains('youtube.com/watch')) {
      final uri = Uri.tryParse(url);
      videoId = uri?.queryParameters['v'];
    }
    // Handle youtu.be/VIDEO_ID
    else if (url.contains('youtu.be/')) {
      final parts = url.split('youtu.be/');
      if (parts.length > 1) {
        videoId = parts[1].split('?').first.split('&').first;
      }
    }
    // Handle youtube.com/embed/VIDEO_ID
    else if (url.contains('youtube.com/embed/')) {
      final parts = url.split('embed/');
      if (parts.length > 1) {
        videoId = parts[1].split('?').first.split('&').first;
      }
    }

    if (videoId != null && videoId.isNotEmpty) {
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    return null;
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
  }

  String? _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return null;
    }
  }

  String _getFaviconUrl(String domain) {
    // Use Google's favicon service for reliable favicons
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => const SizedBox(
                    height: 200,
                    child: Center(child: Icon(LucideIcons.imageOff, size: 48)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _launchUrl(imageUrl);
                },
                icon: const Icon(LucideIcons.externalLink),
                label: const Text('Open in Browser'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playVideo(String url) {
    String? videoId;
    try {
      videoId = YoutubePlayer.convertUrlToId(url);
    } catch (_) {}

    if (videoId != null && videoId.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => _YouTubePlayerDialog(videoId: videoId!),
      );
    } else {
      _launchUrl(url);
    }
  }

  Future<void> _startResearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    // Check and consume credits
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.deepResearch,
      feature: 'deep_research',
    );
    if (!hasCredits) return;

    setState(() {
      _isResearching = true;
      _result = null;
      _sources = null;
      _searchedSites.clear();
      _currentSearchQuery = null;
      _status = 'Starting research...';
      _progress = 0.0;
    });

    try {
      final researchService = ref.read(deepResearchServiceProvider);

      await for (final update in researchService.research(query,
          notebookId: _selectedNotebookId ?? '',
          useContextEngineering: _useContextEngineering)) {
        if (!mounted) break;

        setState(() {
          _status = update.status;
          _progress = update.progress;

          // Extract current search query from status
          if (update.status.contains('Searching:')) {
            final match =
                RegExp(r'Searching: "(.+?)"').firstMatch(update.status);
            if (match != null) {
              _currentSearchQuery = match.group(1);
            }
          }

          // Capture videos and images as they come in
          if (update.videos != null) _videos = update.videos;
          if (update.images != null) _images = update.images;

          // Track sources as they come in for live favicon display
          if (update.sources != null) {
            for (final source in update.sources!) {
              final domain = _extractDomain(source.url);
              if (domain != null && !_searchedSites.contains(domain)) {
                _searchedSites.add(domain);
              }
            }
          }

          if (update.result != null) {
            _result = update.result;
            _sources = update.sources;
            _isResearching = false;

            if (_selectedNotebookId != null && _result != null) {
              _saveToNotebook();
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isResearching = false;
        _status = 'Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Research failed: $e')),
      );
    }
  }

  Future<void> _saveToNotebook() async {
    if (_selectedNotebookId == null || _result == null) return;

    try {
      final query = _queryController.text.trim();
      final title = 'Deep Research: $query';

      await ref.read(sourceProvider.notifier).addSource(
            title: title,
            type: 'report',
            content: _result,
            notebookId: _selectedNotebookId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Research saved to notebook successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save to notebook: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Gradient App Bar
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Deep Research',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary,
                      scheme.secondary,
                      scheme.tertiary,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _queryController,
                          decoration: InputDecoration(
                            hintText: 'What topic should I investigate?',
                            prefixIcon:
                                Icon(LucideIcons.search, color: scheme.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: scheme.surface,
                            contentPadding: const EdgeInsets.all(20),
                          ),
                          style: text.bodyLarge,
                          maxLines: null,
                          enabled: !_isResearching,
                        ),
                        if (!_isResearching) ...[
                          Divider(height: 1, color: scheme.outlineVariant),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _useContextEngineering
                                          ? scheme.primaryContainer
                                              .withValues(alpha: 0.3)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SwitchListTile(
                                      title: Text(
                                        'Deep Context Mode',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12),
                                      subtitle: const Text(
                                        'Generate learning paths & mindmaps',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      value: _useContextEngineering,
                                      onChanged: (val) => setState(
                                          () => _useContextEngineering = val),
                                      dense: true,
                                      secondary: Icon(
                                        LucideIcons.brainCircuit,
                                        size: 18,
                                        color: _useContextEngineering
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Consumer(builder: (context, ref, _) {
                              final notebooks = ref.watch(notebookProvider);
                              return DropdownButtonFormField<String>(
                                initialValue: _selectedNotebookId,
                                decoration: InputDecoration(
                                  labelText: 'Save source to...',
                                  prefixIcon:
                                      const Icon(LucideIcons.book, size: 18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                style: TextStyle(color: scheme.onSurface),
                                dropdownColor: scheme.surface,
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      'Don\'t save automatically',
                                      style: TextStyle(color: scheme.onSurface),
                                    ),
                                  ),
                                  ...notebooks.map((n) => DropdownMenuItem(
                                        value: n.id,
                                        child: Text(
                                          n.title,
                                          style: TextStyle(
                                              color: scheme.onSurface),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )),
                                ],
                                onChanged: (value) =>
                                    setState(() => _selectedNotebookId = value),
                                selectedItemBuilder: (context) {
                                  return [
                                    Text(
                                      'Don\'t save automatically',
                                      style: TextStyle(color: scheme.onSurface),
                                    ),
                                    ...notebooks.map((n) => Text(
                                          n.title,
                                          style: TextStyle(
                                              color: scheme.onSurface),
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                  ];
                                },
                              );
                            }),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isResearching ? null : _startResearch,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _isResearching
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(LucideIcons.sparkles),
                              label: Text(
                                _isResearching
                                    ? 'Researching...'
                                    : 'Start Deep Research',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                ],
              ),
            ),
          ),

          // Progress Section
          if (_isResearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progress,
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: scheme.secondary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: scheme.secondary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(LucideIcons.loader,
                                    color: scheme.secondary)
                                .animate(onPlay: (c) => c.repeat())
                                .rotate(duration: 2.seconds),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _status,
                                  style: text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_currentSearchQuery != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Looking up: "$_currentSearchQuery"',
                                      style: text.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideX(),
                    // Live Favicons
                    if (_searchedSites.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _searchedSites.length,
                          itemBuilder: (context, index) {
                            final domain = _searchedSites[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: Colors.transparent,
                                  child: CachedNetworkImage(
                                    imageUrl: _getFaviconUrl(domain),
                                    imageBuilder: (context, imageProvider) =>
                                        Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: DecorationImage(
                                            image: imageProvider,
                                            fit: BoxFit.cover),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                        LucideIcons.globe,
                                        size: 16,
                                        color: scheme.onSurfaceVariant),
                                  ),
                                ),
                                label: Text(domain,
                                    style: const TextStyle(fontSize: 12)),
                                backgroundColor: scheme.surfaceContainerHighest,
                                side: BorderSide.none,
                                padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                              ),
                            ).animate().scale(curve: Curves.elasticOut);
                          },
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),

          // Results Section
          if (_result != null)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_images != null && _images!.isNotEmpty) ...[
                    Text('Visual Context',
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images!.take(8).length,
                        itemBuilder: (context, index) {
                          final imageUrl = _images![index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () => _showImageDialog(imageUrl),
                              borderRadius: BorderRadius.circular(12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: 220,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: scheme.surfaceContainerHighest,
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Markdown Report Card
                  Card(
                    elevation: 0,
                    color: scheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.fileText, color: scheme.primary),
                              const SizedBox(width: 12),
                              Text(
                                'Research Report',
                                style: text.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          MarkdownBody(
                            data: _result!,
                            styleSheet:
                                MarkdownStyleSheet.fromTheme(Theme.of(context))
                                    .copyWith(
                              p: text.bodyMedium?.copyWith(
                                height: 1.6,
                                color: scheme.onSurface,
                              ),
                              h1: text.headlineSmall?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.bold),
                              h2: text.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onSurface),
                              h3: text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface),
                              strong: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                              em: text.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: scheme.onSurface,
                              ),
                              listBullet: text.bodyMedium?.copyWith(
                                color: scheme.onSurface,
                              ),
                              blockquote: text.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border(
                                    left: BorderSide(
                                        color: scheme.primary, width: 4)),
                              ),
                            ),
                            onTapLink: (text, href, title) {
                              if (href != null) {
                                if (href.contains('youtube.com') ||
                                    href.contains('youtu.be')) {
                                  _playVideo(href);
                                } else {
                                  _launchUrl(href);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1),

                  // Videos Section
                  if (_videos != null && _videos!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Related Videos',
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._videos!.map((videoUrl) {
                      final thumbnailUrl = _getYouTubeThumbnail(videoUrl);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _playVideo(videoUrl),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 120,
                                height: 80,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (thumbnailUrl != null)
                                      CachedNetworkImage(
                                        imageUrl: thumbnailUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            Container(color: Colors.black26),
                                      )
                                    else
                                      Container(
                                        color: scheme.primaryContainer,
                                        child: Icon(LucideIcons.video,
                                            color: scheme.onPrimaryContainer),
                                      ),
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle),
                                        child: const Icon(Icons.play_arrow,
                                            color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        videoUrl,
                                        style: text.bodyMedium,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.youtube,
                                              size: 14, color: Colors.red),
                                          const SizedBox(width: 4),
                                          Text('Watch Video',
                                              style: text.labelSmall),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],

                  // Sources Section
                  if (_sources != null && _sources!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Sources Referenced',
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sources!.map((source) {
                        return ActionChip(
                          avatar: CircleAvatar(
                            backgroundImage: NetworkImage(_getFaviconUrl(
                                _extractDomain(source.url) ?? '')),
                            backgroundColor: Colors.transparent,
                            onBackgroundImageError: (_, __) {},
                            child: null,
                          ),
                          label: Text(
                            source.title.isEmpty ? 'Source' : source.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => _launchUrl(source.url),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 40),
                ]),
              ),
            )
          else if (!_isResearching)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.globe,
                        size: 80, color: scheme.outline.withValues(alpha: 0.2)),
                    const SizedBox(height: 24),
                    Text(
                      'Deep Research Agent',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 300,
                      child: Text(
                        'Powered by AI to browse the real-time web, read pages, and synthesize comprehensive reports.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _YouTubePlayerDialog extends StatefulWidget {
  final String videoId;
  const _YouTubePlayerDialog({required this.videoId});

  @override
  State<_YouTubePlayerDialog> createState() => _YouTubePlayerDialogState();
}

class _YouTubePlayerDialogState extends State<_YouTubePlayerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
        isLive: false,
        forceHD: false,
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
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(0),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Theme.of(context).primaryColor,
              onReady: () {
                _controller.play();
              },
              onEnded: (metaData) {
                Navigator.pop(context);
              },
              bottomActions: const [
                CurrentPosition(),
                ProgressBar(isExpanded: true),
                RemainingDuration(),
                FullScreenButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
