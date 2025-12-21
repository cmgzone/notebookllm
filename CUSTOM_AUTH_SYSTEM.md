# Custom Authentication System

A complete, secure, custom authentication system built without Firebase Auth dependency.

## Features

### Core Authentication
- **Email/Password Sign Up & Sign In** - Secure registration and login
- **Password Hashing** - SHA-256 double-hashing with unique salts
- **Session Management** - JWT-like token system with access/refresh tokens
- **Remember Me** - Extended session duration option

### Security Features
- **Two-Factor Authentication (2FA)** - Email-based verification codes
- **Account Lockout** - Automatic lockout after 5 failed attempts (15 min)
- **Password Strength Validation** - Real-time strength indicator
- **Secure Token Storage** - Flutter Secure Storage with platform encryption
- **Audit Logging** - Complete activity history

### Account Management
- **Email Verification** - Token-based email confirmation
- **Password Reset** - Secure reset via email link
- **Profile Updates** - Display name and avatar
- **Session Management** - View and revoke active sessions
- **Account Deletion** - Complete data removal

## File Structure

```
lib/core/auth/
├── auth.dart                    # Barrel exports
├── custom_auth_service.dart     # Main auth service & providers
├── custom_auth_guard.dart       # Route protection
└── auth_database_setup.sql      # Database schema

lib/features/auth/
├── custom_login_screen.dart     # Login/signup UI
├── security_settings_screen.dart # Security management UI
├── password_reset_screen.dart   # Password reset UI
└── email_verification_screen.dart # Email verification UI
```

## Database Setup

Run the SQL in `lib/core/auth/auth_database_setup.sql` in your Neon database:

```sql
-- Tables created:
-- users (enhanced with email_verified, two_factor_enabled)
-- auth_sessions (access/refresh tokens)
-- verification_tokens (email verification, password reset)
-- two_factor_codes (2FA codes)
-- login_attempts (rate limiting)
-- audit_logs (activity tracking)
```

## Usage

### Providers

```dart
// Auth state (reactive)
final authState = ref.watch(customAuthStateProvider);

// Current user
final user = ref.watch(currentUserProvider);

// Is authenticated
final isAuth = ref.watch(isAuthenticatedProvider);

// Auth service (for actions)
final authService = ref.read(customAuthServiceProvider);
```

### Sign Up

```dart
await ref.read(customAuthStateProvider.notifier).signUp(
  email: 'user@example.com',
  password: 'SecurePass123!',
  displayName: 'John Doe',
);
```

### Sign In

```dart
await ref.read(customAuthStateProvider.notifier).signIn(
  email: 'user@example.com',
  password: 'SecurePass123!',
  rememberMe: true,
);

// Check if 2FA is required
final state = ref.read(customAuthStateProvider);
if (state.requiresTwoFactor) {
  // Show 2FA input
}
```

### Two-Factor Authentication

```dart
// Verify 2FA code
await ref.read(customAuthStateProvider.notifier).verifyTwoFactor('123456');

// Enable 2FA
await authService.enableTwoFactor(userId);

// Disable 2FA (requires password)
await authService.disableTwoFactor(userId, password);
```

### Password Management

```dart
// Check password strength
final strength = authService.checkPasswordStrength(password);
// strength.score (0-4), strength.label, strength.suggestions

// Change password
await authService.changePassword(
  userId: userId,
  currentPassword: 'oldPass',
  newPassword: 'newSecurePass!',
);

// Request password reset
await authService.requestPasswordReset('user@example.com');

// Reset password with token
await authService.resetPassword(token, newPassword);
```

### Session Management

```dart
// Get active sessions
final sessions = await authService.getActiveSessions(userId);

// Revoke specific session
await authService.revokeSession(sessionId);

// Revoke all other sessions
await authService.revokeAllOtherSessions(userId);
```

### Audit Logs

```dart
final logs = await authService.getAuditLogs(userId, limit: 50);
```

## Routes

| Route | Description |
|-------|-------------|
| `/login` | Login/signup screen |
| `/password-reset/:token` | Password reset form |
| `/verify-email/:token` | Email verification |
| `/security` | Security settings |

## Security Constants

```dart
class AuthConstants {
  static const int accessTokenExpiryMinutes = 15;
  static const int refreshTokenExpiryDays = 30;
  static const int passwordResetExpiryMinutes = 30;
  static const int emailVerificationExpiryHours = 24;
  static const int twoFactorCodeExpiryMinutes = 5;
  static const int maxLoginAttempts = 5;
  static const int lockoutDurationMinutes = 15;
  static const int minPasswordLength = 8;
}
```

## Migration from Firebase Auth

1. Run the database setup SQL
2. Update imports from `auth_service.dart` to `custom_auth_service.dart`
3. Replace `authStateProvider` with `customAuthStateProvider`
4. Update route guards to use `CustomAuthChangeNotifier`
5. Test all auth flows

## Email Integration (Production)

For production, implement email sending in these methods:
- `sendEmailVerification()` - Send verification link
- `requestPasswordReset()` - Send reset link  
- `_generateAndSaveTwoFactorCode()` - Send 2FA code

Example with a service like SendGrid, Mailgun, or AWS SES.
