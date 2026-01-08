import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../social_sharing_provider.dart';

class ContentPrivacySheet extends ConsumerStatefulWidget {
  final String contentType; // 'notebook' or 'plan'
  final String contentId;
  final String contentTitle;
  final bool isPublic;
  final bool isLocked; // Only for notebooks
  final int viewCount;
  final int shareCount;

  const ContentPrivacySheet({
    super.key,
    required this.contentType,
    required this.contentId,
    required this.contentTitle,
    required this.isPublic,
    this.isLocked = false,
    this.viewCount = 0,
    this.shareCount = 0,
  });

  @override
  ConsumerState<ContentPrivacySheet> createState() =>
      _ContentPrivacySheetState();
}

class _ContentPrivacySheetState extends ConsumerState<ContentPrivacySheet> {
  late bool _isPublic;
  late bool _isLocked;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isPublic = widget.isPublic;
    _isLocked = widget.isLocked;
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final service = ref.read(socialSharingServiceProvider);

      if (widget.contentType == 'notebook') {
        if (_isPublic != widget.isPublic) {
          await service.setNotebookPublic(widget.contentId, _isPublic);
        }
        if (_isLocked != widget.isLocked) {
          await service.setNotebookLocked(widget.contentId, _isLocked);
        }
      } else {
        if (_isPublic != widget.isPublic) {
          await service.setPlanPublic(widget.contentId, _isPublic);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasChanges =
        _isPublic != widget.isPublic || _isLocked != widget.isLocked;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Privacy Settings', style: theme.textTheme.titleLarge),
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

          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                    icon: Icons.visibility,
                    value: widget.viewCount,
                    label: 'Views'),
                _StatItem(
                    icon: Icons.share,
                    value: widget.shareCount,
                    label: 'Shares'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Public toggle
          SwitchListTile(
            title: const Text('Make Public'),
            subtitle: Text(
              _isPublic
                  ? 'Anyone can discover and view this ${widget.contentType}'
                  : 'Only you can see this ${widget.contentType}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
            secondary: Icon(_isPublic ? Icons.public : Icons.lock),
          ),

          // Lock toggle (notebooks only)
          if (widget.contentType == 'notebook') ...[
            const Divider(),
            SwitchListTile(
              title: const Text('Lock Notebook'),
              subtitle: Text(
                _isLocked
                    ? 'Others cannot copy or clone this notebook'
                    : 'Others can copy this notebook to their account',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              value: _isLocked,
              onChanged: (value) => setState(() => _isLocked = value),
              secondary: Icon(_isLocked ? Icons.lock_outline : Icons.lock_open),
            ),
          ],

          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: hasChanges && !_isSaving ? _saveChanges : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _StatItem(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

/// Helper function to show the privacy sheet
Future<bool?> showContentPrivacySheet(
  BuildContext context, {
  required String contentType,
  required String contentId,
  required String contentTitle,
  required bool isPublic,
  bool isLocked = false,
  int viewCount = 0,
  int shareCount = 0,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ContentPrivacySheet(
      contentType: contentType,
      contentId: contentId,
      contentTitle: contentTitle,
      isPublic: isPublic,
      isLocked: isLocked,
      viewCount: viewCount,
      shareCount: shareCount,
    ),
  );
}
