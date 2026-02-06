# Podcast & Murf Voice Fixes

**Date:** December 10, 2025

## Issues Fixed

### 1. Murf Voice Not Working (Only Natalie Worked)

**Root Cause:**
The Murf voice setting was selected in the AI Model Settings screen, but it was **never being saved to SharedPreferences**. The `_saveSettings()` method in `ai_model_settings_screen.dart` was missing the line to save the Murf voice selection.

**Fix Applied:**
- Added loading of `tts_murf_voice` in `_loadSettings()` method
- Added saving of `tts_murf_voice` in `_saveSettings()` method
- Now properly saves/loads the selected Murf voice to `selectedMurfVoiceProvider`

### 2. Podcast Host Voices Not Configurable

**Root Cause:**
- The podcast generation used hardcoded voice for the male host (`en-US-miles`)
- There was no setting to let users choose different host voices for podcasts

**Fixes Applied:**
- Added secondary Murf voice setting `tts_murf_voice_male` for the male host (Adam)
- Created an enhanced `_PodcastSettingsDialog` in `studio_screen.dart` that:
  - Shows voice selection dropdowns when Murf is the TTS provider
  - Lets users pick voices for both Sarah (female) and Adam (male)
  - Saves voice choices to SharedPreferences before generating

---

## Files Modified

### `lib/features/settings/ai_model_settings_screen.dart`
- Added loading of `tts_murf_voice` from SharedPreferences
- Added `selectedMurfVoiceProvider` state update on load
- Added saving of `tts_murf_voice` on save

### `lib/core/audio/murf_service.dart`
- Expanded voice list from 8 to 14+ voices
- Added `femaleVoices` and `maleVoices` static lists for easy categorization
- Added `styles` list for voice style options (General, Conversational, etc.)
- Updated voice descriptions with style hints (e.g., "Conversational", "Professional")

### `lib/features/studio/audio_overview_provider.dart`
- Added loading of secondary male voice (`tts_murf_voice_male`)
- Updated generateMurf() to use 'Conversational' style for more natural podcasts
- Added debug logging for voice selection during podcast generation

### `lib/features/studio/studio_screen.dart`
- Added imports for `SharedPreferences` and `MurfService`
- Replaced inline podcast dialog with new stateful `_PodcastSettingsDialog` widget
- New dialog features:
  - Topic focus input field
  - Voice selection for Sarah (female host) when using Murf
  - Voice selection for Adam (male host) when using Murf
  - Info message when not using Murf
  - Auto-saves voice settings before generation

---

## How to Use

### Selecting Murf Voice in Settings
1. Go to **Settings > AI Model Settings**
2. Under "Voice & Speech", select **Murf.ai**
3. Choose your preferred voice from the dropdown
4. Tap **Save** (floppy disk icon)

### Customizing Podcast Host Voices
1. Go to **Studio** screen
2. Tap the **Deep Dive Podcast** card
3. In the dialog:
   - Enter a topic focus (optional)
   - If using Murf, select voices for:
     - **Sarah (Female Host)**: Choose from 7 female voices
     - **Adam (Male Host)**: Choose from 7 male voices
4. Tap **Generate**

---

## Available Murf Voices

### Female Voices (for Sarah)
- Natalie (Conversational)
- Iris (Professional)
- Brianna (Friendly)
- Hazel (Warm)
- Daisy (Upbeat)
- Julia (Clear)
- Alison (Calm)

### Male Voices (for Adam)
- Miles (Authoritative)
- Michael (Friendly)
- Cooper (Professional)
- Terrell (Engaging)
- Marcus (Deep)
- Lucas (Conversational)
- Ken (Warm)

---

## Technical Notes

- Voice settings are persisted to SharedPreferences with keys:
  - `tts_murf_voice` - Primary/female voice
  - `tts_murf_voice_male` - Secondary/male voice for podcasts
- The Murf API uses voice IDs in format: `en-US-{name}` (e.g., `en-US-natalie`)
- Podcast generation uses "Conversational" style for more natural dialogue feel
