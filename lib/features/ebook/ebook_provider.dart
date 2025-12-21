import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import 'models/ebook_project.dart';
import 'models/ebook_chapter.dart';

class EbookNotifier extends StateNotifier<List<EbookProject>> {
  final Ref ref;

  EbookNotifier(this.ref) : super([]) {
    _loadEbooks();
  }

  Future<void> _loadEbooks() async {
    try {
      final api = ref.read(apiServiceProvider);
      final projectsData = await api.getEbookProjects();

      final projects = <EbookProject>[];
      for (var j in projectsData) {
        final project = EbookProject.fromBackendJson(j);
        // Load chapters for each project
        try {
          final chaptersData = await api.getEbookChapters(project.id);
          final updatedProject = project.copyWith(
            chapters: chaptersData
                .map((c) => EbookChapter.fromBackendJson(c))
                .toList(),
          );
          projects.add(updatedProject);
        } catch (e) {
          debugPrint('Error loading chapters for ebook ${project.id}: $e');
          projects.add(project);
        }
      }

      state = projects..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Error loading ebooks: $e');
      state = [];
    }
  }

  Future<void> addEbook(EbookProject ebook) async {
    try {
      final api = ref.read(apiServiceProvider);
      final savedProject = await api.saveEbookProject(
        title: ebook.title,
        topic: ebook.topic,
        targetAudience: ebook.targetAudience,
        branding: ebook.branding.toBackendJson(),
        selectedModel: ebook.selectedModel,
        notebookId: ebook.notebookId ?? '',
      );

      // If there are chapters, sync them
      if (ebook.chapters.isNotEmpty) {
        await api.syncEbookChapters(
          projectId: savedProject['id'],
          chapters: ebook.chapters.map((c) => c.toBackendJson()).toList(),
        );
      }

      await _loadEbooks();
    } catch (e) {
      debugPrint('Error adding ebook: $e');
    }
  }

  Future<void> updateEbook(EbookProject ebook) async {
    try {
      // The backend API for updating a project is saveEbookProject (UPSERT)
      final api = ref.read(apiServiceProvider);
      await api.saveEbookProject(
        id: ebook.id,
        title: ebook.title,
        topic: ebook.topic,
        targetAudience: ebook.targetAudience,
        branding: ebook.branding.toBackendJson(),
        selectedModel: ebook.selectedModel,
        notebookId: ebook.notebookId ?? '',
      );

      // Sync chapters
      if (ebook.chapters.isNotEmpty) {
        await api.syncEbookChapters(
          projectId: ebook.id,
          chapters: ebook.chapters.map((c) => c.toBackendJson()).toList(),
        );
      }

      await _loadEbooks();
    } catch (e) {
      debugPrint('Error updating ebook: $e');
    }
  }

  Future<void> deleteEbook(String id) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteEbookProject(id);
      state = state.where((e) => e.id != id).toList();
    } catch (e) {
      debugPrint('Error deleting ebook: $e');
    }
  }

  EbookProject? getEbook(String id) {
    try {
      return state.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}

final ebookProvider =
    StateNotifierProvider<EbookNotifier, List<EbookProject>>((ref) {
  return EbookNotifier(ref);
});
