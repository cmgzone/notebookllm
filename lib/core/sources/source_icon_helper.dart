import 'package:flutter/material.dart';

/// Helper class to get appropriate icons and colors for different source types
class SourceIconHelper {
  static IconData getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return Icons.note;
      case 'youtube':
        return Icons.video_library;
      case 'drive':
        return Icons.drive_folder_upload;
      case 'url':
        return Icons.link;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      case 'file':
        return Icons.insert_drive_file;
      case 'code':
        return Icons.code;
      default:
        return Icons.description;
    }
  }

  static Color getColorForType(String type, ColorScheme scheme) {
    switch (type.toLowerCase()) {
      case 'text':
        return Colors.teal.shade600;
      case 'youtube':
        return Colors.red.shade600;
      case 'drive':
        return Colors.blue.shade600;
      case 'url':
        return scheme.primary;
      case 'image':
        return Colors.purple.shade600;
      case 'video':
        return Colors.orange.shade600;
      case 'audio':
        return Colors.green.shade600;
      case 'file':
        return scheme.secondary;
      case 'code':
        return Colors.cyan.shade600;
      default:
        return scheme.tertiary;
    }
  }

  static String getDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return 'Text Note';
      case 'youtube':
        return 'YouTube Video';
      case 'drive':
        return 'Google Drive';
      case 'url':
        return 'Web URL';
      case 'image':
        return 'Image';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      case 'file':
        return 'File';
      case 'code':
        return 'Verified Code';
      default:
        return 'Source';
    }
  }

  static String getDescription(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return 'Text note indexed';
      case 'youtube':
        return 'Video transcript extracted and indexed';
      case 'drive':
        return 'Document content extracted and indexed';
      case 'url':
        return 'Web page content extracted and indexed';
      case 'image':
        return 'Image analyzed and indexed';
      case 'video':
        return 'Video processed and indexed';
      case 'audio':
        return 'Audio transcribed and indexed';
      case 'file':
        return 'File content extracted and indexed';
      case 'code':
        return 'Code verified and indexed';
      default:
        return 'Content indexed';
    }
  }
}
