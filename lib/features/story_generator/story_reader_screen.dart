import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'story.dart';
import 'story_generator_provider.dart';

class StoryReaderScreen extends ConsumerStatefulWidget {
  final Story story;

  const StoryReaderScreen({super.key, required this.story});

  @override
  ConsumerState<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends ConsumerState<StoryReaderScreen> {
  int _currentChapter = 0;
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final story = widget.story;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with cover image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                story.title,
                style: const TextStyle(
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
              background: story.coverImageUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          story.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: scheme.primaryContainer,
                          ),
                        ),
                        Container(
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
                        ),
                      ],
                    )
                  : Container(color: scheme.primaryContainer),
            ),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.trash2),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),

          // Story info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type and genre badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              story.type == StoryType.realStory
                                  ? LucideIcons.globe
                                  : LucideIcons.sparkles,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(story.type.displayName),
                          ],
                        ),
                      ),
                      if (story.genre != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(story.genre!),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Synopsis
                  if (story.content.isNotEmpty) ...[
                    Text('Synopsis', style: text.titleMedium),
                    const SizedBox(height: 8),
                    Text(story.content, style: text.bodyMedium),
                    const SizedBox(height: 16),
                  ],

                  // Story info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (story.setting != null)
                        Chip(
                          avatar: Icon(LucideIcons.mapPin,
                              size: 16, color: scheme.primary),
                          label: Text(story.setting!,
                              style: const TextStyle(fontSize: 12)),
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      Chip(
                        avatar: Text(story.tone.emoji,
                            style: const TextStyle(fontSize: 14)),
                        label: Text(story.tone.displayName,
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                      Chip(
                        avatar: Icon(LucideIcons.bookOpen,
                            size: 16, color: scheme.primary),
                        label: Text(story.length.displayName,
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Characters section
          if (story.characters.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Characters', style: text.titleLarge),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: story.characters.length,
                  itemBuilder: (context, index) {
                    final character = story.characters[index];
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        _getRoleColor(character.role, scheme),
                                    radius: 16,
                                    child: Text(
                                      character.name.isNotEmpty
                                          ? character.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          character.name,
                                          style: text.titleSmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          character.role.toUpperCase(),
                                          style: text.labelSmall?.copyWith(
                                            color: _getRoleColor(
                                                character.role, scheme),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  character.description,
                                  style: text.bodySmall,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
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
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],

          // Chapters
          if (story.chapters.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Chapters', style: text.titleLarge),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chapter = story.chapters[index];
                  return _ChapterCard(
                    chapter: chapter,
                    isExpanded: _currentChapter == index,
                    onTap: () => setState(() {
                      _currentChapter = _currentChapter == index ? -1 : index;
                    }),
                  );
                },
                childCount: story.chapters.length,
              ),
            ),
          ],

          // Sources (for real stories)
          if (story.sources.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 16),
                    Text('Sources', style: text.titleMedium),
                    const SizedBox(height: 8),
                    ...story.sources.map((url) => ListTile(
                          leading: const Icon(LucideIcons.link, size: 18),
                          title: Text(
                            url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 13,
                            ),
                          ),
                          dense: true,
                          onTap: () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                        )),
                  ],
                ),
              ),
            ),
          ],

          // Image gallery
          if (story.imageUrls.length > 1) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gallery', style: text.titleMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: story.imageUrls.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                story.imageUrls[index],
                                width: 160,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 160,
                                  color: scheme.surfaceContainerHighest,
                                  child: const Icon(LucideIcons.image),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Color _getRoleColor(String role, ColorScheme scheme) {
    switch (role.toLowerCase()) {
      case 'protagonist':
        return Colors.blue;
      case 'antagonist':
        return Colors.red;
      default:
        return scheme.secondary;
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(storyGeneratorProvider.notifier)
                  .deleteStory(widget.story.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final StoryChapter chapter;
  final bool isExpanded;
  final VoidCallback onTap;

  const _ChapterCard({
    required this.chapter,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Text(
                '${chapter.order + 1}',
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
            title: Text(chapter.title, style: text.titleMedium),
            subtitle: chapter.hook != null
                ? Text(
                    chapter.hook!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: scheme.outline,
                    ),
                  )
                : null,
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: onTap,
          ),
          if (isExpanded) ...[
            if (chapter.imageUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    chapter.imageUrl!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: MarkdownBody(
                data: chapter.content,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: text.bodyMedium?.copyWith(
                    height: 1.6,
                    color: scheme.onSurface,
                  ),
                  strong: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                  em: text.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            // Cliffhanger at the end
            if (chapter.cliffhanger != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: scheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.sparkles, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chapter.cliffhanger!,
                        style: text.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
