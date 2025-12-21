import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/ai/gemini_image_service.dart';
import '../../core/security/global_credentials_service.dart';

class VisualStudioScreen extends ConsumerStatefulWidget {
  const VisualStudioScreen({super.key});

  @override
  ConsumerState<VisualStudioScreen> createState() => _VisualStudioScreenState();
}

class _VisualStudioScreenState extends ConsumerState<VisualStudioScreen> {
  final _promptController = TextEditingController();
  String? _generatedImageUrl;
  bool _isGenerating = false;

  void _generateImage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _generatedImageUrl = null;
    });

    try {
      // Get API key from secure storage
      final creds = ref.read(globalCredentialsServiceProvider);
      final apiKey = await creds.getApiKey('gemini');

      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Gemini API key not found. Please set it in Settings.');
      }

      final imageService = GeminiImageService(apiKey: apiKey);
      final url = await imageService.generateImage(prompt);

      if (mounted) {
        setState(() {
          _generatedImageUrl = url;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    }
  }

  Future<void> _saveAndShareImage() async {
    if (_generatedImageUrl == null) return;

    try {
      // Extract base64 data from data URL
      final base64Data = _generatedImageUrl!.split(',')[1];
      final bytes = base64Decode(base64Data);

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/generated_image_${DateTime.now().millisecondsSinceEpoch}.png');

      // Write bytes to file
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Generated with Visual Studio: ${_promptController.text}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image ready to share!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save/share: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Studio'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prompt Input
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe the image you want to generate...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 16),

            // Generate Button
            FilledButton.icon(
              onPressed: _isGenerating ? null : _generateImage,
              icon: _isGenerating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: scheme.onPrimary))
                  : const Icon(LucideIcons.wand2),
              label: Text(_isGenerating ? 'Dreaming...' : 'Generate Image'),
            ),

            const SizedBox(height: 32),

            // Result Area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                alignment: Alignment.center,
                child: _buildContent(scheme, text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme scheme, TextTheme text) {
    if (_isGenerating) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Creating your masterpiece...', style: text.bodyLarge),
        ],
      );
    }

    if (_generatedImageUrl != null) {
      // Decode base64 image for display
      final base64Data = _generatedImageUrl!.split(',')[1];
      final bytes = base64Decode(base64Data);

      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              bytes,
              fit: BoxFit.cover,
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: _saveAndShareImage,
                child: const Icon(Icons.share),
              ),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.image, size: 64, color: scheme.outline),
        const SizedBox(height: 16),
        Text(
          'Your imagination awaits',
          style: text.titleMedium?.copyWith(color: scheme.outline),
        ),
      ],
    );
  }
}
