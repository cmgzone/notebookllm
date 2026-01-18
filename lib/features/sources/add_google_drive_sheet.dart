import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'source_provider.dart';
import '../../core/api/api_service.dart';
import '../../core/sources/url_validator.dart';

class AddGoogleDriveSheet extends ConsumerStatefulWidget {
  final String? notebookId;
  const AddGoogleDriveSheet({super.key, this.notebookId});

  @override
  ConsumerState<AddGoogleDriveSheet> createState() =>
      _AddGoogleDriveSheetState();
}

class _AddGoogleDriveSheetState extends ConsumerState<AddGoogleDriveSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateGoogleDriveUrl(String url) {
    return UrlValidator.isValidGoogleDriveUrl(url)
        ? null
        : UrlValidator.getErrorMessage(url, 'drive');
  }

  String _extractFileId(String url) {
    return UrlValidator.extractGoogleDriveFileId(url) ?? '';
  }

  String _getFileType(String url) {
    return UrlValidator.getGoogleDriveDisplayName(url);
  }

  Future<void> _addGoogleDrive() async {
    final url = _controller.text.trim();
    final error = _validateGoogleDriveUrl(url);

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
      final fileId = _extractFileId(url);
      final fileType = _getFileType(url);
      final title = '$fileType: $fileId';

      // Call backend API for content extraction
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/google-drive/extract', {
        'url': url,
        'fileId': fileId,
      });

      if (response['success'] == true) {
        final content = response['content'] as String;
        final metadata = response['metadata'] as Map<String, dynamic>?;

        await ref.read(sourceProvider.notifier).addSource(
              title: metadata?['format'] ?? title,
              type: 'drive',
              content: content,
              notebookId: widget.notebookId,
            );

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Drive file added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show error with instructions
        if (!mounted) return;
        final errorMsg = response['error'] ?? 'Failed to extract content';
        final instructions = response['instructions'] as List?;

        String message = errorMsg;
        if (instructions != null && instructions.isNotEmpty) {
          message += '\n\nTips:\n';
          message += instructions.map((i) => '• $i').join('\n');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add Google Drive file: $e'),
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
                Icon(Icons.drive_folder_upload, color: scheme.primary),
                const SizedBox(width: 12),
                Text('Add from Google Drive', style: text.titleLarge),
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
                labelText: 'Google Drive URL',
                hintText: 'https://drive.google.com/file/d/...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.url,
              onSubmitted: _isLoading ? null : (_) => _addGoogleDrive(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supported formats:',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Google Docs, Sheets, Slides\n• PDFs and documents\n• Make sure the file is publicly accessible or shared',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
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
                  onPressed: _isLoading ? null : _addGoogleDrive,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Add File'),
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
