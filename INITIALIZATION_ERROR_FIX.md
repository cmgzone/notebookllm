# Initialization Error Troubleshooting

The error `PlatformException(channel-error, Unable to establish connection on channel., null, null)` indicates that the Flutter app (Dart code) is trying to talk to native code (Java/Kotlin on Android) that doesn't exist or isn't registered.

This commonly happens when:
1.  **New Dependencies Added**: You added packages like `firebase_core`, `firebase_auth`, or `shared_preferences` to `pubspec.yaml`, but the native app hasn't been rebuilt to include their native code.
2.  **Hot Restart**: You performed a "Hot Restart" instead of a full stop and start after adding these dependencies.

## Solution

1.  **Stop the App**: Completely stop the running application.
2.  **Rebuild**: Run the app again (`flutter run` or press Play in your IDE). This forces a rebuild of the APK/bundle, linking the new native plugins.

## What I Changed

I have updated `lib/main.dart` to be more robust:
-   **Granular Error Reporting**: The error screen will now tell you exactly *which* step failed (e.g., "Initializing Firebase", "Loading Preferences").
-   **Graceful Degradation**: If Firebase fails to initialize (common if configuration is missing), the app will now try to continue instead of crashing completely. This should allow you to at least see the home screen, though authentication features won't work until the underlying issue is resolved.
-   **Safe Preferences**: Wrapped `SharedPreferences` initialization in a try-catch block as well.

Please rebuild and run the app. If you still see the error, the new error message will pinpoint exactly which plugin is causing the issue.
