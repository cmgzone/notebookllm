// Update lib/core/auth/custom_auth_service.dart

// Replace the empty refreshTokens method with this implementation:
Future<AuthTokens?> refreshTokens() async {
  try {
    // Get stored refresh token
    final refreshToken = await _secureStorage.read(key: 'refresh_token');
    if (refreshToken == null) {
      developer.log('No refresh token found', name: 'CustomAuthService');
      return null;
    }

    developer.log('Attempting to refresh token', name: 'CustomAuthService');

    final response = await _api.post('/auth/refresh', {
      'refreshToken': refreshToken,
    });

    if (response['success'] == true) {
      final newAccessToken = response['accessToken'] as String;
      final expiresIn = response['expiresIn'] as int;

      // Calculate expiry time
      final accessTokenExpiry =
          DateTime.now().add(Duration(seconds: expiresIn));
      final refreshTokenExpiry = DateTime.now().add(const Duration(days: 30));

      final tokens = AuthTokens(
        accessToken: newAccessToken,
        refreshToken: refreshToken, // Keep existing refresh token
        accessTokenExpiry: accessTokenExpiry,
        refreshTokenExpiry: refreshTokenExpiry,
      );

      // Store new access token
      await _api.setToken(newAccessToken);

      developer.log('Token refreshed successfully', name: 'CustomAuthService');
      return tokens;
    }

    developer.log('Token refresh failed: ${response['error']}',
        name: 'CustomAuthService');
    return null;
  } catch (e) {
    developer.log('Token refresh error: $e', name: 'CustomAuthService');
    return null;
  }
}

// Update the signIn method to store refresh token:
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

      // Store refresh token securely if provided
      if (response['refreshToken'] != null) {
        await _secureStorage.write(
            key: 'refresh_token', value: response['refreshToken']);
        developer.log('Refresh token stored', name: 'CustomAuthService');
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

// Update signOut to clear refresh token:
Future<void> signOut() async {
  await _api.clearToken();
  await _secureStorage.delete(key: _userDataKey);
  await _secureStorage.delete(key: 'refresh_token'); // Clear refresh token
  developer.log('User signed out, tokens cleared', name: 'CustomAuthService');
}
