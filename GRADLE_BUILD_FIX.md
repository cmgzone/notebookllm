# Gradle Build Fix - Repository Configuration

## Problem Fixed

The Android build was failing with:
```
Cannot resolve external dependency com.google.gms:google-services:4.4.0 
because no repositories are defined.
```

## Solution Applied

### 1. Fixed `android/build.gradle.kts`

Added repositories to the `buildscript` block:

```kotlin
buildscript {
    repositories {
        google()        // ✅ Added
        mavenCentral()  // ✅ Added
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}
```

### 2. Fixed `android/settings.gradle.kts`

Added `dependencyResolutionManagement` block:

```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
    }
}
```

## Why This Happened

Modern Gradle (7.0+) requires explicit repository declarations in:
1. **buildscript block** - For build dependencies (like Google Services plugin)
2. **dependencyResolutionManagement** - For project dependencies

The repositories were only defined in `pluginManagement`, which isn't sufficient.

## How to Build Now

### Clean Build (Recommended)
```powershell
flutter clean
flutter pub get
flutter build apk --release
```

### Debug Build
```powershell
flutter run
```

### Build for Specific Architecture
```powershell
# ARM64 only (smaller APK)
flutter build apk --release --target-platform android-arm64

# Split per ABI (recommended for Play Store)
flutter build apk --release --split-per-abi
```

## Build Times

First release build can take 5-10 minutes because:
- Gradle downloads dependencies
- Compiles native code
- Optimizes with R8/ProGuard
- Generates release APK

Subsequent builds are much faster (1-2 minutes).

## Troubleshooting

### Build Still Failing?

1. **Check Java version:**
   ```powershell
   java -version
   ```
   Should be Java 11 or higher.

2. **Clear Gradle cache:**
   ```powershell
   cd android
   .\gradlew clean
   cd ..
   flutter clean
   ```

3. **Update Gradle wrapper:**
   ```powershell
   cd android
   .\gradlew wrapper --gradle-version=8.7
   cd ..
   ```

### Build Taking Too Long?

This is normal for release builds. You can:
- Use debug builds for testing: `flutter run`
- Build for single architecture: `flutter build apk --release --target-platform android-arm64`
- Increase Gradle memory in `android/gradle.properties`:
  ```properties
  org.gradle.jvmargs=-Xmx4096m
  ```

### Missing google-services.json?

If you see Firebase errors:
1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/`
3. Rebuild

## Files Modified

- ✅ `android/build.gradle.kts` - Added buildscript repositories
- ✅ `android/settings.gradle.kts` - Added dependencyResolutionManagement

## Verification

Build should now complete successfully:
```
✓ Built build/app/outputs/flutter-apk/app-release.apk (XX.XMB)
```

## Related Issues

This fix also resolves:
- Firebase plugin resolution errors
- Other Google Play Services dependency issues
- Maven Central dependency resolution problems

## Next Steps

After successful build:
1. Test the APK on a device
2. Check app size and optimize if needed
3. Configure signing for Play Store release
4. Run `flutter build appbundle` for Play Store upload

## Repository Configuration Explained

```kotlin
// For build plugins (Google Services, etc.)
buildscript {
    repositories { google(); mavenCentral() }
}

// For project dependencies (Firebase, etc.)
allprojects {
    repositories { google(); mavenCentral() }
}

// Modern Gradle approach (preferred)
dependencyResolutionManagement {
    repositories { google(); mavenCentral() }
}
```

All three ensure dependencies can be resolved from Google's Maven repository and Maven Central.
