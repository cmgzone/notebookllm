import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../../core/ai/deep_research_service.dart';
import '../../core/api/api_service.dart';
import '../notebook/notebook_provider.dart';
import '../notebook/notebook.dart';
import '../subscription/services/credit_manager.dart';
import 'research_session_provider.dart';

class DeepResearchScreen extends ConsumerStatefulWidget {
  const DeepResearchScreen({super.key});

  @override
  ConsumerState<DeepResearchScreen> createState() => _DeepResearchScreenState();
}

class _DeepResearchScreenState extends ConsumerState<DeepResearchScreen>
    with SingleTickerProviderStateMixin {
  final _queryController = TextEditingController();
  late AnimationController _spinController;

  // State
  bool _isResearching = false;
  String _status = '';
  double _progress = 0.0;
  String? _result;
  List<ResearchSource>? _sources;
  List<String>? _images;
  String? _error;
  bool _showHistory = false;

  // Options
  ResearchDepth _depth = ResearchDepth.standard;
  ResearchTemplate _template = ResearchTemplate.general;
  String? _selectedNotebookId;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _startResearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    // Check credits
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: _depth == ResearchDepth.deep
          ? CreditCosts.deepResearch * 2
          : CreditCosts.deepResearch,
      feature: 'deep_research',
    );
    if (!hasCredits) return;

    setState(() {
      _isResearching = true;
      _result = null;
      _sources = null;
      _images = null;
      _error = null;
      _status = 'Starting research...';
      _progress = 0.0;
    });

    try {
      final service = ref.read(deepResearchServiceProvider);

      await for (final update in service.research(
        query: query,
        notebookId: _selectedNotebookId ?? '',
        depth: _depth,
        template: _template,
      )) {
        if (!mounted) break;

        setState(() {
          _status = update.status;
          _progress = update.progress;
          if (update.sources != null) _sources = update.sources;
          if (update.images != null) _images = update.images;
          if (update.result != null) _result = update.result;
          if (update.error != null) _error = update.error;
          if (update.isComplete) _isResearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResearching = false;
          _error = e.toString();
          _status = 'Error: $e';
        });
      }
    }
  }

  void _clearResearch() {
    setState(() {
      _result = null;
      _sources = null;
      _images = null;
      _error = null;
      _status = '';
      _progress = 0.0;
      _queryController.clear();
    });
  }

  Future<void> _shareReport() async {
    if (_result == null) return;
    await Share.share(_result!, subject: 'Research: ${_queryController.text}');
  }

  Future<void> _exportMarkdown() async {
    if (_result == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/research_${DateTime.now().millisecondsSinceEpoch}.md');
      var content = '# Research: ${_queryController.text}\n\n$_result';
      if (_images != null && _images!.isNotEmpty) {
        content += '\n\n## Visual Results\n\n';
        for (final img in _images!) {
          content += '![]($img)\n\n';
        }
      }
      await file.writeAsString(content);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _loadSession(ResearchSession session) async {
    setState(() {
      _showHistory = false;
      _status = 'Loading...';
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/research/sessions/${session.id}');
      final data = response['session'] as Map<String, dynamic>?;
      final sourcesData = response['sources'] as List<dynamic>? ?? [];

      if (data != null) {
        setState(() {
          _queryController.text = session.query;
          _result = data['report'] as String?;
          _sources = sourcesData
              .map((s) => ResearchSource(
                    title: s['title'] ?? '',
                    url: s['url'] ?? '',
                    content: s['content'] ?? '',
                    snippet: s['snippet'],
                    imageUrl: s['imageUrl'],
                  ))
              .toList();
          _images = _sources
              ?.where((s) => s.imageUrl != null && s.imageUrl!.isNotEmpty)
              .map((s) => s.imageUrl!)
              .toList();
          _status = '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
        setState(() => _status = '');
      }
    }
  }

  Future<void> _deleteSession(ResearchSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Research'),
        content: Text('Delete "${session.query}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(researchSessionProvider.notifier)
            .deleteSession(session.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sessions = ref.watch(researchSessionProvider);
    final notebooks = ref.watch(notebookProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_showHistory ? 'Research History' : 'Deep Research'),
        actions: [
          if (_result != null) ...[
            IconButton(
                icon: const Icon(LucideIcons.share2),
                onPressed: _shareReport,
                tooltip: 'Share'),
            IconButton(
                icon: const Icon(LucideIcons.download),
                onPressed: _exportMarkdown,
                tooltip: 'Export'),
            IconButton(
                icon: const Icon(LucideIcons.plus),
                onPressed: _clearResearch,
                tooltip: 'New'),
          ],
          IconButton(
            icon: Icon(_showHistory ? LucideIcons.x : LucideIcons.history),
            onPressed: () => setState(() => _showHistory = !_showHistory),
            tooltip: _showHistory ? 'Close' : 'History',
          ),
        ],
      ),
      body: _showHistory
          ? _buildHistory(sessions)
          : _buildMain(scheme, notebooks),
    );
  }

  Widget _buildHistory(AsyncValue<List<ResearchSession>> sessions) {
    return sessions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) => list.isEmpty
          ? const Center(child: Text('No research history'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final s = list[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(LucideIcons.fileText),
                    title: Text(s.query,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${s.sourceCount} sources'),
                    trailing: IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 20),
                      onPressed: () => _deleteSession(s),
                    ),
                    onTap: () => _loadSession(s),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMain(ColorScheme scheme, List<Notebook> notebooks) {
    if (_isResearching) {
      return _build3DResearchView(scheme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const SizedBox(height: 32),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.globe, size: 48, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Deep Research',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Explore any topic with AI-powered analysis',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Search input
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: 'What do you want to research?',
                    prefixIcon: const Icon(LucideIcons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: scheme.surface,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: null,
                  style: const TextStyle(fontSize: 16),
                  onSubmitted: (_) => _startResearch(),
                ),
                const SizedBox(height: 20),

                // Options row
                Row(
                  children: [
                    // Depth selector
                    Expanded(
                      child: DropdownButtonFormField<ResearchDepth>(
                        initialValue: _depth,
                        decoration: InputDecoration(
                          labelText: 'Depth',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: scheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: ResearchDepth.values
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d.name[0].toUpperCase() +
                                      d.name.substring(1)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _depth = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Template selector
                    Expanded(
                      child: DropdownButtonFormField<ResearchTemplate>(
                        initialValue: _template,
                        decoration: InputDecoration(
                          labelText: 'Template',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: scheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: ResearchTemplate.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(_templateName(t)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _template = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Notebook selector
                DropdownButtonFormField<String?>(
                  initialValue: _selectedNotebookId,
                  decoration: InputDecoration(
                    labelText: 'Save to Notebook (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: scheme.surface,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...notebooks.map((n) => DropdownMenuItem(
                          value: n.id,
                          child: Text(n.title),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedNotebookId = v),
                ),
                const SizedBox(height: 24),

                // Start button
                FilledButton(
                  onPressed: _queryController.text.trim().isEmpty
                      ? null
                      : _startResearch,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.sparkles),
                      SizedBox(width: 8),
                      Text('Start Deep Research',
                          style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Error display
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.alertCircle, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: TextStyle(color: scheme.onErrorContainer))),
                ],
              ),
            ),
          ],

          // Result display
          if (_result != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Research Report',
                          style: Theme.of(context).textTheme.headlineSmall),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.copy),
                            onPressed: () {
                              // Copy to clipboard
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  MarkdownBody(
                    data: _result!,
                    selectable: true,
                    onTapLink: (text, href, title) {
                      if (href != null) launchUrl(Uri.parse(href));
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                            p: const TextStyle(fontSize: 16, height: 1.6)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Images section
            if (_images != null && _images!.isNotEmpty) ...[
              Text('Visual Results',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images!.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: () => launchUrl(Uri.parse(_images![index])),
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Container(
                                width: 280,
                                height: 180,
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                child: Image.network(
                                  _images![index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Icon(LucideIcons.image,
                                        color: scheme.onSurfaceVariant),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(LucideIcons.externalLink,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Sources section
            if (_sources != null && _sources!.isNotEmpty) ...[
              Text('Sources & Citations',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _sources!.length,
                itemBuilder: (context, index) {
                  final s = _sources![index];
                  final host = Uri.parse(s.url).host;
                  return InkWell(
                    onTap: () => launchUrl(Uri.parse(s.url)),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                scheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                'https://www.google.com/s2/favicons?domain=$host&sz=64',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                    LucideIcons.globe,
                                    size: 16,
                                    color: scheme.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(s.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                Text(host,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                _credibilityBadge(s.credibility, scheme),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _build3DResearchView(ColorScheme scheme) {
    // Extract domain from status if available
    String? currentDomain;
    if (_status.contains('Found info from ')) {
      currentDomain =
          _status.replaceAll('Found info from ', '').replaceAll('...', '');
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient background glow
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 3D Rotating Rings
          AnimatedBuilder(
            animation: _spinController,
            builder: (context, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(math.pi / 6)
                  ..rotateY(_spinController.value * 2 * math.pi),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _spinController,
            builder: (context, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(-math.pi / 6)
                  ..rotateY(-_spinController.value * 2 * math.pi),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.tertiary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),

          // Center visual (Favicon or Globe)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: currentDomain != null
                ? Container(
                    key: ValueKey(currentDomain),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.network(
                          'https://www.google.com/s2/favicons?domain=$currentDomain&sz=128',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(LucideIcons.globe,
                              size: 40, color: scheme.primary),
                        ),
                      ),
                    ),
                  )
                : Container(
                    key: const ValueKey('default'),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Icon(LucideIcons.brainCircuit,
                        color: scheme.onPrimaryContainer, size: 30),
                  ),
          ),

          // Status Card
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _status,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _progress,
                          borderRadius: BorderRadius.circular(4),
                          backgroundColor: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                        ),
                        if (_sources != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_sources!.length} sources analyzed',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _templateName(ResearchTemplate t) {
    return switch (t) {
      ResearchTemplate.general => 'General',
      ResearchTemplate.academic => 'Academic',
      ResearchTemplate.productComparison => 'Comparison',
      ResearchTemplate.marketAnalysis => 'Market',
      ResearchTemplate.howToGuide => 'How-To',
      ResearchTemplate.prosAndCons => 'Pros & Cons',
      ResearchTemplate.shopping => 'Shopping',
    };
  }

  Widget _credibilityBadge(SourceCredibility c, ColorScheme scheme) {
    final (color, label) = switch (c) {
      SourceCredibility.academic => (Colors.green, 'Academic'),
      SourceCredibility.government => (Colors.blue, 'Gov'),
      SourceCredibility.news => (Colors.teal, 'News'),
      SourceCredibility.professional => (Colors.indigo, 'Pro'),
      SourceCredibility.blog => (Colors.orange, 'Blog'),
      SourceCredibility.unknown => (Colors.grey, ''),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
