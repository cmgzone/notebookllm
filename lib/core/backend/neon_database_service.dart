// STUB FILE - Database operations now handled by backend API
// This file provides backwards compatibility for files that haven't been migrated yet

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

/// Stub provider for backwards compatibility
final neonDatabaseServiceProvider = Provider<NeonDatabaseService>((ref) {
  return NeonDatabaseService();
});

/// Stub class - all operations are now handled by the backend API
/// See lib/core/api/api_service.dart for the new implementation
class NeonDatabaseService {
  bool get isInitialized => true;

  Future<void> initialize() async {
    debugPrint(
        '⚠️ NeonDatabaseService.initialize() called - using API service instead');
  }

  Future<List<Map<String, dynamic>>> query(String sql,
      [Map<String, dynamic>? params]) async {
    debugPrint(
        '⚠️ NeonDatabaseService.query() called - use ApiService instead');
    return [];
  }

  Future<void> execute(String sql, [Map<String, dynamic>? params]) async {
    debugPrint(
        '⚠️ NeonDatabaseService.execute() called - use ApiService instead');
  }

  Future<Map<String, dynamic>?> getUser(String id) async {
    return null;
  }

  Future<void> createUser(
      {required String id, required String email, String? name}) async {}
  Future<void> createNotebook(
      {required String id,
      required String userId,
      required String title,
      String? description}) async {}
  Future<void> deleteNotebook(String id) async {}
  Future<void> updateNotebook(
      {required String id, String? title, String? coverImage}) async {}
  Future<void> saveSourceWithMedia(String id, String notebookId, String type,
      String title, String? content, String? url, dynamic mediaBytes) async {}
  Future<dynamic> getSourceMedia(String sourceId) async => null;
  Future<List<Map<String, dynamic>>> getOnboardingScreens() async => [];
  Future<String?> getPrivacyPolicy() async => null;
  Future<bool> hasChunks(String sourceId) async => false;
  Future<List<Map<String, dynamic>>> getChunks(String sourceId) async => [];
  Future<void> close() async {}
}
