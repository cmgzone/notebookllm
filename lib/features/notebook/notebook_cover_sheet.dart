import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/ai/cover_image_service.dart';
import 'notebook.dart';
import 'notebook_provider.dart';

class NotebookCoverSheet extends ConsumerStatefulWidget {
  final Notebook notebook;

  const NotebookCoverSheet({super.key, required this.notebook});

  @override
  ConsumerState<NotebookCoverSheet> createState() => _NotebookCoverSheetState();
}

class _NotebookCoverSheetState extends ConsumerState<NotebookCoverSheet> {
  bool _isGenerating = false;
  bool _isUploading = false;
  String? _previewImage;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _previewImage = widget.notebook.coverImage;
  }

  Future<void> _generateWithAI() async {
    setState(() {
      _isGenerating = true;
      _status = 'Generating cover image...';
    });

    try {
      final coverService = ref.read(coverImageServiceProvider);
      final imageData = await coverService.generateCoverImage(
        notebookTitle: widget.notebook.title,
        description: widget.notebook.description,
      );

      setState(() {
        _previewImage = imageData;
        _status = 'Cover generated!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString()}';
      });

      // Try fallback
      try {
        final coverService = ref.read(coverImageServiceProvider);
        final fallbackImage =
            await coverService.generateSimpleCover(widget.notebook.title);
        setState(() {
          _previewImage = fallbackImage;
          _status = 'Using gradient cover';
        });
      } catch (_) {}
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _pickImage() async {
    setState(() {
      _isUploading = true;
      _status = 'Selecting image...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.path != null) {
          final bytes = await File(file.path!).readAsBytes();
          final mimeType = _getMimeType(file.extension ?? 'jpg');
          final base64 = base64Encode(bytes);

          setState(() {
            _previewImage = 'data:$mimeType;base64,$base64';
            _status = 'Image selected';
          });
        }
      } else {
        setState(() => _status = 'Selection cancelled');
      }
    } catch (e) {
      setState(() => _status = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _saveCover() async {
    if (_previewImage == null) return;

    try {
      await ref.read(notebookProvider.notifier).updateNotebookCover(
            widget.notebook.id,
            _previewImage,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover image saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeCover() async {
    try {
      await ref.read(notebookProvider.notifier).updateNotebookCover(
            widget.notebook.id,
            null,
          );

      setState(() {
        _previewImage = null;
        _status = 'Cover removed';
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover image removed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPreview() {
    if (_previewImage == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'No cover image',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget imageWidget;
    if (_previewImage!.startsWith('data:image/svg+xml')) {
      // For SVG, show a placeholder or render it differently
      imageWidget = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.auto_awesome, size: 48, color: Colors.white54),
        ),
      );
    } else if (_previewImage!.startsWith('data:')) {
      // Base64 encoded image
      final base64Data = _previewImage!.split(',').last;
      imageWidget = Image.memory(
        base64Decode(base64Data),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, size: 48),
        ),
      );
    } else {
      // URL
      imageWidget = Image.network(
        _previewImage!,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, size: 48),
        ),
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget,
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLoading = _isGenerating || _isUploading;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Notebook Cover',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.notebook.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),

          // Preview
          _buildPreview(),
          const SizedBox(height: 16),

          // Status
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _status,
                style: TextStyle(
                  color:
                      _status.contains('Error') ? Colors.red : scheme.primary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : _pickImage,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: const Text('Upload'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isLoading ? null : _generateWithAI,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Generate'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Save/Remove buttons
          Row(
            children: [
              if (_previewImage != null || widget.notebook.coverImage != null)
                Expanded(
                  child: TextButton.icon(
                    onPressed: isLoading ? null : _removeCover,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Remove',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              if (_previewImage != null &&
                  _previewImage != widget.notebook.coverImage)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : _saveCover,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Cover'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Show the cover image management sheet
void showNotebookCoverSheet(BuildContext context, Notebook notebook) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => NotebookCoverSheet(notebook: notebook),
  );
}
