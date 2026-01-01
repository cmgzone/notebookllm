// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_overview_provider.dart';
import 'audio_player_sheet.dart';
import 'artifact_provider.dart';
import '../sources/source_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/audio/murf_service.dart';
import '../subscription/services/credit_manager.dart';

class StudioScreen extends ConsumerStatefulWidget {
  final String? notebookId; // null = global view, otherwise notebook-specific

  const StudioScreen({super.key, this.notebookId});

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  String? _generatingType;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final allSources = ref.watch(sourceProvider);
    final audioState = ref.watch(audioOverviewProvider);
    final audioOverviews = audioState.overviews;

    // Filter by notebook if notebookId is provided
    final sources = widget.notebookId != null
        ? allSources.where((s) => s.notebookId == widget.notebookId).toList()
        : allSources;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.notebookId != null ? 'Studio' : 'Global Studio'),
        centerTitle: true,
        actions: [
          Consumer(builder: (context, ref, _) {
            final mode = ref.watch(themeModeProvider);
            return IconButton(
              icon: Icon(
                  mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
              tooltip: mode == ThemeMode.dark
                  ? 'Switch to Light Mode'
                  : 'Switch to Dark Mode',
              onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            );
          }),
          if (audioOverviews.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.headphones),
              tooltip: 'Audio History',
              onPressed: () => _showAudioHistory(context, ref, audioOverviews),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 10, 20, 100), // More bottom padding for scroll
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sources.isEmpty)
                    _buildEmptyState(context)
                  else ...[
                    // Audio Section (Podcast)
                    Text('Audio Experience',
                        style: text.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 12),
                    _buildAudioCard(context, ref, audioState),

                    const SizedBox(height: 32),

                    // Visual/Text Artifacts
                    Text('Visual Support',
                        style: text.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 12),
                    GridView(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 140, // Fixed height for tighter cards
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _TemplateCard(
                          title: 'Study Guide',
                          subtitle: 'Key concepts & summaries',
                          icon: LucideIcons.bookOpen,
                          color: Colors.blue,
                          isLoading: _generatingType == 'study-guide',
                          onTap: () =>
                              _generateArtifact(context, ref, 'study-guide'),
                        ),
                        _TemplateCard(
                          title: 'Executive Brief',
                          subtitle: 'Actionable insights',
                          icon: LucideIcons.fileText,
                          color: Colors.green,
                          isLoading: _generatingType == 'brief',
                          onTap: () => _generateArtifact(context, ref, 'brief'),
                        ),
                        _TemplateCard(
                          title: 'FAQ',
                          subtitle: 'Common questions',
                          icon: LucideIcons.helpCircle,
                          color: Colors.orange,
                          isLoading: _generatingType == 'faq',
                          onTap: () => _generateArtifact(context, ref, 'faq'),
                        ),
                        _TemplateCard(
                          title: 'Timeline',
                          subtitle: 'Chronological events',
                          icon: LucideIcons.calendarClock,
                          color: Colors.purple,
                          isLoading: _generatingType == 'timeline',
                          onTap: () =>
                              _generateArtifact(context, ref, 'timeline'),
                        ),
                        _TemplateCard(
                          title: 'Visual Studio',
                          subtitle: 'Generate Images',
                          icon: LucideIcons.image,
                          color: Colors.pink,
                          onTap: () => context.push('/visual-studio'),
                        ),
                        _TemplateCard(
                          title: 'Ebook Creator',
                          subtitle: 'AI Agents at work',
                          icon: LucideIcons.book,
                          color: Colors.indigo,
                          onTap: () => context.push('/ebook-creator'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(LucideIcons.library,
              size: 60,
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Add sources to start creating',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioCard(
      BuildContext context, WidgetRef ref, AudioStudioState state) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (state.isGenerating) {
      return Card(
        elevation: 4,
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              SizedBox(
                height: 60,
                width: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: state.progressValue > 0
                          ? state.progressValue / 100
                          : null,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                    ),
                    const Icon(LucideIcons.mic, size: 24),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                state.isCancelled
                    ? 'Cancelling...'
                    : 'Producing Deep Dive Podcast...',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                state.progressMessage,
                style: text.bodySmall?.copyWith(color: scheme.secondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Cancel button
              if (!state.isCancelled)
                TextButton.icon(
                  onPressed: () {
                    ref.read(audioOverviewProvider.notifier).cancelGeneration();
                  },
                  icon: Icon(Icons.cancel_outlined,
                      size: 18, color: scheme.error),
                  label: Text('Cancel', style: TextStyle(color: scheme.error)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
            ],
          ),
        ),
      ).animate().fadeIn();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer,
              scheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showPodcastSettings(context, ref),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(LucideIcons.headphones,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deep Dive Podcast',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Generate a conversational audio overview with two hosts.',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(LucideIcons.chevronRight, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPodcastSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _PodcastSettingsDialog(
        onGenerate: (topic) => _generateAudioOverview(ref, topic),
      ),
    );
  }

  void _generateArtifact(
      BuildContext context, WidgetRef ref, String type) async {
    if (_generatingType != null) return;

    // Check sources
    final allSources = ref.read(sourceProvider);
    final sources = widget.notebookId != null
        ? allSources.where((s) => s.notebookId == widget.notebookId).toList()
        : allSources;

    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some sources first')),
      );
      return;
    }

    // Check and consume credits based on artifact type
    final creditCost = type == 'study-guide'
        ? CreditCosts.generateStudyGuide
        : type == 'mind-map'
            ? CreditCosts.generateMindMap
            : CreditCosts
                .generateStudyGuide; // Default cost for other artifacts

    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: creditCost,
      feature: 'generate_$type',
    );
    if (!hasCredits) return;

    setState(() => _generatingType = type);

    try {
      await ref.read(artifactProvider.notifier).generate(
            type,
            notebookId: widget.notebookId,
            showBubble: true,
          );
      if (context.mounted) {
        final allArtifacts = ref.read(artifactProvider);
        if (allArtifacts.isNotEmpty) {
          context.push('/artifact', extra: allArtifacts.last);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generatingType = null);
      }
    }
  }

  Future<void> _generateAudioOverview(WidgetRef ref, String? topic) async {
    // Check and consume credits for podcast generation
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.podcastGeneration,
      feature: 'podcast_generation',
    );
    if (!hasCredits) return;

    try {
      await ref
          .read(audioOverviewProvider.notifier)
          .generate('Deep Dive Podcast', isPodcast: true, topic: topic);

      // We don't need a snackbar here because the UI updates to show generation progress
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error generating audio: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showAudioHistory(
      BuildContext context, WidgetRef ref, List<dynamic> items) {
    // dynamic list to match AudioOverview, but really it's List<AudioOverview>
    // We should cast or use properly.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('Audio History',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(),
            ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final ov = items[items.length - 1 - index];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.headphones,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(ov.title),
                  subtitle: Text(
                      '${ov.createdAt.day}/${ov.createdAt.month} • ${ov.duration.inMinutes}m'),
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => AudioPlayerSheet(overview: ov),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      color: scheme.surfaceContainer, // Clean look
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: color,
                            ),
                          )
                        : Icon(
                            icon,
                            color: color,
                            size: 24,
                          ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Podcast Settings Dialog with voice customization
class _PodcastSettingsDialog extends StatefulWidget {
  final Function(String?) onGenerate;

  const _PodcastSettingsDialog({required this.onGenerate});

  @override
  State<_PodcastSettingsDialog> createState() => _PodcastSettingsDialogState();
}

class _PodcastSettingsDialogState extends State<_PodcastSettingsDialog> {
  String? _topic;
  String _ttsProvider = 'elevenlabs';
  String _murfVoiceFemale = 'en-US-natalie';
  String _murfVoiceMale = 'en-US-miles';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ttsProvider = prefs.getString('tts_provider') ?? 'elevenlabs';
      _murfVoiceFemale = prefs.getString('tts_murf_voice') ?? 'en-US-natalie';
      _murfVoiceMale = prefs.getString('tts_murf_voice_male') ?? 'en-US-miles';
      _isLoading = false;
    });
  }

  Future<void> _saveVoiceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tts_murf_voice', _murfVoiceFemale);
    await prefs.setString('tts_murf_voice_male', _murfVoiceMale);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMurf = _ttsProvider == 'murf';

    return AlertDialog(
      title: Row(
        children: [
          Icon(LucideIcons.headphones, color: scheme.primary),
          const SizedBox(width: 12),
          const Text('Podcast Settings'),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What should the hosts focus on?',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText:
                          'e.g. "The unexpected plot twist" or "Key financial metrics"',
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    onChanged: (val) => _topic = val,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.people, size: 20, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text('Hosts: Sarah & Adam',
                          style: Theme.of(context).textTheme.labelLarge),
                    ],
                  ),
                  if (isMurf) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.record_voice_over,
                                  size: 16, color: scheme.primary),
                              const SizedBox(width: 8),
                              Text('Murf Voice Settings',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: scheme.primary,
                                      )),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Sarah (Female Host):',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _murfVoiceFemale,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: scheme.surface,
                            ),
                            items: MurfService.femaleVoices.map((voiceId) {
                              final name =
                                  MurfService.voices[voiceId] ?? voiceId;
                              return DropdownMenuItem(
                                value: voiceId,
                                child: Text(name,
                                    style: TextStyle(
                                        fontSize: 13, color: scheme.onSurface)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _murfVoiceFemale = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Text('Adam (Male Host):',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _murfVoiceMale,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: scheme.surface,
                            ),
                            items: MurfService.maleVoices.map((voiceId) {
                              final name =
                                  MurfService.voices[voiceId] ?? voiceId;
                              return DropdownMenuItem(
                                value: voiceId,
                                child: Text(name,
                                    style: TextStyle(
                                        fontSize: 13, color: scheme.onSurface)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _murfVoiceMale = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Using $_ttsProvider for voices. Select Murf in Settings for custom host voices.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () async {
            if (isMurf) {
              await _saveVoiceSettings();
            }
            if (context.mounted) {
              Navigator.pop(context);
            }
            widget.onGenerate(_topic);
          },
          icon: const Icon(LucideIcons.sparkles),
          label: const Text('Generate'),
        ),
      ],
    );
  }
}
