# Backend Integration Fix - Complete Guide

## Problem Summary
Your Flutter app is crashing after migrating to backend API because:
1. **API Response Parsing Issues** - Backend returns different response structure than expected
2. **Authentication Failures** - Token handling and auth flow mismatches
3. **Error Handling** - Missing null checks and error response handling
4. **CORS/Network Issues** - Backend URL configuration problems

## Critical Fixes Required

### 1. Fix API Service Response Handling

**Issue**: `_handleResponse()` doesn't handle null responses properly

```dart
// BEFORE (BROKEN)
Map<String, dynamic> _handleResponse(http.Response response,
    {bool clearTokenOn401 = false}) {
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  // This crashes if response.body is empty or null
}

// AFTER (FIXED)
Map<String, dynamic> _handleResponse(http.Response response,
    {bool clearTokenOn401 = false}) {
  try {
    if (response.body.isEmpty) {
      throw Exception('Empty response from server');
    }
    
    final body = jsonDecode(response.body) as Map<String, dynamic>?;
    
    if (body == null) {
      throw Exception('Invalid JSON response from server');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else if (response.statusCode == 401) {
      developer.log(
          '[API] Got 401 response (missing token), clearTokenOn401=$clearTokenOn401',
          name: 'ApiService');
      if (clearTokenOn401) {
        clearToken();
      }
      throw Exception('Unauthorized - please login again');
    } else if (response.statusCode == 403) {
      developer.log(
          '[API] Got 403 response (invalid/expired token)',
          name: 'ApiService');
      throw Exception('Session expired - please login again');
    } else if (response.statusCode == 429) {
      final message =
          body['message'] ?? 'Rate limit exceeded. Please try again later.';
      throw Exception(message);
    } else {
      final message = body['message'] ??
          body['error'] ??
          'Request failed: ${response.statusCode}';
      throw Exception(message);
    }
  } catch (e) {
    if (e is Exception) {
      rethrow;
    }
    throw Exception('Failed to parse response: $e');
  }
}
```

### 2. Fix Auth Service Response Handling

**Issue**: Auth service expects `success` field that backend doesn't return

```dart
// BEFORE (BROKEN)
Future<Map<String, dynamic>> login({
  required String email,
  required String password,
}) async {
  try {
    final response = await _apiService.login(
      email: email,
      password: password,
    );

    if (response['success'] == true && response['user'] != null) {
      return response['user'];
    } else {
      throw Exception('Login failed');
    }
  } catch (e) {
    throw Exception('Login error: $e');
  }
}

// AFTER (FIXED)
Future<Map<String, dynamic>> login({
  required String email,
  required String password,
}) async {
  try {
    final response = await _apiService.login(
      email: email,
      password: password,
    );

    // Backend returns user directly or in 'user' field
    final user = response['user'] ?? response;
    if (user != null && user is Map<String, dynamic>) {
      return user;
    } else {
      throw Exception('Login failed: Invalid response');
    }
  } catch (e) {
    throw Exception('Login error: $e');
  }
}
```

### 3. Fix Notebook Provider

**Issue**: Notebooks endpoint returns empty list when user not authenticated

```dart
// Add proper error handling in notebook_provider.dart
Future<List<Map<String, dynamic>>> getNotebooks() async {
  final token = await getToken();
  
  if (token == null) {
    developer.log('[API] getNotebooks - NO TOKEN! User not authenticated',
        name: 'ApiService');
    return [];
  }

  try {
    developer.log('[API] Fetching notebooks...', name: 'ApiService');
    final response = await get('/notebooks');
    final notebooks =
        List<Map<String, dynamic>>.from(response['notebooks'] ?? []);
    return notebooks;
  } catch (e) {
    developer.log('[API] Error fetching notebooks: $e', name: 'ApiService');
    return [];
  }
}
```

### 4. Backend URL Configuration

**Current**: `https://backend.taskiumnetwork.com/api`

Verify this URL is:
- ✅ Accessible from your network
- ✅ CORS enabled for Flutter app
- ✅ Running and responding to requests

Test with:
```bash
curl -X GET https://backend.taskiumnetwork.com/api/health
```

### 5. Environment Configuration

Ensure `.env` file has correct backend URL:
```properties
# .env (Flutter)
BACKEND_URL=https://backend.taskiumnetwork.com/api

# backend/.env (Node.js)
PORT=3000
NODE_ENV=production
JWT_SECRET=your-secret-key
NEON_HOST=your-neon-host
NEON_DATABASE=neondb
NEON_USERNAME=neondb_owner
NEON_PASSWORD=your-password
```

## Implementation Steps

### Step 1: Update API Service
1. Open `lib/core/api/api_service.dart`
2. Replace `_handleResponse()` method with fixed version
3. Add null checks to all response parsing

### Step 2: Update Auth Service
1. Open `lib/core/auth/auth_service.dart`
2. Remove `success` field checks
3. Handle both direct user response and nested user field

### Step 3: Test Authentication Flow
1. Clear app cache and data
2. Try login with test credentials
3. Verify token is stored correctly
4. Check network logs for API responses

### Step 4: Verify Backend is Running
```bash
# Check backend status
npm run dev  # in backend directory

# Test API endpoint
curl -X GET https://backend.taskiumnetwork.com/api/health
```

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| 401 Unauthorized | Token not stored or expired. Clear cache and re-login |
| Empty response | Backend not returning data. Check API endpoint |
| CORS error | Backend CORS not configured. Add Flutter app URL to CORS whitelist |
| Connection timeout | Backend URL wrong or server down. Verify URL and server status |
| JSON parse error | Response format mismatch. Check backend response structure |

## Testing Checklist

- [ ] Backend server is running
- [ ] API endpoints are accessible
- [ ] CORS is configured correctly
- [ ] Database migrations are complete
- [ ] Auth tokens are being stored
- [ ] Notebooks API returns data
- [ ] Error responses are handled gracefully
- [ ] App doesn't crash on network errors

## Deployment to GitHub

See `GITHUB_DEPLOYMENT.md` for push instructions.
