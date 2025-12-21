# Authentication Fixes

## Issues Addressed

1.  **Missing User Name on Sign Up**:
    - The user's display name was not being saved to the Neon database during sign-up because the Firebase user profile update happened *after* the Neon user creation.
    - **Fix**: Modified `FirebaseAuthService.signUpWithEmail` to accept the `name` parameter and pass it directly to `NeonDatabaseService.createUser`. Also updated `LoginScreen` to pass the name.

2.  **Unprotected Routes**:
    - Several features (`/voice-mode`, `/elevenlabs-agent`, `/visual-studio`) were accessible without authentication, potentially causing errors when they tried to access user-specific data or services.
    - **Fix**: Added these routes to the `protected` list in `lib/core/router.dart`.

3.  **Profile Synchronization**:
    - If a user's email or display name changed in Firebase (or was updated externally), the Neon database was not being updated upon login.
    - **Fix**: Added `updateUser` method to `NeonDatabaseService` and updated `FirebaseAuthService.signInWithEmail` to check for discrepancies and sync the user profile to Neon if needed.

## Files Modified

- `lib/core/backend/firebase_auth_service.dart`: Updated `signUpWithEmail` and `signInWithEmail`.
- `lib/features/auth/login_screen.dart`: Updated `_submit` to pass name to `signUpWithEmail`.
- `lib/core/router.dart`: Added protected routes.
- `lib/core/backend/neon_database_service.dart`: Added `updateUser` method.

## Verification

- **Sign Up**: Create a new account. The name should be visible in the app immediately.
- **Login**: Log in with an existing account. If the name was missing in Neon, it should be updated.
- **Protected Routes**: Try to access Voice Mode or Visual Studio without logging in. You should be redirected to the login screen.
