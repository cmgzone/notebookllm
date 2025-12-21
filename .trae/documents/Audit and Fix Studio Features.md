## Audit Summary
- Artifact templates: working with real generation using ingested chunks; falls back to placeholders when no sources (`lib/features/studio/artifact_provider.dart:42–64`, `66–143`, `145+`).
- Artifact viewer: working and supports share (`lib/features/studio/artifact_viewer_screen.dart:15–20`, `39–63`, `73–83`).
- Artifacts history: working (`lib/features/studio/studio_screen.dart:24–29`, `143–176`).
- Audio overview generation: NOT real; uses hard-coded URL and duration (`lib/features/studio/audio_overview_provider.dart:6–16`).
- Audio playback sheet: controls and actions wired (`lib/features/studio/audio_player_sheet.dart:70–99`, `120–157`).
- Audio handler: core actions implemented; skip next/previous no-ops (`lib/core/audio/audio_handler.dart:53–74`).

## Fix Plan
### 1) Real Audio Overview Generation
- Replace hard-coded generation in `audio_overview_provider.generate` with real TTS via Supabase Edge Function `/tts` (pattern already used in chat: `lib/features/chat/enhanced_chat_screen.dart:93–140`).
- Input text: derive from latest artifact or an AI summary of current sources; ensure user is authenticated.
- On success, store audio in Supabase Storage (`lib/core/media/media_service.dart:36–51`) and save `storage://bucket/path` URI to overview.
- Retrieve signed URLs when needed (`lib/core/media/media_service.dart:53–59`).
- Determine duration by preloading the audio with `just_audio` and reading `duration` before storing.

### 2) Offline Caching to Real Files
- Update `lib/core/audio/audio_cache.dart` to download audio to the app documents directory and persist a local path; maintain `isOffline` and avoid placeholders.
- Optionally add a `localPath` field to `AudioOverview` or maintain a mapping in the cache state.
- Show success/failure via SnackBar; keep share and download actions intact in the sheet.

### 3) Audio Overview History
- Add a simple history modal for generated audio overviews similar to artifacts, listing title and date, playable via `AudioPlayerSheet` for selection.
- Provide share and delete options per item where appropriate.

### 4) Audio Handler Improvements
- Implement `skipToNext/skipToPrevious` in `lib/core/audio/audio_handler.dart` using a `ConcatenatingAudioSource` queue; keep UI-driven skip working even if handler-level skip is not used.

### 5) Artifact Generation Quality
- Ensure ingestion uses real embeddings when available by enabling Supabase and related API keys; rely on `smart_ingestion_provider` and edge functions (`supabase/functions/ingest_source`) as documented.
- Keep placeholder content only as fallback when sources are empty per project rules.

### 6) Configuration & Docs
- Confirm `.env` keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_FUNCTIONS_URL`, `SUPABASE_MEDIA_BUCKET`.
- Align changes with `.trae/documents/Finalize Cleanup And Implement Real Functionality.md` and `.trae/documents/Expand ElevenLabs Audio Features_ Voice Selector, STT Capture, Streaming, and Robust UX.md`.

### 7) Verification
- Exercise Studio tiles for all artifact types and audio overview end-to-end.
- Validate TTS function calls return signed URLs; confirm playback, share, and download.
- Add small widget tests for artifact navigation and audio sheet controls.

## Deliverables
- Real audio overview generation tied to Supabase Functions and Storage.
- Offline caching implemented with real file downloads.
- Audio overview history UI.
- Optional audio handler skip support.
- Verified Studio features with working buttons and non-placeholder behavior.