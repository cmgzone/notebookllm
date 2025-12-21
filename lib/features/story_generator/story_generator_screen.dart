import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'story.dart';
import 'story_generator_provider.dart';
import 'story_reader_screen.dart';
import '../subscription/services/credit_manager.dart';

class StoryGeneratorScreen extends ConsumerStatefulWidget {
  const StoryGeneratorScreen({super.key});

  @override
  ConsumerState<StoryGeneratorScreen> createState() =>
      _StoryGeneratorScreenState();
}

class _StoryGeneratorScreenState extends ConsumerState<StoryGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storyGeneratorProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Generator'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(LucideIcons.globe), text: 'Real Stories'),
            Tab(icon: Icon(LucideIcons.sparkles), text: 'Fiction'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          if (state.isGenerating) ...[
            LinearProgressIndicator(value: state.progress),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.status)),
                ],
              ),
            ),
          ],

          // Error message
          if (state.error != null)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(state.error!,
                        style: TextStyle(color: scheme.error)),
                  ),
                ],
              ),
            ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RealStoryTab(
                    stories: state.stories
                        .where((s) => s.type == StoryType.realStory)
                        .toList()),
                _FictionTab(
                    stories: state.stories
                        .where((s) => s.type == StoryType.fiction)
                        .toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RealStoryTab extends ConsumerStatefulWidget {
  final List<Story> stories;

  const _RealStoryTab({required this.stories});

  @override
  ConsumerState<_RealStoryTab> createState() => _RealStoryTabState();
}

class _RealStoryTabState extends ConsumerState<_RealStoryTab> {
  final _topicController = TextEditingController();
  String _selectedStyle = 'Narrative';
  final _styles = ['Narrative', 'Documentary', 'Journalistic', 'Dramatic'];

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isGenerating = ref.watch(storyGeneratorProvider).isGenerating;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Input section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.globe, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('Create Real Story',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a story based on real events using web research',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    labelText: 'Topic or Event',
                    hintText: 'e.g., The Moon Landing, Discovery of Penicillin',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStyle,
                  decoration: const InputDecoration(
                    labelText: 'Writing Style',
                    border: OutlineInputBorder(),
                  ),
                  items: _styles
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedStyle = v!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isGenerating ? null : _generateRealStory,
                    icon: const Icon(LucideIcons.search),
                    label: const Text('Research & Generate'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Stories list
        if (widget.stories.isNotEmpty) ...[
          Text('Your Real Stories',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...widget.stories.map((story) => _StoryCard(story: story)),
        ],
      ],
    );
  }

  Future<void> _generateRealStory() async {
    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic')),
      );
      return;
    }

    // Check and consume credits
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.storyGeneration,
      feature: 'story_generation',
    );
    if (!hasCredits) return;

    ref
        .read(storyGeneratorProvider.notifier)
        .generateRealStory(
          topic: _topicController.text.trim(),
          style: _selectedStyle,
        )
        .listen((_) {});
  }
}

class _FictionTab extends ConsumerStatefulWidget {
  final List<Story> stories;

  const _FictionTab({required this.stories});

  @override
  ConsumerState<_FictionTab> createState() => _FictionTabState();
}

class _FictionTabState extends ConsumerState<_FictionTab> {
  final _promptController = TextEditingController();
  final _settingController = TextEditingController();
  String _selectedGenre = 'Fantasy';
  StoryLength _selectedLength = StoryLength.medium;
  StoryTone _selectedTone = StoryTone.neutral;
  bool _showAdvanced = false;
  final _genres = [
    'Fantasy',
    'Sci-Fi',
    'Mystery',
    'Romance',
    'Horror',
    'Adventure',
    'Drama',
    'Thriller',
    'Historical',
    'Comedy',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    _settingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isGenerating = ref.watch(storyGeneratorProvider).isGenerating;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Input section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.sparkles, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('Create Fiction', style: text.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate an immersive story with AI-created illustrations',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _promptController,
                  decoration: const InputDecoration(
                    labelText: 'Story Prompt',
                    hintText:
                        'e.g., A young wizard discovers a hidden realm beneath an ancient library...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // Genre and Length row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGenre,
                        decoration: const InputDecoration(
                          labelText: 'Genre',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _genres
                            .map((g) =>
                                DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedGenre = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<StoryLength>(
                        initialValue: _selectedLength,
                        decoration: const InputDecoration(
                          labelText: 'Length',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: StoryLength.values
                            .map((l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(l.displayName),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedLength = v!),
                      ),
                    ),
                  ],
                ),

                // Length description
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    _selectedLength.description,
                    style: text.bodySmall?.copyWith(color: scheme.outline),
                  ),
                ),

                const SizedBox(height: 12),

                // Tone selection
                Text('Story Tone', style: text.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: StoryTone.values.map((tone) {
                    final isSelected = _selectedTone == tone;
                    return FilterChip(
                      label: Text('${tone.emoji} ${tone.displayName}'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedTone = tone);
                      },
                      selectedColor: scheme.primaryContainer,
                      checkmarkColor: scheme.primary,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                // Advanced options toggle
                InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Row(
                    children: [
                      Icon(
                        _showAdvanced
                            ? LucideIcons.chevronDown
                            : LucideIcons.chevronRight,
                        size: 18,
                        color: scheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text('Advanced Options',
                          style: text.labelMedium
                              ?.copyWith(color: scheme.outline)),
                    ],
                  ),
                ),

                if (_showAdvanced) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _settingController,
                    decoration: const InputDecoration(
                      labelText: 'Setting (Optional)',
                      hintText:
                          'e.g., Victorian London, distant future Mars colony...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isGenerating ? null : _generateFiction,
                    icon: const Icon(LucideIcons.penTool),
                    label:
                        Text(isGenerating ? 'Generating...' : 'Generate Story'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Stories list
        if (widget.stories.isNotEmpty) ...[
          Text('Your Fiction Stories',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...widget.stories.map((story) => _StoryCard(story: story)),
        ],
      ],
    );
  }

  Future<void> _generateFiction() async {
    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a story prompt')),
      );
      return;
    }

    // Check and consume credits
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.storyGeneration,
      feature: 'story_generation',
    );
    if (!hasCredits) return;

    ref
        .read(storyGeneratorProvider.notifier)
        .generateFictionStory(
          prompt: _promptController.text.trim(),
          genre: _selectedGenre,
          length: _selectedLength,
          tone: _selectedTone,
          setting: _settingController.text.trim().isNotEmpty
              ? _settingController.text.trim()
              : null,
        )
        .listen((_) {});
  }
}

class _StoryCard extends ConsumerWidget {
  final Story story;

  const _StoryCard({required this.story});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StoryReaderScreen(story: story)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            if (story.coverImageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  story.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: scheme.primaryContainer,
                    child: Icon(LucideIcons.image,
                        size: 48, color: scheme.primary),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        story.type == StoryType.realStory
                            ? LucideIcons.globe
                            : LucideIcons.sparkles,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        story.type.displayName,
                        style: TextStyle(fontSize: 12, color: scheme.primary),
                      ),
                      if (story.genre != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(story.genre!,
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    story.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${story.chapters.length} chapters • ${story.imageUrls.length} images',
                    style: Theme.of(context).textTheme.bodySmall,
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
