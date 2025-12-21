import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'source_provider.dart';

import 'add_url_sheet.dart';
import 'add_youtube_sheet.dart';
import 'add_google_drive_sheet.dart';
import 'enhanced_text_note_sheet.dart';

class AddSourceSheet extends ConsumerWidget {
  final String? notebookId;
  const AddSourceSheet({super.key, this.notebookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

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
                Text('Add source', style: text.titleLarge),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._connectors(context, ref),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _connectors(BuildContext context, WidgetRef ref) {
    final connectors = [
      const _ConnectorItem(icon: Icons.note_add, label: 'Text Note'),
      const _ConnectorItem(
          icon: Icons.drive_folder_upload, label: 'Google Drive'),
      const _ConnectorItem(icon: Icons.image, label: 'Image'),
      const _ConnectorItem(icon: Icons.videocam, label: 'Video'),
      const _ConnectorItem(icon: Icons.link, label: 'Web URL'),
      const _ConnectorItem(icon: Icons.video_library, label: 'YouTube'),
      const _ConnectorItem(icon: Icons.audiotrack, label: 'Audio'),
    ];
    return connectors
        .map((c) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: ListTile(
                leading:
                    Icon(c.icon, color: Theme.of(context).colorScheme.primary),
                title: Text(c.label),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: Theme.of(context).colorScheme.surface,
                onTap: () {
                  Navigator.pop(context);
                  if (c.label == 'Text Note') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          EnhancedTextNoteSheet(notebookId: notebookId),
                    );
                  } else if (c.label == 'Web URL') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => AddUrlSheet(notebookId: notebookId),
                    );
                  } else if (c.label == 'YouTube') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => AddYouTubeSheet(notebookId: notebookId),
                    );
                  } else if (c.label == 'Google Drive') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          AddGoogleDriveSheet(notebookId: notebookId),
                    );
                  } else if (c.label == 'Image') {
                    _pickAndUpload(context, ref, type: 'image');
                  } else if (c.label == 'Video') {
                    _pickAndUpload(context, ref, type: 'video');
                  } else if (c.label == 'Audio') {
                    _pickAndUpload(context, ref, type: 'audio');
                  }
                },
              ),
            ))
        .toList();
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref,
      {required String type}) async {
    final isImage = type == 'image';
    final allowedExtensions = isImage
        ? ['jpg', 'jpeg', 'png', 'gif', 'webp']
        : (type == 'video'
            ? ['mp4', 'mov', 'm4v', 'webm']
            : ['mp3', 'wav', 'm4a']);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      if (!context.mounted) return;
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Uploading $type...'),
            ],
          ),
          duration: const Duration(minutes: 5),
        ),
      );

      final file = result.files.first;
      final name = file.name;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      // final service = ref.read(mediaServiceProvider);
      // final asset = await service.uploadBytes(bytes, filename: name, type: type);
      // final storageUri = service.storageUri(asset);

      // We skip Supabase upload and directly save to Neon via sourceProvider

      await ref.read(sourceProvider.notifier).addSource(
            title: name,
            type: type,
            content: 'media://$name', // Placeholder content, media is in bytea
            mediaBytes: bytes,
            notebookId: notebookId,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${type[0].toUpperCase()}${type.substring(1)} uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _ConnectorItem {
  const _ConnectorItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
