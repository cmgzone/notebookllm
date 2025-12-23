import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import '../auth/custom_auth_service.dart';

final neonFunctionsServiceProvider = Provider<NeonFunctionsService>((ref) {
  return NeonFunctionsService(ref);
});

class NeonFunctionsService {
  final Ref ref;

  NeonFunctionsService(this.ref);

  ApiService get _api => ref.read(apiServiceProvider);
  String? get _userId => ref.read(customAuthStateProvider).user?.uid;

  // ============================================
  // ANALYTICS
  // ============================================

  Future<Map<String, dynamic>> getUserStats() async {
    if (_userId == null) throw Exception('User not authenticated');
    return await _api.getUserStats();
  }

  Future<Map<String, dynamic>> getNotebookAnalytics(String notebookId) async {
    return await _api.getNotebookAnalytics(notebookId);
  }

  // ============================================
  // SEARCH
  // ============================================

  Future<List<Map<String, dynamic>>> searchSources(
    String query, {
    int limit = 20,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');
    return await _api.searchSources(query, limit: limit);
  }

  Future<List<Map<String, dynamic>>> searchSourcesFiltered({
    required String query,
    String? sourceType,
    List<String>? tagIds,
    int limit = 20,
  }) async {
    // Note: The backend search_sources function supports filters
    // but the current route just exposes basic search.
    // For now, we'll use the basic search or extend the route if needed.
    return await _api.searchSources(query, limit: limit);
  }

  // ============================================
  // TAG MANAGEMENT
  // ============================================

  Future<String> getOrCreateTag(String tagName,
      {String color = '#3B82F6'}) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      final tags = await _api.getTags();
      final existing = tags.firstWhere(
        (t) => t['name'] == tagName,
        orElse: () => {},
      );

      if (existing.isNotEmpty && existing['id'] != null) {
        return existing['id'];
      }

      final newTag = await _api.createTag(name: tagName, color: color);
      return newTag['id'];
    } catch (e) {
      debugPrint('Error in getOrCreateTag: $e');
      rethrow;
    }
  }

  Future<bool> addTagToSource(String sourceId, String tagId) async {
    await _api.addTagToSource(sourceId, tagId);
    return true;
  }

  Future<bool> removeTagFromSource(String sourceId, String tagId) async {
    await _api.removeTagFromSource(sourceId, tagId);
    return true;
  }

  Future<List<Map<String, dynamic>>> getPopularTags({int limit = 10}) async {
    if (_userId == null) throw Exception('User not authenticated');
    return await _api.getPopularTags(limit: limit);
  }

  // ============================================
  // BULK OPERATIONS
  // ============================================

  Future<int> bulkDeleteSources(List<String> sourceIds) async {
    return await _api.bulkDeleteSources(sourceIds);
  }

  Future<int> bulkAddTags(List<String> sourceIds, List<String> tagIds) async {
    return await _api.bulkAddTagsToSources(sourceIds, tagIds);
  }

  Future<int> bulkMoveSources(
      List<String> sourceIds, String targetNotebookId) async {
    return await _api.bulkMoveSources(sourceIds, targetNotebookId);
  }

  Future<int> bulkRemoveTags(
      List<String> sourceIds, List<String> tagIds) async {
    return await _api.bulkRemoveTagsFromSources(sourceIds, tagIds);
  }

  // ============================================
  // MEDIA MANAGEMENT
  // ============================================

  Future<int> getUserMediaSize() async {
    if (_userId == null) throw Exception('User not authenticated');
    return await _api.getMediaSizeStats();
  }

  Future<int> cleanupOrphanedMedia() async {
    // Backend doesn't have an explicit route for this yet, so we return 0
    return 0;
  }

  // ============================================
  // SHARING
  // ============================================

  Future<Map<String, dynamic>> createShareToken(
    String notebookId, {
    String accessLevel = 'read',
    int expiresInDays = 7,
  }) async {
    return await _api.createShareToken(notebookId,
        accessLevel: accessLevel, expiresInDays: expiresInDays);
  }

  Future<Map<String, dynamic>> validateShareToken(String token) async {
    return await _api.validateShareToken(token);
  }

  Future<List<Map<String, dynamic>>> listShares(String notebookId) async {
    return await _api.listShares(notebookId);
  }

  Future<bool> revokeShare(String notebookId, String token) async {
    return await _api.revokeShare(notebookId, token);
  }

  // ============================================
  // RECOMMENDATIONS
  // ============================================

  Future<List<Map<String, dynamic>>> getRelatedSources(
    String sourceId, {
    int limit = 5,
  }) async {
    return await _api.getRelatedSources(sourceId);
  }
}
