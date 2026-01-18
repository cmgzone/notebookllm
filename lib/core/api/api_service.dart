import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref);
});

class ApiService {
  final Ref ref; // Added this line
  ApiService(this.ref); // Added this constructor

  // static const String _baseUrl = 'http://localhost:3001/api';
  static const String _baseUrl = 'https://backend.taskiumnetwork.com/api';
  static const String _tokenKey = 'auth_token';
  static const String _tokenBackupKey =
      'auth_token_backup'; // Backup in SharedPreferences

  // Use consistent secure storage configuration across the app
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String? _token;

  // Get stored token - tries secure storage first, then SharedPreferences as fallback
  Future<String?> getToken() async {
    if (_token != null) {
      developer.log('[API] Using cached token', name: 'ApiService');
      return _token;
    }

    // Try secure storage first
    try {
      final storedToken = await _storage.read(key: _tokenKey);
      if (storedToken != null && storedToken.isNotEmpty) {
        developer.log(
            '[API] Read token from secure storage: exists (${storedToken.length} chars)',
            name: 'ApiService');
        _token = storedToken;
        return _token;
      }
    } catch (e) {
      developer.log('[API] Secure storage read error: $e', name: 'ApiService');
    }

    // Fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupToken = prefs.getString(_tokenBackupKey);
      if (backupToken != null && backupToken.isNotEmpty) {
        developer.log(
            '[API] Read token from SharedPreferences backup: exists (${backupToken.length} chars)',
            name: 'ApiService');
        _token = backupToken;
        // Try to restore to secure storage
        try {
          await _storage.write(key: _tokenKey, value: backupToken);
          developer.log('[API] Restored token to secure storage',
              name: 'ApiService');
        } catch (_) {}
        return _token;
      }
    } catch (e) {
      developer.log('[API] SharedPreferences read error: $e',
          name: 'ApiService');
    }

