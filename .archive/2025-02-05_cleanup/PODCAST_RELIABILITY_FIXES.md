# Podcast Generation Reliability Fixes

**Date:** December 10, 2025

## Issues Addressed

### 1. Podcasts Getting Stuck
- **Root Cause:** No timeout handling on API calls. TTS or AI calls could hang indefinitely.
- **Fix:** Added 90s timeout for AI calls and 60s timeout for TTS calls.

### 2. Podcasts Not Fully Generating
- **Root Cause:** Single TTS failure would crash entire generation. No retry logic.
- **Fix:** Added retry helper with 3 attempts and exponential backoff. Failed segments are skipped instead of crashing.

### 3. JSON Parsing Failures
- **Root Cause:** AI sometimes returns JSON wrapped in markdown code blocks or with trailing commas.
- **Fix:** Enhanced JSON parser that:
  - Strips markdown code blocks (```json```)
  - Removes trailing commas
  - Handles malformed responses gracefully
  - Falls back to regex parsing

### 4. No Way to Cancel Stuck Generation
- **Root Cause:** No cancellation mechanism.
- **Fix:** Added `cancelGeneration()` method and Cancel button in UI.

### 5. Content Too Long for AI
- **Root Cause:** Sources could exceed AI token limits causing failures.
- **Fix:** Content is now truncated to 30,000 characters before sending to AI.

### 6. Only First Voice Plays (Audio Concatenation Issue) ⭐ NEW
- **Root Cause:** MP3 files cannot be simply concatenated byte-by-byte. Each MP3 has headers that make simple concatenation impossible - only the first track plays.
- **Fix:** 
  - For Murf TTS: Use **PCM format** instead of MP3 for podcast segments
  - PCM is raw audio that CAN be concatenated
  - After concatenation, wrap with WAV header to create playable file
  - File is saved as `.wav` instead of `.mp3`

---

## Changes Made

### `lib/features/studio/audio_overview_provider.dart`

#### New Constants
```dart
const Duration _aiTimeout = Duration(seconds: 90);
const Duration _ttsTimeout = Duration(seconds: 60);
const int _maxRetries = 3;
const Duration _retryDelay = Duration(seconds: 2);
```

#### State Updates
- Added `isCancelled` flag to `AudioStudioState`
- Added `cancelGeneration()` method
- Added `_shouldAbort` getter

#### New Helper Method
```dart
Future<Uint8List> _generateTTSWithRetry({
  required Future<Uint8List> Function() primaryGen,
  required Future<Uint8List> Function() fallback1,
  required Future<Uint8List> Function() fallback2,
  required String segmentInfo,
})
```
This method:
- Tries primary TTS provider with timeout
- Falls back to fallback1, then fallback2
- Retries up to 3 times with exponential backoff
- Checks for cancellation between attempts

#### Enhanced `_callAI()`
- Added 90-second timeout
- Better error handling for timeouts

#### Enhanced `generate()`
- Resets `isCancelled` at start
- Limits content to 30k characters
- Checks `_shouldAbort` before each segment
- Uses `_generateTTSWithRetry` for all TTS calls
- Skips failed segments instead of failing entire podcast
- Tracks successful segment count
- Proper cancellation handling in catch block

#### Enhanced `_parsePodcastJson()`
- Strips markdown code blocks
- Removes AI intro text before JSON
- Fixes trailing commas
- Better error logging
- More robust segment extraction

### `lib/features/studio/studio_screen.dart`

- Shows "Cancelling..." text when cancellation is in progress
- Added Cancel button (red) during generation
- Button calls `cancelGeneration()` on provider

---

## How It Works Now

### Timeout Protection
```
AI Call → 90s timeout → Exception if exceeds
TTS Call → 60s timeout → Exception if exceeds
```

### Retry Flow for Each Segment
```
Attempt 1: Primary TTS (e.g., ElevenLabs)
  ↓ (if fails)
  Try Fallback 1 (e.g., Murf)
  ↓ (if fails)
  Try Fallback 2 (e.g., Google)
  ↓ (if all fail)
Wait 2s, then Attempt 2...
Wait 4s, then Attempt 3...
  ↓ (if all fail)
Skip segment, continue with next
```

### Cancellation Flow
```
User clicks Cancel
  ↓
cancelGeneration() sets isCancelled = true
  ↓
_shouldAbort returns true
  ↓
Next loop iteration throws 'Cancelled'
  ↓
Catch block shows "Generation cancelled"
  ↓
State resets, overlay hides
```

---

## Testing

1. **Timeout Test**: Use a TTS provider that's slow/unreachable
2. **Retry Test**: Temporarily fail one provider
3. **Cancel Test**: Start generation, click Cancel
4. **Long Content Test**: Add many sources, generate podcast
5. **Malformed JSON Test**: Already handled by enhanced parser

---

## Statistics Logged

During generation, debug logs show:
- Content length and any truncation
- Number of segments generated
- Which TTS provider used for each segment
- Retry attempts and fallbacks used
- Success rate (e.g., "Generated 18/20 segments successfully")

---

## User Experience

### Before
- Podcast would hang indefinitely
- No indication of what's happening
- Only option was to force-close app
- Partial failures crashed everything

### After
- Clear progress indication: "Recording 5/20 (Sarah)..."
- Cancel button visible during generation
- Failed segments skipped gracefully
- Timeout protection prevents permanent hangs
- Better error messages when things fail
