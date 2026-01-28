import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../social_sharing_provider.dart';

class ShareContentSheet extends ConsumerStatefulWidget {
  final String contentType; // 'notebook' or 'plan'
  final String contentId;
  final String contentTitle;

  const ShareContentSheet({
    super.key,
    required this.contentType,
    required this.contentId,
    required this.contentTitle,
  });

  @override
  ConsumerState<ShareContentSheet> createState() => _ShareContentSheetState();
}

class _ShareContentSheetState extends ConsumerState<ShareContentSheet> {
  final _captionController = TextEditingController();
  bool _isPublic = true;
  bool _isSharing = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      await ref.read(socialSharingServiceProvider).shareContent(
            contentType: widget.contentType,
            contentId: widget.contentId,
            caption: _captionController.text.trim().isEmpty
                ? null
                : _captionController.text.trim(),
            isPublic: _isPublic,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${widget.contentType == 'notebook' ? 'Notebook' : 'Plan'} shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.contentType == 'notebook'
                    ? Icons.book
                    : Icons.assignment,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share ${widget.contentType == 'notebook' ? 'Notebook' : 'Plan'}',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      widget.contentTitle,
                      style: TextStyle(color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _captionController,
            decoration: InputDecoration(
              labelText: 'Add a caption (optional)',
              hintText: 'What would you like to say about this?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.edit_note),
            ),
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Share publicly'),
            subtitle: Text(
              _isPublic
                  ? 'Everyone can see this in the discover feed'
                  : 'Only your friends can see this',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
            secondary: Icon(_isPublic ? Icons.public : Icons.people),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isSharing ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSharing ? null : _share,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share),
                  label: Text(_isSharing ? 'Sharing...' : 'Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the share sheet
Future<bool?> showShareContentSheet(
  BuildContext context, {
  required String contentType,
  required String contentId,
  required String contentTitle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ShareContentSheet(
      contentType: contentType,
      contentId: contentId,
      contentTitle: contentTitle,
    ),
  );
}
