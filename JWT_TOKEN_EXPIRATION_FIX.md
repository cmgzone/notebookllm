# JWT Token Expiration Fix

## Problem
Your production app is experiencing JWT token expiration errors because:
1. JWT tokens expire after 15 minutes
2. Token refresh mechanism is not implemented (`refreshTokens()` returns null)
3. Frontend doesn't handle token expiration gracefully

## Solution

### 1. Backend: Add Token Refresh Endpoint

Add this to `backend/src/routes/auth.ts`:

```typescript
// Add refresh token endpoint
router.post('/refresh', async (req, res) => {
    try {
        const { refreshToken } = req.body;
        
        if (!refreshToken) {
            return res.status(400).json({ error: 'Refresh token required' });
        }

        // Verify refresh token (you'll need to store these in DB)
        const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET) as any;
        
        // Generate new access token
        const newAccessToken = jwt.sign(
            { userId: decoded.userId, email: decoded.email, role: decoded.role },
            process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production',
            { expiresIn: '15m' }
        );

        res.json({
            success: true,
            accessToken: newAccessToken,
            expiresIn: 15 * 60 // 15 minutes in seconds
        });
    } catch (error) {
        console.error('Token refresh error:', error);
        res.status(401).json({ error: 'Invalid refresh token' });
    }
});
```

### 2. Backend: Update Login to Return Refresh Token

Update your login endpoint to return both access and refresh tokens:

```typescript
// In your login endpoint
const accessToken = jwt.sign(
    { userId: user.id, email: user.email, role: user.role },
    jwtSecret,
    { expiresIn: '15m' }
);

const refreshToken = jwt.sign(
    { userId: user.id, email: user.email, role: user.role },
    process.env.JWT_REFRESH_SECRET || jwtSecret,
    { expiresIn: '30d' }
);

res.json({
    success: true,
    user: userResponse,
    accessToken,
    refreshToken,
    expiresIn: 15 * 60
});
```

### 3. Frontend: Implement Token Refresh Logic

Update `lib/core/auth/custom_auth_service.dart`:

```dart
Future<AuthTokens?> refreshTokens() async {
  try {
    // Get stored refresh token
    final refreshToken = await _secureStorage.read(key: 'refresh_token');
    if (refreshToken == null) return null;

    final response = await _api.post('/auth/refresh', {
      'refreshToken': refreshToken,
    });

    if (response['success'] == true) {
      final newAccessToken = response['accessToken'] as String;
      final expiresIn = response['expiresIn'] as int;
      
      // Calculate expiry time
      final accessTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
      final refreshTokenExpiry = DateTime.now().add(const Duration(days: 30));
      
      final tokens = AuthTokens(
        accessToken: newAccessToken,
        refreshToken: refreshToken, // Keep existing refresh token
        accessTokenExpiry: accessTokenExpiry,
        refreshTokenExpiry: refreshTokenExpiry,
      );

      // Store new access token
      await _api.setToken(newAccessToken);
      
      return tokens;
    }
    
    return null;
  } catch (e) {
    developer.log('Token refresh failed: $e', name: 'CustomAuthService');
    return null;
  }
}
```

### 4. Frontend: Add Automatic Token Refresh

Update your API service to automatically refresh tokens:

```dart
// In lib/core/api/api_service.dart
Future<Map<String, dynamic>> _makeRequest(String method, String path, {
  Map<String, dynamic>? data,
  bool retry = true,
}) async {
  try {
    // Make the request
    final response = await _makeHttpRequest(method, path, data);
    return response;
  } catch (e) {
    // If 401/403 and we haven't retried yet, try to refresh token
    if (retry && (e.toString().contains('401') || e.toString().contains('403'))) {
      final authService = _ref.read(customAuthServiceProvider);
      final newTokens = await authService.refreshTokens();
      
      if (newTokens != null) {
        // Retry the request with new token
        return _makeRequest(method, path, data: data, retry: false);
      }
      
      // Refresh failed, sign out user
      await authService.signOut();
      _ref.read(customAuthStateProvider.notifier).signOut();
    }
    
    rethrow;
  }
}
```

### 5. Frontend: Store Refresh Token Securely

Update your login method to store the refresh token:

```dart
Future<AuthResult> signIn({
  required String email,
  required String password,
  bool rememberMe = false,
  String? deviceInfo,
}) async {
  try {
    final response = await _api.login(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );

    if (response['success'] == true && response['user'] != null) {
      final user = AppUser.fromMap(response['user']);
      await _cacheUser(user);

      // Store refresh token securely
      if (response['refreshToken'] != null) {
        await _secureStorage.write(
          key: 'refresh_token', 
          value: response['refreshToken']
        );
      }

      return AuthResult(success: true, user: user);
    } else {
      throw AuthException(response['error'] ?? 'Sign in failed');
    }
  } catch (e) {
    developer.log('Sign in error: $e', name: 'CustomAuthService');
    if (e is AuthException) rethrow;
    throw AuthException(e.toString());
  }
}
```

### 6. Environment Variables

Add to your backend `.env`:

```env
JWT_SECRET=your-super-secret-jwt-key-change-in-production
JWT_REFRESH_SECRET=your-even-more-secret-refresh-key-change-in-production
```

## Quick Fix for Production

For immediate relief, you can increase the JWT expiry time temporarily:

In `backend/src/routes/auth.ts`, change:
```typescript
// From 15 minutes to 24 hours temporarily
{ expiresIn: '24h' }
```

But implement the proper refresh token solution above for long-term stability.

## Testing

1. Deploy the backend changes
2. Test login - should receive both access and refresh tokens
3. Wait for token to expire (or manually expire it)
4. Make an API call - should automatically refresh and retry
5. Check logs for successful token refresh

## Security Notes

- Use different secrets for access and refresh tokens
- Store refresh tokens securely (encrypted in database)
- Implement refresh token rotation for maximum security
- Add rate limiting to refresh endpoint
- Log all token refresh attempts for security monitoring