import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref);
});

class ApiService {
  final Ref ref; // Added this line
  ApiService(this.ref); // Added this constructor

  // static const String _baseUrl = 'http://localhost:3000/api';
  static const String _baseUrl = 'https://notebookllm-ufj7.onrender.com/api';
  static const String _tokenKey = 'auth_token';
  static const _storage = FlutterSecureStorage();

  String? _token;

  // Get stored token
  Future<String?> getToken() async {
    _token ??= await _storage.read(key: _tokenKey);
    return _token;
  }

  // Store token
  Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  // Clear token
  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  // Get headers with auth
  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Generic GET request
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic PUT request
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic DELETE request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl$endpoint'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else if (response.statusCode == 401) {
      // Clear invalid token
      clearToken();
      throw Exception('Unauthorized - please login again');
    } else {
      throw Exception(
          body['error'] ?? 'Request failed: ${response.statusCode}');
    }
  }

  // ============ AUTH ENDPOINTS ============

  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await post('/auth/signup', {
      'email': email,
      'password': password,
      if (displayName != null) 'displayName': displayName,
    });

    // Store token
    if (response['token'] != null) {
      await setToken(response['token']);
    }

    return response;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await post('/auth/login', {
      'email': email,
      'password': password,
    });

    // Store token
    if (response['token'] != null) {
      await setToken(response['token']);
    }

    return response;
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    return await get('/auth/me');
  }

  Future<void> requestPasswordReset(String email) async {
    await post('/auth/forgot-password', {'email': email});
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await post('/auth/reset-password', {
      'token': token,
      'newPassword': newPassword,
    });
  }

  Future<void> deleteAccount(String password) async {
    await post('/auth/delete-account', {'password': password});
  }

  Future<void> enableTwoFactor() async {
    await post('/auth/2fa/enable', {});
  }

  Future<void> disableTwoFactor(String password) async {
    await post('/auth/2fa/disable', {'password': password});
  }

  Future<void> verifyTwoFactor(String code) async {
    await post('/auth/2fa/verify', {'code': code});
  }

  Future<void> resendTwoFactorCode(String userId) async {
    await post('/auth/2fa/resend', {'userId': userId});
  }

  Future<void> resendVerification() async {
    await post('/auth/resend-verification', {});
  }

  Future<void> verifyEmail(String token) async {
    await post('/auth/verify-email', {'token': token});
  }

  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    await put('/auth/profile', {
      if (displayName != null) 'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await post('/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  // ================= NOTEBOOKS ============

  Future<List<Map<String, dynamic>>> getNotebooks() async {
    final response = await get('/notebooks');
    return List<Map<String, dynamic>>.from(response['notebooks'] ?? []);
  }

  Future<Map<String, dynamic>> getNotebook(String id) async {
    final response = await get('/notebooks/$id');
    return response['notebook'];
  }

  Future<Map<String, dynamic>> createNotebook({
    required String title,
    String? description,
    String? coverImage,
  }) async {
    final response = await post('/notebooks', {
      'title': title,
      if (description != null) 'description': description,
      if (coverImage != null) 'coverImage': coverImage,
    });
    return response['notebook'];
  }

  Future<Map<String, dynamic>> updateNotebook(
    String id, {
    String? title,
    String? description,
    String? coverImage,
  }) async {
    final response = await put('/notebooks/$id', {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (coverImage != null) 'coverImage': coverImage,
    });
    return response['notebook'];
  }

  Future<void> deleteNotebook(String id) async {
    await delete('/notebooks/$id');
  }

  // ============ SOURCES ============

  Future<List<Map<String, dynamic>>> getSourcesForNotebook(
    String notebookId,
  ) async {
    final response = await get('/sources/notebook/$notebookId');
    return List<Map<String, dynamic>>.from(response['sources'] ?? []);
  }

  Future<Map<String, dynamic>> getSource(String id) async {
    final response = await get('/sources/$id');
    return response['source'];
  }

  Future<Map<String, dynamic>> createSource({
    required String notebookId,
    required String type,
    required String title,
    String? content,
    String? url,
  }) async {
    final response = await post('/sources', {
      'notebookId': notebookId,
      'type': type,
      'title': title,
      if (content != null) 'content': content,
      if (url != null) 'url': url,
    });
    return response['source'];
  }

  Future<Map<String, dynamic>> updateSource(
    String id, {
    String? title,
    String? content,
    String? url,
  }) async {
    final response = await put('/sources/$id', {
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (url != null) 'url': url,
    });
    return response['source'];
  }

  Future<void> deleteSource(String id) async {
    await delete('/sources/$id');
  }

  // Search sources
  Future<List<Map<String, dynamic>>> searchSources(String query,
      {int limit = 20}) async {
    final response = await post('/sources/search', {
      'query': query,
      'limit': limit,
    });
    return List<Map<String, dynamic>>.from(response['sources'] ?? []);
  }

  // ============ BULK OPERATIONS ============

  Future<int> bulkDeleteSources(List<String> ids) async {
    final response = await post('/sources/bulk/delete', {'ids': ids});
    return response['count'] as int? ?? 0;
  }

  Future<int> bulkMoveSources(List<String> ids, String targetNotebookId) async {
    final response = await post('/sources/bulk/move', {
      'ids': ids,
      'targetNotebookId': targetNotebookId,
    });
    return response['count'] as int? ?? 0;
  }

  Future<int> bulkAddTagsToSources(
      List<String> sourceIds, List<String> tagIds) async {
    final response = await post('/sources/bulk/tags/add', {
      'sourceIds': sourceIds,
      'tagIds': tagIds,
    });
    return response['count'] as int? ?? 0;
  }

  Future<int> bulkRemoveTagsFromSources(
      List<String> sourceIds, List<String> tagIds) async {
    final response = await post('/sources/bulk/tags/remove', {
      'sourceIds': sourceIds,
      'tagIds': tagIds,
    });
    return response['count'] as int? ?? 0;
  }

  // ============ CHUNKS ============

  Future<List<Map<String, dynamic>>> getChunksForSource(String sourceId) async {
    final response = await get('/chunks/source/$sourceId');
    return List<Map<String, dynamic>>.from(response['chunks'] ?? []);
  }

  Future<void> createChunksBulk(
    String sourceId,
    List<Map<String, dynamic>> chunks,
  ) async {
    await post('/chunks/bulk', {
      'sourceId': sourceId,
      'chunks': chunks,
    });
  }

  Future<void> deleteChunksForSource(String sourceId) async {
    await delete('/chunks/source/$sourceId');
  }

  Future<List<Map<String, dynamic>>> searchChunks(
    String notebookId,
    String query, {
    int limit = 10,
  }) async {
    final response = await post('/chunks/search', {
      'notebookId': notebookId,
      'query': query,
      'limit': limit,
    });
    return List<Map<String, dynamic>>.from(response['chunks'] ?? []);
  }

  // ============ TAGS ============

  Future<List<Map<String, dynamic>>> getTags() async {
    final response = await get('/tags');
    return List<Map<String, dynamic>>.from(response['tags'] ?? []);
  }

  Future<List<Map<String, dynamic>>> getTagsForNotebook(
      String notebookId) async {
    final response = await get('/tags/notebook/$notebookId');
    return List<Map<String, dynamic>>.from(response['tags'] ?? []);
  }

  Future<Map<String, dynamic>> createTag({
    required String name,
    required String color,
  }) async {
    final response = await post('/tags', {
      'name': name,
      'color': color,
    });
    return response['tag'];
  }

  Future<Map<String, dynamic>> updateTag(
    String id, {
    String? name,
    String? color,
  }) async {
    final response = await put('/tags/$id', {
      if (name != null) 'name': name,
      if (color != null) 'color': color,
    });
    return response['tag'];
  }

  Future<void> deleteTag(String id) async {
    await delete('/tags/$id');
  }

  Future<void> addTagToNotebook(String notebookId, String tagId) async {
    await post('/tags/notebook/$notebookId/tag/$tagId', {});
  }

  Future<void> removeTagFromNotebook(String notebookId, String tagId) async {
    await delete('/tags/notebook/$notebookId/tag/$tagId');
  }

  Future<void> addTagToSource(String sourceId, String tagId) async {
    await post('/tags/source/$sourceId/tag/$tagId', {});
  }

  Future<void> removeTagFromSource(String sourceId, String tagId) async {
    await delete('/tags/source/$sourceId/tag/$tagId');
  }

  Future<List<Map<String, dynamic>>> getPopularTags({int limit = 10}) async {
    final response = await get('/tags/popular?limit=$limit');
    return List<Map<String, dynamic>>.from(response['tags'] ?? []);
  }

  // ============ ANALYTICS ============

  Future<Map<String, dynamic>> getUserStats() async {
    final response = await get('/analytics/user-stats');
    return response['stats'] ?? {};
  }

  Future<Map<String, dynamic>> getNotebookAnalytics(String notebookId) async {
    final response = await get('/analytics/notebook/$notebookId');
    return response['analytics'] ?? {};
  }

  // ============ MEDIA ============

  Future<Uint8List?> getMediaBytes(String sourceId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/media/$sourceId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      developer.log('Error fetching media bytes: $e', name: 'ApiService');
      return null;
    }
  }

  Future<int> getMediaSizeStats() async {
    final response = await get('/media/stats/size');
    return response['size'] as int? ?? 0;
  }

  // ============ SHARING ============

  Future<Map<String, dynamic>> createShareToken(String notebookId,
      {String? accessLevel, int? expiresInDays}) async {
    final response = await post('/sharing/create', {
      'notebookId': notebookId,
      if (accessLevel != null) 'accessLevel': accessLevel,
      if (expiresInDays != null) 'expiresInDays': expiresInDays,
    });
    return response['share'];
  }

  Future<Map<String, dynamic>> validateShareToken(String token) async {
    final response = await get('/sharing/validate/$token');
    return response['validation'];
  }

  Future<List<Map<String, dynamic>>> listShares(String notebookId) async {
    final response = await get('/sharing/list/$notebookId');
    return List<Map<String, dynamic>>.from(response['shares'] ?? []);
  }

  Future<bool> revokeShare(String notebookId, String token) async {
    final response = await delete('/sharing/revoke/$notebookId/$token');
    return response['revoked'] as bool? ?? false;
  }

  // ============ RECOMMENDATIONS ============

  Future<List<Map<String, dynamic>>> getRelatedSources(String sourceId) async {
    final response = await get('/recommendations/$sourceId');
    return List<Map<String, dynamic>>.from(response['sources'] ?? []);
  }

  // ============ AI ============

  Future<String> chatWithAI({
    required List<Map<String, String>> messages,
    String provider = 'gemini',
    String? model,
  }) async {
    final response = await post('/ai/chat', {
      'messages': messages,
      'provider': provider,
      if (model != null) 'model': model,
    });
    return response['response'];
  }

  Future<String> generateSummary({
    required String content,
    String provider = 'gemini',
  }) async {
    final response = await post('/ai/summary', {
      'content': content,
      'provider': provider,
    });
    return response['summary'];
  }

  Future<List<String>> generateQuestions({
    required String notebookId,
    int count = 5,
  }) async {
    final response = await post('/ai/questions', {
      'notebookId': notebookId,
      'count': count,
    });
    return List<String>.from(response['questions'] ?? []);
  }

  Future<String> generateNotebookSummary(String notebookId) async {
    final response = await post('/ai/notebook-summary', {
      'notebookId': notebookId,
    });
    return response['summary'];
  }

  // ============ SUBSCRIPTIONS ============

  Future<Map<String, dynamic>?> getSubscription() async {
    final response = await get('/subscriptions/me');
    return response['subscription'];
  }

  Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    final response = await get('/subscriptions/plans');
    return List<Map<String, dynamic>>.from(response['plans'] ?? []);
  }

  Future<Map<String, dynamic>> getCreditBalance() async {
    return await get('/subscriptions/credits');
  }

  Future<List<Map<String, dynamic>>> getTransactionHistory(
      {int limit = 50}) async {
    final response = await get('/subscriptions/transactions?limit=$limit');
    return List<Map<String, dynamic>>.from(response['transactions'] ?? []);
  }

  Future<List<Map<String, dynamic>>> getCreditPackages() async {
    final response = await get('/subscriptions/packages');
    return List<Map<String, dynamic>>.from(response['packages'] ?? []);
  }

  Future<Map<String, dynamic>> consumeCredits({
    required int amount,
    required String feature,
    Map<String, dynamic>? metadata,
  }) async {
    return await post('/subscriptions/consume', {
      'amount': amount,
      'feature': feature,
      if (metadata != null) 'metadata': metadata,
    });
  }

  Future<void> createSubscription() async {
    await post('/subscriptions/create', {});
  }

  Future<Map<String, dynamic>> upgradePlan({
    required String planId,
    required String transactionId,
  }) async {
    return await post('/subscriptions/upgrade', {
      'planId': planId,
      'transactionId': transactionId,
    });
  }

  // ============ ADMIN ============

  Future<List<Map<String, dynamic>>> getAIModels() async {
    final response = await get('/admin/models');
    return List<Map<String, dynamic>>.from(response['models'] ?? []);
  }

  Future<Map<String, dynamic>> addAIModel(Map<String, dynamic> model) async {
    final response = await post('/admin/models', model);
    return response['model'];
  }

  Future<Map<String, dynamic>> updateAIModel(
      String id, Map<String, dynamic> model) async {
    final response = await put('/admin/models/$id', model);
    return response['model'];
  }

  Future<void> deleteAIModel(String id) async {
    await delete('/admin/models/$id');
  }

  Future<List<Map<String, dynamic>>> getApiKeys() async {
    final response = await get('/admin/api-keys');
    return List<Map<String, dynamic>>.from(response['apiKeys'] ?? []);
  }

  Future<void> setApiKey({
    required String service,
    required String apiKey,
    String? description,
  }) async {
    await post('/admin/api-keys', {
      'service': service,
      'apiKey': apiKey,
      if (description != null) 'description': description,
    });
  }

  Future<void> deleteApiKey(String service) async {
    await delete('/admin/api-keys/$service');
  }

  Future<List<Map<String, dynamic>>> getAdminPlans() async {
    final response = await get('/admin/plans');
    return List<Map<String, dynamic>>.from(response['plans'] ?? []);
  }

  Future<Map<String, dynamic>> updateAdminPlan(
      String id, Map<String, dynamic> updates) async {
    final response = await put('/admin/plans/$id', updates);
    return response['plan'];
  }

  Future<List<Map<String, dynamic>>> getOnboardingScreens() async {
    final response = await get('/admin/onboarding');
    return List<Map<String, dynamic>>.from(response['screens'] ?? []);
  }

  Future<void> updateOnboardingScreens(
      List<Map<String, dynamic>> screens) async {
    await put('/admin/onboarding', {'screens': screens});
  }

  Future<String?> getPrivacyPolicy() async {
    final response = await get('/admin/privacy-policy');
    return response['content'] as String?;
  }

  Future<void> updatePrivacyPolicy(String content) async {
    await put('/admin/privacy-policy', {'content': content});
  }

  // ============ SOURCE CHUNKS ============

  Future<bool> sourceHasChunks(String sourceId) async {
    final chunks = await getChunksForSource(sourceId);
    return chunks.isNotEmpty;
  }

  // ============ GAMIFICATION ============

  Future<Map<String, dynamic>> getGamificationStats() async {
    final response = await get('/gamification/stats');
    return response['stats'];
  }

  Future<Map<String, dynamic>> trackActivity({
    required String field,
    int? increment,
    dynamic value,
  }) async {
    return await post('/gamification/track', {
      'field': field,
      if (increment != null) 'increment': increment,
      if (value != null) 'value': value,
    });
  }

  Future<List<Map<String, dynamic>>> getAchievements() async {
    final response = await get('/gamification/achievements');
    return List<Map<String, dynamic>>.from(response['achievements'] ?? []);
  }

  Future<Map<String, dynamic>> updateAchievementProgress({
    required String achievementId,
    required int value,
    required bool isUnlocked,
  }) async {
    final response = await post('/gamification/achievements/progress', {
      'achievementId': achievementId,
      'value': value,
      'isUnlocked': isUnlocked,
    });
    return response['achievement'];
  }

  Future<List<Map<String, dynamic>>> getDailyChallenges() async {
    final response = await get('/gamification/challenges');
    return List<Map<String, dynamic>>.from(response['challenges'] ?? []);
  }

  Future<List<Map<String, dynamic>>> batchUpdateChallenges(
      List<Map<String, dynamic>> challenges) async {
    final response = await post('/gamification/challenges/batch', {
      'challenges': challenges,
    });
    return List<Map<String, dynamic>>.from(response['challenges'] ?? []);
  }

  // ============ STUDY TOOLS ============

  // Flashcards
  Future<List<Map<String, dynamic>>> getFlashcardDecks() async {
    final response = await get('/study/flashcards/decks');
    return List<Map<String, dynamic>>.from(response['decks'] ?? []);
  }

  Future<Map<String, dynamic>> createFlashcardDeck({
    String? id,
    required String notebookId,
    String? sourceId,
    required String title,
    List<Map<String, dynamic>>? cards,
  }) async {
    final response = await post('/study/flashcards/decks', {
      if (id != null) 'id': id,
      'notebookId': notebookId,
      if (sourceId != null) 'sourceId': sourceId,
      'title': title,
      if (cards != null) 'cards': cards,
    });
    return response['deck'];
  }

  Future<void> deleteFlashcardDeck(String id) async {
    await delete('/study/flashcards/decks/$id');
  }

  Future<Map<String, dynamic>> updateFlashcardProgress({
    required String cardId,
    required bool wasCorrect,
  }) async {
    return await post('/study/flashcards/$cardId/progress', {
      'wasCorrect': wasCorrect,
    });
  }

  Future<List<Map<String, dynamic>>> getFlashcardsForDeck(String deckId) async {
    final response = await get('/study/flashcards/decks/$deckId');
    return List<Map<String, dynamic>>.from(response['flashcards'] ?? []);
  }

  Future<List<Map<String, dynamic>>> syncFlashcards({
    required String deckId,
    required List<Map<String, dynamic>> flashcards,
  }) async {
    final response = await post('/study/flashcards/batch', {
      'deckId': deckId,
      'flashcards': flashcards,
    });
    return List<Map<String, dynamic>>.from(response['flashcards'] ?? []);
  }

  // Quizzes
  Future<List<Map<String, dynamic>>> getQuizzes() async {
    final response = await get('/study/quizzes');
    return List<Map<String, dynamic>>.from(response['quizzes'] ?? []);
  }

  Future<Map<String, dynamic>> createQuiz({
    String? id,
    required String notebookId,
    String? sourceId,
    required String title,
    required List<Map<String, dynamic>> questions,
  }) async {
    final response = await post('/study/quizzes', {
      if (id != null) 'id': id,
      'notebookId': notebookId,
      if (sourceId != null) 'sourceId': sourceId,
      'title': title,
      'questions': questions,
    });
    return response['quiz'];
  }

  Future<Map<String, dynamic>> getQuizDetails(String quizId) async {
    return await get('/study/quizzes/$quizId');
  }

  Future<void> deleteQuiz(String id) async {
    await delete('/study/quizzes/$id');
  }

  Future<void> recordQuizAttempt({
    required String quizId,
    required int score,
    required int total,
  }) async {
    await post('/study/quizzes/$quizId/attempt', {
      'score': score,
      'total': total,
    });
  }

  // Mind Maps
  Future<List<Map<String, dynamic>>> getMindMaps() async {
    final response = await get('/study/mindmaps');
    return List<Map<String, dynamic>>.from(response['mindMaps'] ?? []);
  }

  Future<Map<String, dynamic>> saveMindMap({
    String? id,
    required String notebookId,
    String? sourceId,
    required String title,
    required Map<String, dynamic> rootNode,
    String? textContent,
  }) async {
    final response = await post('/study/mindmaps', {
      if (id != null) 'id': id,
      'notebookId': notebookId,
      if (sourceId != null) 'sourceId': sourceId,
      'title': title,
      'rootNode': rootNode,
      if (textContent != null) 'textContent': textContent,
    });
    return response['mindMap'];
  }

  // Infographics
  Future<List<Map<String, dynamic>>> getInfographics() async {
    final response = await get('/study/infographics');
    return List<Map<String, dynamic>>.from(response['infographics'] ?? []);
  }

  Future<Map<String, dynamic>> saveInfographic({
    String? id,
    required String notebookId,
    String? sourceId,
    required String title,
    String? imageUrl,
    String? imageBase64,
    String? style,
  }) async {
    final response = await post('/study/infographics', {
      if (id != null) 'id': id,
      'notebookId': notebookId,
      if (sourceId != null) 'sourceId': sourceId,
      'title': title,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      if (style != null) 'style': style,
    });
    return response['infographic'];
  }

  // ============ EBOOKS ============

  Future<List<Map<String, dynamic>>> getEbookProjects() async {
    final response = await get('/ebooks');
    return List<Map<String, dynamic>>.from(response['projects'] ?? []);
  }

  Future<Map<String, dynamic>> saveEbookProject({
    String? id,
    required String notebookId,
    required String title,
    required String topic,
    required String targetAudience,
    required Map<String, dynamic> branding,
    required String selectedModel,
    String status = 'draft',
    String? coverImage,
  }) async {
    final response = await post('/ebooks', {
      if (id != null) 'id': id,
      'notebookId': notebookId,
      'title': title,
      'topic': topic,
      'targetAudience': targetAudience,
      'branding': branding,
      'selectedModel': selectedModel,
      'status': status,
      if (coverImage != null) 'coverImage': coverImage,
    });
    return response['project'];
  }

  Future<void> deleteEbookProject(String id) async {
    await delete('/ebooks/$id');
  }

  Future<List<Map<String, dynamic>>> getEbookChapters(String projectId) async {
    final response = await get('/ebooks/$projectId/chapters');
    return List<Map<String, dynamic>>.from(response['chapters'] ?? []);
  }

  Future<List<Map<String, dynamic>>> syncEbookChapters({
    required String projectId,
    required List<Map<String, dynamic>> chapters,
  }) async {
    final response = await post('/ebooks/$projectId/chapters/batch', {
      'chapters': chapters,
    });
    return List<Map<String, dynamic>>.from(response['chapters'] ?? []);
  }

  // ============ RESEARCH ============

  Future<List<Map<String, dynamic>>> getResearchSessions() async {
    final response = await get('/research/sessions');
    return List<Map<String, dynamic>>.from(response['sessions'] ?? []);
  }

  Future<Map<String, dynamic>> saveResearchSession({
    String? id,
    required String notebookId,
    required String query,
    String? report,
    List<Map<String, dynamic>>? sources,
  }) async {
    final response = await post('/research/sessions', {
      if (id != null) 'id': id,
      'notebookId': notebookId,
      'query': query,
      if (report != null) 'report': report,
      if (sources != null) 'sources': sources,
    });
    return response['session'];
  }

  // ============ SEARCH PROXY ============

  Future<Map<String, dynamic>> searchProxy({
    required String query,
    String type = 'search',
    int num = 10,
    int page = 1,
  }) async {
    return await post('/search/proxy', {
      'query': query,
      'type': type,
      'num': num,
      'page': page,
    });
  }

  // ============ TUTOR SESSIONS ============

  Future<List<Map<String, dynamic>>> getTutorSessions() async {
    final response = await get('/features/tutor/sessions');
    return List<Map<String, dynamic>>.from(response['sessions'] ?? []);
  }

  Future<Map<String, dynamic>> createTutorSession(
      Map<String, dynamic> session) async {
    final response = await post('/features/tutor/sessions', session);
    return response['session'];
  }

  Future<Map<String, dynamic>> updateTutorSession(
      String id, Map<String, dynamic> updates) async {
    final response = await put('/features/tutor/sessions/$id', updates);
    return response['session'];
  }

  Future<void> deleteTutorSession(String id) async {
    await delete('/features/tutor/sessions/$id');
  }

  // ============ LANGUAGE LEARNING SESSIONS ============

  Future<List<Map<String, dynamic>>> getLanguageSessions() async {
    final response = await get('/features/language/sessions');
    return List<Map<String, dynamic>>.from(response['sessions'] ?? []);
  }

  Future<Map<String, dynamic>> createLanguageSession(
      Map<String, dynamic> session) async {
    final response = await post('/features/language/sessions', session);
    return response['session'];
  }

  Future<Map<String, dynamic>> updateLanguageSession(
      String id, Map<String, dynamic> updates) async {
    final response = await put('/features/language/sessions/$id', updates);
    return response['session'];
  }

  Future<void> deleteLanguageSession(String id) async {
    await delete('/features/language/sessions/$id');
  }

  // ============ STORY GENERATOR ============

  Future<List<Map<String, dynamic>>> getStories() async {
    final response = await get('/features/stories');
    return List<Map<String, dynamic>>.from(response['stories'] ?? []);
  }

  Future<Map<String, dynamic>> createStory(Map<String, dynamic> story) async {
    final response = await post('/features/stories', story);
    return response['story'];
  }

  Future<void> deleteStory(String id) async {
    await delete('/features/stories/$id');
  }

  // ============ MEAL PLANNER ============

  Future<List<Map<String, dynamic>>> getMealPlans() async {
    final response = await get('/features/meals/plans');
    return List<Map<String, dynamic>>.from(response['plans'] ?? []);
  }

  Future<Map<String, dynamic>> saveMealPlan(Map<String, dynamic> plan) async {
    final response = await post('/features/meals/plans', plan);
    return response['plan'];
  }

  Future<List<Map<String, dynamic>>> getSavedMeals() async {
    final response = await get('/features/meals/saved');
    return List<Map<String, dynamic>>.from(response['meals'] ?? []);
  }

  Future<Map<String, dynamic>> saveMeal(Map<String, dynamic> meal) async {
    final response = await post('/features/meals/saved', meal);
    return response['meal'];
  }

  Future<void> deleteSavedMeal(String id) async {
    await delete('/features/meals/saved/$id');
  }

  // ============ AUDIO OVERVIEWS ============

  Future<List<Map<String, dynamic>>> getAudioOverviews() async {
    final response = await get('/features/audio/overviews');
    return List<Map<String, dynamic>>.from(response['overviews'] ?? []);
  }

  Future<Map<String, dynamic>> saveAudioOverview(
      Map<String, dynamic> overview) async {
    final response = await post('/features/audio/overviews', overview);
    return response['overview'];
  }

  Future<void> deleteAudioOverview(String id) async {
    await delete('/features/audio/overviews/$id');
  }
}
