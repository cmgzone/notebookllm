# Overlay Bubble Troubleshooting Guide

## Issue: Overlay bubble not appearing when app is closed/minimized

### Root Cause
The `flutter_overlay_window` package requires specific Android permissions and configuration to work properly when the app is in the background.

### Solution Steps

#### 1. **Verify AndroidManifest.xml Configuration** ✅
The manifest has been updated with:
- `SYSTEM_ALERT_WINDOW` permission (line 10)
- Overlay service declaration (lines 56-59)

#### 2. **Request Permission at Runtime**
The overlay requires the user to grant "Display over other apps" permission.

**Add this check in your ebook wizard before starting generation:**

```dart
// In ebook_creator_wizard.dart, before calling startGeneration:

Future<void> _startGeneration() async {
  // Check overlay permission
  final hasPermission = await overlayBubbleService.checkPermission();
  if (!hasPermission) {
    final granted = await overlayBubbleService.requestPermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Overlay permission required for background progress'),
        ),
      );
      // Still continue, but overlay won't show
    }
  }
  
  // Now start generation
  await ref.read(ebookOrchestratorProvider.notifier).startGeneration(project);
}
```

#### 3. **Test the Overlay**

**Manual Testing Steps:**
1. **Build and install the app** (overlay doesn't work in debug mode reliably):
   ```bash
   flutter build apk --release
   # Install the APK on your device
   ```

2. **Grant permission manually**:
   - Go to Settings → Apps → NotebookLLM → Special app access → Display over other apps
   - Enable the toggle

3. **Start ebook generation**:
   - Create a new ebook
   - Start generation
   - Press home button or minimize the app
   - You should see the floating bubble

#### 4. **Alternative: Use Notification Instead**

If overlay continues to have issues, you can fall back to notifications which are more reliable:

```dart
// In overlay_bubble_service.dart, add fallback:

Future<void> show({String status = 'AI Generating...'}) async {
  final hasPermission = await checkPermission();
  if (!hasPermission) {
    final granted = await requestPermission();
    if (!granted) {
      // Fallback to notification
      await _showNotification(status);
      return;
    }
  }
  
  // Continue with overlay...
}

Future<void> _showNotification(String status) async {
  // Use flutter_local_notifications to show persistent notification
  // This is more reliable than overlay
}
```

#### 5. **Common Issues**

**Issue**: Permission dialog doesn't appear
- **Fix**: Make sure you're testing on a physical device (emulator has issues)
- **Fix**: Check Android version (works best on Android 8.0+)

**Issue**: Overlay appears but disappears immediately
- **Fix**: Ensure `hide()` is only called when generation completes
- **Fix**: Check that the app isn't being killed by battery optimization

**Issue**: Overlay doesn't update
- **Fix**: Verify `FlutterOverlayWindow.shareData()` is being called
- **Fix**: Check that `overlayListener` is properly subscribed

### Current Implementation Status

✅ **Configured:**
- AndroidManifest.xml has overlay service
- SYSTEM_ALERT_WINDOW permission added
- overlayMain() entry point defined
- OverlayBubbleService implemented
- Ebook orchestrator calls show/hide

⚠️ **Needs Testing:**
- Permission request flow
- Overlay visibility when app is minimized
- Data updates to overlay

### Recommended Next Steps

1. **Add permission request to ebook wizard** (code provided above)
2. **Build release APK and test on physical device**
3. **Manually grant overlay permission in settings**
4. **Test by starting ebook generation and minimizing app**

### Debug Commands

```bash
# Check if overlay permission is granted
adb shell appops get com.example.notebook_llm SYSTEM_ALERT_WINDOW

# Force grant permission (for testing)
adb shell appops set com.example.notebook_llm SYSTEM_ALERT_WINDOW allow

# View logs for overlay
adb logcat | grep -i overlay
```

### Alternative Solution: Background Notification

If overlay proves unreliable, the app already has `flutter_local_notifications` configured. You can show a persistent notification with progress updates instead, which is more reliable across all Android versions.
