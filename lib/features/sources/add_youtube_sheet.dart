import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'source_provider.dart';
import '../../core/sources/content_extractor_service.dart';
import '../../core/sources/url_validator.dart';

class AddYouTubeSheet extends ConsumerStatefulWidget {
  final String? notebookId;
  const AddYouTubeSheet({super.key, this.notebookId});

  @override
  ConsumerState<AddYouTubeSheet> createState() => _AddYouTubeSheetState();
}

class _AddYouTubeSheetState extends ConsumerState<AddYouTubeSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateYouTubeUrl(String url) {
    return UrlValidator.isValidYouTubeUrl(url)
        ? null
        : UrlValidator.getErrorMessage(url, 'youtube');
  }

  String _extractVideoId(String url) {
    return UrlValidator.extractYouTubeVideoId(url) ?? '';
  }

  Future<void> _addYouTube() async {
    final url = _controller.text.trim();
    final error = _validateYouTubeUrl(url);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final videoId = _extractVideoId(url);
      final title = 'YouTube: $videoId';

      // Extract content using the content extractor service
      final extractor = ref.read(contentExtractorServiceProvider);
      final content = await extractor.extractYouTubeContent(url);

      await ref.read(sourceProvider.notifier).addSource(
            title: title,
            type: 'youtube',
            content: content,
            notebookId: widget.notebookId,
          );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('YouTube video added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add YouTube video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.video_library, color: scheme.primary),
                const SizedBox(width: 12),
                Text('Add YouTube Video', style: text.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'YouTube URL',
                hintText: 'https://youtube.com/watch?v=...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.url,
              onSubmitted: _isLoading ? null : (_) => _addYouTube(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Paste a YouTube video URL. We\'ll extract the transcript and make it searchable.',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _addYouTube,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Add Video'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