    developer.log('[API] No token found in any storage', name: 'ApiService');
    return null;
  }

  // Store token - saves to both secure storage and SharedPreferences
  Future<void> setToken(String token) async {
    developer.log('[API] Storing token (${token.length} chars)',
        name: 'ApiService');
    _token = token;

    // Save to secure storage
    try {
      await _storage.write(key: _tokenKey, value: token);
      developer.log('[API] Token stored in secure storage', name: 'ApiService');
    } catch (e) {
      developer.log('[API] Secure storage write error: $e', name: 'ApiService');
    }

    // Also save to SharedPreferences as backup
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenBackupKey, token);
      developer.log('[API] Token stored in SharedPreferences backup',
          name: 'ApiService');
    } catch (e) {
      developer.log('[API] SharedPreferences write error: $e',
          name: 'ApiService');
    }
  }

  // Clear token - clears from both storages
  Future<void> clearToken() async {
    developer.log('[API] Clearing token', name: 'ApiService');
    _token = null;

    try {
      await _storage.delete(key: _tokenKey);
    } catch (e) {
      developer.log('[API] Secure storage delete error: $e',
          name: 'ApiService');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenBackupKey);
    } catch (e) {
      developer.log('[API] SharedPreferences delete error: $e',
          name: 'ApiService');
    }
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
      final headers = await _getHeaders();
      developer.log('[API] GET $endpoint - headers: ${headers.keys.toList()}',
          name: 'ApiService');
      developer.log(
          '[API] GET $endpoint - has auth: ${headers.containsKey('Authorization')}',
          name: 'ApiService');

      final response = await http
          .get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
              'Request timed out. Please check your connection and try again.');
        },
      );

      developer.log('[API] GET $endpoint - status: ${response.statusCode}',
          name: 'ApiService');

      if (response.statusCode == 401) {
        developer.log(
            '[API] GET $endpoint - 401 UNAUTHORIZED! Token may be invalid or expired',
            name: 'ApiService');
      }

      return _handleResponse(response);
    } catch (e) {
      developer.log('[API] GET $endpoint - ERROR: $e', name: 'ApiService');
      // Re-throw if it's already an Exception with a message, otherwise wrap it
      if (e is Exception) {
        rethrow;
      }
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
      // Re-throw if it's already an Exception with a message, otherwise wrap it
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  // Generic PATCH request
  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
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
      // Re-throw if it's already an Exception with a message, otherwise wrap it
      if (e is Exception) {
        rethrow;
      }
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
      // Re-throw if it's already an Exception with a message, otherwise wrap it
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  // Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response,
      {bool clearTokenOn401 = false}) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else if (response.statusCode == 401) {
      developer.log(
          '[API] Got 401 response (missing token), clearTokenOn401=$clearTokenOn401',
          name: 'ApiService');
      if (clearTokenOn401) {
        clearToken();
      }
      // Check for GitHub-specific not connected error
      final errorCode = body['error'];
      if (errorCode == 'GITHUB_NOT_CONNECTED') {
        throw Exception(body['message'] ??
            'GitHub account not connected. Please connect your GitHub account in Settings.');
      }
      throw Exception('Unauthorized - please login again');
    } else if (response.statusCode == 403) {
      developer.log(
          '[API] Got 403 response (invalid/expired token), clearTokenOn401=$clearTokenOn401',
          name: 'ApiService');
      // 403 means token is invalid or expired - don't auto-clear, let auth system handle it
      throw Exception('Session expired - please login again');
    } else if (response.statusCode == 429) {
      // Rate limit error
      final message =
          body['message'] ?? 'Rate limit exceeded. Please try again later.';
      throw Exception(message);
    } else {
      // For other errors, prefer the message field over the error code
      final message = body['message'] ??
          body['error'] ??
          'Request failed: ${response.statusCode}';
      throw Exception(message);
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
    bool rememberMe = false,
  }) async {
    final response = await post('/auth/login', {
      'email': email,
      'password': password,
      'rememberMe': rememberMe,
    });

    // Store token
    if (response['token'] != null) {
      await setToken(response['token']);
    }

    return response;
  }

  Future<Map<String, dynamic>> getCurrentUser(
      {bool clearTokenOn401 = true}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response, clearTokenOn401: clearTokenOn401);
    } catch (e) {
      throw Exception('Network error: $e');
    }
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

  Future<void> updateProfile(
      {String? displayName, String? avatarUrl, String? coverUrl}) async {
    await put('/auth/profile', {
      if (displayName != null) 'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (coverUrl != null) 'coverUrl': coverUrl,
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
    final token = await getToken();
    developer.log(
        '[API] getNotebooks - token exists: ${token != null}, length: ${token?.length ?? 0}',
        name: 'ApiService');

    if (token == null) {
      developer.log('[API] getNotebooks - NO TOKEN! User not authenticated',
          name: 'ApiService');
      return [];
    }

    developer.log('[API] Fetching notebooks...', name: 'ApiService');
    final response = await get('/notebooks');
    developer.log('[API] Notebooks response: $response', name: 'ApiService');
    final notebooks =
        List<Map<String, dynamic>>.from(response['notebooks'] ?? []);
    developer.log('[API] Parsed ${notebooks.length} notebooks',
        name: 'ApiService');
    return notebooks;
  }

  Future<Map<String, dynamic>> getNotebook(String id) async {
    final response = await get('/notebooks/$id');
    return response['notebook'];
  }

  Future<Map<String, dynamic>> createNotebook({
    required String title,
    String? description,
    String? coverImage,
    String? category,
  }) async {
    final response = await post('/notebooks', {
      'title': title,
      if (description != null) 'description': description,
      if (coverImage != null) 'coverImage': coverImage,
      if (category != null) 'category': category,
    });
    return response['notebook'];
  }

  Future<Map<String, dynamic>> updateNotebook(
    String id, {
    String? title,
    String? description,
    String? coverImage,
    String? category,
  }) async {
    final response = await put('/notebooks/$id', {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (coverImage != null) 'coverImage': coverImage,
      if (category != null) 'category': category,
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
    String? imageUrl,
  }) async {
    final response = await post('/sources', {
      'notebookId': notebookId,
      'type': type,
      'title': title,
      if (content != null) 'content': content,
      if (url != null) 'url': url,
      if (imageUrl != null) 'imageUrl': imageUrl,
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

  Future<Map<String, dynamic>> uploadMediaDirect({
    required String base64Data,
    required String filename,
    String? type,
  }) async {
    return await post('/media/upload-direct', {
      'mediaData': base64Data,
      'filename': filename,
      if (type != null) 'type': type,
    });
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
    required List<Map<String, dynamic>> messages,
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

  Future<String> chatWithVision({
    required String prompt,
    required String base64Image,
    String? notebookId,
  }) async {
    final response = await post('/ai/vision', {
      'prompt': prompt,
      'image': base64Image,
      if (notebookId != null) 'notebookId': notebookId,
    });
    return response['content'] ?? response['response'] ?? '';
  }

  Stream<String> chatWithAIStream({
    required List<Map<String, dynamic>> messages,
    String provider = 'gemini',
    String? model,
  }) async* {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('$_baseUrl/ai/chat/stream');
    final request = http.Request('POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      'messages': messages,
      'provider': provider,
      if (model != null) 'model': model,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Failed to stream: ${response.statusCode}');
      }

      yield* response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) {
            if (line.startsWith('data: ')) {
              final dataStr = line.substring(6);
              if (dataStr == '[DONE]') return null;
              try {
                final json = jsonDecode(dataStr);
                if (json['error'] != null) throw Exception(json['error']);
                return json['text'] as String?;
              } catch (_) {
                return null;
              }
            }
            return null;
          })
          .where((text) => text != null)
          .cast<String>();
    } finally {
      client.close();
    }
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
    developer.log('[API] Calling /subscriptions/me', name: 'ApiService');
    final response = await get('/subscriptions/me');
    developer.log('[API] /subscriptions/me response: $response',
        name: 'ApiService');
    final subscription = response['subscription'];
    developer.log('[API] Subscription data: $subscription', name: 'ApiService');
    return subscription;
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

  Future<Map<String, dynamic>> addCredits({
    required int amount,
    required String packageId,
    required String transactionId,
    String paymentMethod = 'paypal',
  }) async {
    return await post('/subscriptions/add-credits', {
      'amount': amount,
      'packageId': packageId,
      'transactionId': transactionId,
      'paymentMethod': paymentMethod,
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

  // Public endpoint for listing AI models (available to all authenticated users)
  Future<List<Map<String, dynamic>>> getAIModels() async {
    final response = await get('/ai/models');
    return List<Map<String, dynamic>>.from(response['models'] ?? []);
  }

  // ============ CHAT HISTORY ============

  Future<List<Map<String, dynamic>>> getChatHistory(
      {String? notebookId}) async {
    final query = notebookId != null ? '?notebookId=$notebookId' : '';
    final response = await get('/ai/chat/history$query');
    return List<Map<String, dynamic>>.from(response['messages'] ?? []);
  }

  Future<Map<String, dynamic>> saveChatMessage({
    required String role,
    required String content,
    String? notebookId,
  }) async {
    return await post('/ai/chat/message', {
      'role': role,
      'content': content,
      if (notebookId != null) 'notebookId': notebookId,
    });
  }

  // Admin-only endpoints for managing AI models
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
    final deck = response['deck'];
    if (deck == null) {
      throw Exception('Failed to create deck: No deck data returned');
    }
    return deck;
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

  // ============ CLOUD RESEARCH ============

  /// Start cloud-based research (synchronous - waits for completion)
  Future<Map<String, dynamic>> startCloudResearch({
    required String query,
    String depth = 'standard',
    String template = 'general',
    String? notebookId,
  }) async {
    final response = await post('/research/cloud', {
      'query': query,
      'depth': depth,
      'template': template,
      if (notebookId != null) 'notebookId': notebookId,
    });
    return response;
  }

  /// Start background research (async - returns job ID immediately)
  Future<String> startBackgroundResearch({
    required String query,
    String depth = 'standard',
    String template = 'general',
    String? notebookId,
  }) async {
    final response = await post('/research/background', {
      'query': query,
      'depth': depth,
      'template': template,
      if (notebookId != null) 'notebookId': notebookId,
    });
    return response['jobId'];
  }

  /// Get background research job status
  Future<Map<String, dynamic>?> getResearchJobStatus(String jobId) async {
    try {
      final response = await get('/research/jobs/$jobId');
      return response['job'];
    } catch (e) {
      return null;
    }
  }

  /// Get all pending/running research jobs
  Future<List<Map<String, dynamic>>> getResearchJobs() async {
    final response = await get('/research/jobs');
    return List<Map<String, dynamic>>.from(response['jobs'] ?? []);
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

  // ============ VOICE MODELS ============

  Future<List<Map<String, dynamic>>> getVoiceModels() async {
    final response = await get('/voice/models');
    return List<Map<String, dynamic>>.from(response['voices'] ?? []);
  }

  Future<List<Map<String, dynamic>>> getVoiceModelsByProvider(
      String provider) async {
    final response = await get('/voice/models/$provider');
    return List<Map<String, dynamic>>.from(response['voices'] ?? []);
  }

  // ============ SPORTS SOCIAL ============

  // Predictions
  Future<List<Map<String, dynamic>>> getSportsPredictions({
    int limit = 50,
    int offset = 0,
    String? result,
  }) async {
    String query = '/sports/predictions?limit=$limit&offset=$offset';
    if (result != null) query += '&result=$result';
    final response = await get(query);
    return List<Map<String, dynamic>>.from(response['predictions'] ?? []);
  }

  Future<Map<String, dynamic>> createSportsPrediction(
      Map<String, dynamic> prediction) async {
    final response = await post('/sports/predictions', prediction);
    return response['prediction'];
  }

  Future<Map<String, dynamic>> settleSportsPrediction(
      String id, String result) async {
    final response = await put('/sports/predictions/$id/settle', {
      'result': result,
    });
    return response['prediction'];
  }

  // Stats & Leaderboard
  Future<Map<String, dynamic>> getSportsStats() async {
    final response = await get('/sports/stats');
    return response['stats'] ?? {};
  }

  Future<List<Map<String, dynamic>>> getSportsLeaderboard({
    String timeframe = 'all',
    int limit = 50,
  }) async {
    final response =
        await get('/sports/leaderboard?timeframe=$timeframe&limit=$limit');
    return List<Map<String, dynamic>>.from(response['leaderboard'] ?? []);
  }

  // Tipsters
  Future<List<Map<String, dynamic>>> getTipsters() async {
    final response = await get('/sports/tipsters');
    return List<Map<String, dynamic>>.from(response['tipsters'] ?? []);
  }

  Future<Map<String, dynamic>> registerAsTipster(
      Map<String, dynamic> data) async {
    final response = await post('/sports/tipsters/register', data);
    return response['tipster'];
  }

  Future<void> followTipster(String tipsterId) async {
    await post('/sports/tipsters/$tipsterId/follow', {});
  }

  Future<void> unfollowTipster(String tipsterId) async {
    await delete('/sports/tipsters/$tipsterId/follow');
  }

  Future<List<Map<String, dynamic>>> getFollowingTipsters() async {
    final response = await get('/sports/tipsters/following');
    return List<Map<String, dynamic>>.from(response['tipsters'] ?? []);
  }

  // Favorites
  Future<List<Map<String, dynamic>>> getFavoriteTeams() async {
    final response = await get('/sports/favorites');
    return List<Map<String, dynamic>>.from(response['favorites'] ?? []);
  }

  Future<Map<String, dynamic>> addFavoriteTeam(
      Map<String, dynamic> team) async {
    final response = await post('/sports/favorites', team);
    return response['favorite'];
  }

  Future<void> removeFavoriteTeam(String id) async {
    await delete('/sports/favorites/$id');
  }

  // Bankroll
  Future<Map<String, dynamic>> getBankroll({int limit = 50}) async {
    final response = await get('/sports/bankroll?limit=$limit');
    return response;
  }

  Future<Map<String, dynamic>> addBankrollEntry(
      Map<String, dynamic> entry) async {
    final response = await post('/sports/bankroll', entry);
    return response;
  }

  // Betting Slips
  Future<List<Map<String, dynamic>>> getBettingSlips() async {
    final response = await get('/sports/slips');
    return List<Map<String, dynamic>>.from(response['slips'] ?? []);
  }

  Future<Map<String, dynamic>> saveBettingSlip(
      Map<String, dynamic> slip) async {
    final response = await post('/sports/slips', slip);
    return response['slip'];
  }

  Future<void> deleteBettingSlip(String id) async {
    await delete('/sports/slips/$id');
  }

  // ============ SPORTS LIVE DATA (SportRadar) ============

  // Get live matches
  Future<List<Map<String, dynamic>>> getLiveMatches() async {
    final response = await get('/sports/live');
    return List<Map<String, dynamic>>.from(response['matches'] ?? []);
  }

  // Get today's fixtures
  Future<List<Map<String, dynamic>>> getTodayFixtures() async {
    final response = await get('/sports/fixtures/today');
    return List<Map<String, dynamic>>.from(response['matches'] ?? []);
  }

  // Get fixtures by date
  Future<List<Map<String, dynamic>>> getFixturesByDate(String date) async {
    final response = await get('/sports/fixtures/$date');
    return List<Map<String, dynamic>>.from(response['matches'] ?? []);
  }

  // Get match details
  Future<Map<String, dynamic>?> getMatchDetails(String matchId) async {
    final response = await get('/sports/match/$matchId');
    return response['match'];
  }

  // Get match odds
  Future<Map<String, dynamic>?> getMatchOdds(String matchId) async {
    final response = await get('/sports/match/$matchId/odds');
    return response['odds'];
  }

  // Get head-to-head
  Future<Map<String, dynamic>?> getHeadToHead(
      String team1Id, String team2Id) async {
    final response = await get('/sports/h2h/$team1Id/$team2Id');
    return response['h2h'];
  }

  // Get team form
  Future<Map<String, dynamic>?> getTeamForm(String teamId,
      {int limit = 5}) async {
    final response = await get('/sports/team/$teamId/form?limit=$limit');
    return response['form'];
  }

  // Get league standings
  Future<List<Map<String, dynamic>>> getLeagueStandings(String leagueId) async {
    final response = await get('/sports/standings/$leagueId');
    return List<Map<String, dynamic>>.from(response['standings'] ?? []);
  }

  // Get team injuries
  Future<List<Map<String, dynamic>>> getTeamInjuries(String teamId) async {
    final response = await get('/sports/team/$teamId/injuries');
    return List<Map<String, dynamic>>.from(response['injuries'] ?? []);
  }

  // ============ CODING AGENT COMMUNICATION ============

  /// Get all agent notebooks for the current user
  /// Requirements: 4.1
  Future<List<Map<String, dynamic>>> getAgentNotebooks() async {
    final response = await get('/coding-agent/notebooks');
    return List<Map<String, dynamic>>.from(response['notebooks'] ?? []);
  }

  /// Get conversation history for a source
  /// Requirements: 3.5
  Future<Map<String, dynamic>> getSourceConversation(String sourceId) async {
    final response = await get('/coding-agent/conversations/$sourceId');
    return {
      'conversation': response['conversation'],
      'messages': List<Map<String, dynamic>>.from(response['messages'] ?? []),
    };
  }

  /// Send a follow-up message to an agent for a specific source
  /// Requirements: 3.2, 4.2
  ///
  /// For GitHub sources, includes file content and repository context
  /// in the webhook payload to enable contextual code discussions.
  Future<Map<String, dynamic>> sendFollowupMessage(
    String sourceId,
    String message, {
    Map<String, dynamic>? githubContext,
  }) async {
    final body = <String, dynamic>{
      'sourceId': sourceId,
      'message': message,
    };

    // Include GitHub context if provided (Requirements: 4.2)
    if (githubContext != null) {
      body['githubContext'] = githubContext;
    }

    final response = await post('/coding-agent/followups/send', body);
    return response;
  }

  /// Disconnect an agent session
  /// Requirements: 4.3
  Future<Map<String, dynamic>> disconnectAgent(String sessionId) async {
    final response =
        await post('/coding-agent/sessions/$sessionId/disconnect', {});
    return response;
  }

  // ============ PERSONAL API TOKENS ============

  /// Generate a new personal API token for authenticating MCP servers
  /// Requirements: 1.1, 1.4, 1.5
  ///
  /// Returns the full token (only shown once!) along with token metadata.
  /// The token should be copied immediately as it cannot be retrieved later.
  Future<Map<String, dynamic>> generateApiToken({
    required String name,
    DateTime? expiresAt,
  }) async {
    final response = await post('/auth/tokens', {
      'name': name,
      if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
    });
    return response;
  }

  /// List all API tokens for the current user
  /// Requirements: 2.1
  ///
  /// Returns token metadata including name, creation date, last used date,
  /// and partial token (prefix/suffix for identification).
  Future<List<Map<String, dynamic>>> listApiTokens() async {
    final response = await get('/auth/tokens');
    return List<Map<String, dynamic>>.from(response['tokens'] ?? []);
  }

  /// Revoke an API token by ID
  /// Requirements: 2.2
  ///
  /// Once revoked, the token is immediately invalidated for all future requests.
  Future<void> revokeApiToken(String tokenId) async {
    await delete('/auth/tokens/$tokenId');
  }
}
