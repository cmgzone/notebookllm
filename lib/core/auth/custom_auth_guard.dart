import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'custom_auth_service.dart';

/// Routes that don't require authentication
const publicRoutes = {
  '/onboarding',
  '/onboarding-completion',
  '/login',
  '/password-reset',
  '/verify-email',
};

/// Protected route prefixes
const protectedRoutePrefixes = [
  '/home',
  '/sources',
  '/chat',
  '/studio',
  '/search',
  '/artifact',
  '/research',
  '/settings',
  '/security',
  '/deploy-keys',
  '/migrate-agent-id',
  '/context-profile',
  '/elevenlabs-agent',
  '/voice-mode',
  '/visual-studio',
  '/notebook/',
];

/// Auth change notifier for GoRouter refresh
class CustomAuthChangeNotifier extends ChangeNotifier {
  final ProviderContainer _container;
  ProviderSubscription<AuthState>? _subscription;

  CustomAuthChangeNotifier(this._container) {
    _subscription = _container.listen<AuthState>(
      customAuthStateProvider,
      (previous, next) {
        if (previous?.status != next.status) {
          notifyListeners();
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }
}

/// Check if a route requires authentication
bool isProtectedRoute(String path) {
  // Check exact public routes
  if (publicRoutes.contains(path)) return false;

  // Check if path starts with a public route (for query params)
  for (final route in publicRoutes) {
    if (path.startsWith('$route?') || path.startsWith('$route/')) {
      return false;
    }
  }

  // Check protected prefixes
  for (final prefix in protectedRoutePrefixes) {
    if (path.startsWith(prefix)) return true;
  }

  return false;
}

/// Create auth redirect function with container
String? Function(BuildContext?, GoRouterState) createCustomAuthRedirect(
    ProviderContainer container) {
  return (BuildContext? context, GoRouterState state) {
    final authState = container.read(customAuthStateProvider);
    final isAuthenticated = authState.isAuthenticated;
    final isLoading = authState.isLoading;
    final path = state.uri.path;

    // Don't redirect while loading
    if (isLoading) return null;

    // Allow public routes
    if (publicRoutes.contains(path)) {
      // Redirect authenticated users away from login
      if (path == '/login' && isAuthenticated) {
        return '/home';
      }
      return null;
    }

    // Handle password reset with token
    if (path.startsWith('/password-reset')) {
      return null;
    }

    // Handle email verification
    if (path.startsWith('/verify-email')) {
      return null;
    }

    // Protect routes that need auth
    if (!isAuthenticated && isProtectedRoute(path)) {
      // Store the intended destination for redirect after login
      final redirectTo = Uri.encodeComponent(state.uri.toString());
      return '/login?redirect=$redirectTo';
    }

    return null;
  };
}

/// Middleware to check session validity periodically
class SessionValidityMiddleware {
  final ProviderContainer _container;
  DateTime? _lastCheck;
  static const _checkInterval = Duration(minutes: 5);

  SessionValidityMiddleware(this._container);

  Future<bool> checkSession() async {
    final now = DateTime.now();

    // Only check every 5 minutes
    if (_lastCheck != null && now.difference(_lastCheck!) < _checkInterval) {
      return true;
    }

    _lastCheck = now;

    try {
      final authService = _container.read(customAuthServiceProvider);
      final isValid = await authService.isSessionValid();

      if (!isValid) {
        // Session expired, sign out
        await _container.read(customAuthStateProvider.notifier).signOut();
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Provider for session validity middleware
final sessionValidityMiddlewareProvider =
    Provider<SessionValidityMiddleware>((ref) {
  throw UnimplementedError('Must be overridden with container');
});
