import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'neon_functions_service.dart';

// Deprecated: Use neonFunctionsServiceProvider instead
// This is kept for backward compatibility
final backendFunctionsServiceProvider =
    Provider<BackendFunctionsService>((ref) {
  return BackendFunctionsService(ref);
});

/// Backward compatibility wrapper for BackendFunctionsService
/// All methods use Neon PostgreSQL functions
class BackendFunctionsService {
  final Ref ref;

  BackendFunctionsService(this.ref);

  NeonFunctionsService get _neon => ref.read(neonFunctionsServiceProvider);

  /// Find similar and related sources using Neon functions
  Future<List<Map<String, dynamic>>> findRelatedSources({
    required String sourceId,
    int limit = 5,
  }) async {
    return await _neon.getRelatedSources(sourceId, limit: limit);
  }

  /// Get notebook analytics using Neon functions
  Future<Map<String, dynamic>?> generateSummary({
    String? sourceId,
    String? notebookId,
  }) async {
    if (notebookId != null) {
      return await _neon.getNotebookAnalytics(notebookId);
    }
    return null;
  }

  /// Tag management using Neon functions
  Future<Map<String, dynamic>> manageTags({
    required String action,
    String? sourceId,
    String? notebookId,
    List<String>? tagIds,
    String? tagName,
    String? tagColor,
  }) async {
    try {
      if (action == 'create' && tagName != null) {
        final tagId =
            await _neon.getOrCreateTag(tagName, color: tagColor ?? '#3B82F6');
        return {'success': true, 'tagId': tagId};
      } else if (action == 'add' && sourceId != null && tagIds != null) {
        for (final tagId in tagIds) {
          await _neon.addTagToSource(sourceId, tagId);
        }
        return {'success': true};
      } else if (action == 'remove' && sourceId != null && tagIds != null) {
        for (final tagId in tagIds) {
          await _neon.removeTagFromSource(sourceId, tagId);
        }
        return {'success': true};
      }
      return {'success': false, 'error': 'Invalid action'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get popular tags using Neon functions
  Future<List<Map<String, dynamic>>> getSourceTags(String sourceId) async {
    return await _neon.getPopularTags(limit: 20);
  }

  /// Get popular tags using Neon functions
  Future<List<Map<String, dynamic>>> getNotebookTags(String notebookId) async {
    return await _neon.getPopularTags(limit: 20);
  }

  /// Create secure share links using Neon functions
  Future<Map<String, dynamic>?> createShare({
    required String notebookId,
    String accessLevel = 'read',
    int expiresInDays = 7,
  }) async {
    return await _neon.createShareToken(
      notebookId,
      accessLevel: accessLevel,
      expiresInDays: expiresInDays,
    );
  }

  /// List all shares for a notebook using Neon functions
  Future<List<Map<String, dynamic>>> listShares(String notebookId) async {
    return await _neon.listShares(notebookId);
  }

  /// Revoke a share using Neon functions
  Future<bool> revokeShare({
    required String notebookId,
    required String shareToken,
  }) async {
    return await _neon.revokeShare(notebookId, shareToken);
  }

  /// Bulk delete sources using Neon functions
  Future<bool> bulkDelete(List<String> sourceIds) async {
    final count = await _neon.bulkDeleteSources(sourceIds);
    return count > 0;
  }

  /// Bulk add tags to sources using Neon functions
  Future<bool> bulkAddTags(List<String> sourceIds, List<String> tagIds) async {
    final count = await _neon.bulkAddTags(sourceIds, tagIds);
    return count > 0;
  }

  /// Bulk remove tags from sources using Neon functions
  Future<bool> bulkRemoveTags(
      List<String> sourceIds, List<String> tagIds) async {
    final count = await _neon.bulkRemoveTags(sourceIds, tagIds);
    return count > 0;
  }

  /// Bulk move sources to notebook using Neon functions
  Future<bool> bulkMoveToNotebook(
      List<String> sourceIds, String targetNotebookId) async {
    final count = await _neon.bulkMoveSources(sourceIds, targetNotebookId);
    return count > 0;
  }

  /// Bulk generate summaries (handled by AI provider)
  Future<bool> bulkGenerateSummaries(List<String> sourceIds) async {
    // This would use Gemini AI, not a database function
    return false;
  }

  /// Test Neon connection
  Future<bool> testConnection() async {
    try {
      await _neon.getUserStats();
      return true;
    } catch (e) {
      return false;
    }
  }
}
