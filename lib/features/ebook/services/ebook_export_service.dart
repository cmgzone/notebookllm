import 'dart:convert';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/ebook_project.dart';

class EbookExportService {
  /// Try to load an image from URL or base64 data
  /// Returns null if image can't be loaded or is SVG (not supported in PDF)
  Future<pw.MemoryImage?> _loadImage(String? url) async {
    if (url == null || url.isEmpty) return null;

    try {
      // Skip SVG images - PDF library doesn't support them
      if (url.contains('svg')) {
        debugPrint('[EbookExport] Skipping SVG image');
        return null;
      }

      if (url.startsWith('data:image')) {
        // Skip SVG data URIs
        if (url.contains('svg')) return null;

        // Only handle PNG/JPEG base64
        if (!url.contains('png') &&
            !url.contains('jpeg') &&
            !url.contains('jpg')) {
          return null;
        }

        final base64Data = url.split(',').last;
        final bytes = base64Decode(base64Data);
        return pw.MemoryImage(bytes);
      } else {
        // Network image
        final response = await http.get(Uri.parse(url)).timeout(
              const Duration(seconds: 10),
            );
        if (response.statusCode == 200) {
          return pw.MemoryImage(response.bodyBytes);
        }
      }
    } catch (e) {
      debugPrint('[EbookExport] Failed to load image: $e');
    }
    return null;
  }

  Future<Uint8List> exportToPdf(EbookProject project) async {
    final pdf = pw.Document();

    // Load cover image if available
    final coverImage = await _loadImage(project.coverImageUrl);

    // Cover Page
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (coverImage != null)
                  pw.Container(
                    height: 300,
                    child: pw.Image(coverImage),
                  ),
                pw.SizedBox(height: 40),
                pw.Text(
                  project.title,
                  style: pw.TextStyle(
                      fontSize: 40, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  project.branding.authorName,
                  style: const pw.TextStyle(fontSize: 24),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Chapters
    for (var chapter in project.chapters) {
      // Load chapter image
      pw.MemoryImage? chapterImage;
      if (chapter.images.isNotEmpty) {
        chapterImage = await _loadImage(chapter.images.first.url);
      }

      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text(chapter.title,
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            if (chapterImage != null)
              pw.Container(
                height: 200,
                margin: const pw.EdgeInsets.only(bottom: 20),
                alignment: pw.Alignment.center,
                child: pw.Image(chapterImage),
              ),
            pw.Paragraph(text: chapter.content), // Basic text rendering for now
          ],
        ),
      );
    }

    return await pdf.save();
  }
}

final ebookExportServiceProvider =
    Provider<EbookExportService>((ref) => EbookExportService());
