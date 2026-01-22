// Add this to your lib/core/api/api_service.dart to handle automatic token refresh

// Add this method to your ApiService class:
Future<Map<String, dynamic>> _makeRequestWithRetry(
  String method,
  String path, {
  Map<String, dynamic>? data,
  bool retry = true,
}) async {
  try {
    // Make the original request
    final response = await _makeHttpRequest(method, path, data);
    return response;
  } catch (e) {
    // Check if it's a 401/403 error and we haven't retried yet
    if (retry &&
        (e.toString().contains('401') || e.toString().contains('403'))) {
      debugPrint(
          'API request failed with auth error, attempting token refresh...');

      // Try to refresh the token
      final authService = _ref.read(customAuthServiceProvider);
      final newTokens = await authService.refreshTokens();

      if (newTokens != null) {
        debugPrint('Token refreshed successfully, retrying request...');
        // Retry the request with new token (retry = false to prevent infinite loop)
        return _makeRequestWithRetry(method, path, data: data, retry: false);
      } else {
        debugPrint('Token refresh failed, signing out user...');
        // Refresh failed, sign out user
        await authService.signOut();
        _ref.read(customAuthStateProvider.notifier).signOut();
      }
    }

    rethrow;
  }
}

// Update all your API methods to use _makeRequestWithRetry instead of direct HTTP calls
// For example:
Future<Map<String, dynamic>> getChatHistory(String notebookId) async {
  return _makeRequestWithRetry('GET', '/ai/chat/history/$notebookId');
}

Future<Map<String, dynamic>> getCurrentUser(
    {bool clearTokenOn401 = true}) async {
  return _makeRequestWithRetry('GET', '/auth/me', retry: clearTokenOn401);
}

// Add this helper method for the actual HTTP request:
Future<Map<String, dynamic>> _makeHttpRequest(
    String method, String path, Map<String, dynamic>? data) async {
  final token = await getToken();
  final headers = <String, String>{
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  final uri = Uri.parse('$baseUrl$path');
  http.Response response;

  switch (method.toUpperCase()) {
    case 'GET':
      response = await http.get(uri, headers: headers);
      break;
    case 'POST':
      response = await http.post(uri,
          headers: headers, body: data != null ? jsonEncode(data) : null);
      break;
    case 'PUT':
      response = await http.put(uri,
          headers: headers, body: data != null ? jsonEncode(data) : null);
      break;
    case 'DELETE':
      response = await http.delete(uri, headers: headers);
      break;
    default:
      throw Exception('Unsupported HTTP method: $method');
  }

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return jsonDecode(response.body);
  } else {
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }
}
