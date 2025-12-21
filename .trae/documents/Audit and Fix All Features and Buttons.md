## Scope
- Audit all pages and buttons: onboarding, login, home, sources, chat, studio, search, artifact.
- Fix broken or placeholder handlers; add real functionality per project rules.
- Verify Supabase integration and environment setup without hard-coded secrets.
- Use existing architecture and providers; follow conventions.

## Current Findings
- Unimplemented controls in `lib/features/studio/audio_player_sheet.dart` for `skip_previous`, `skip_next`, `share`, `download`.
- Empty handler on source list trailing button in `lib/features/sources/sources_screen.dart`.
- Placeholder artifact content generator exists for empty data; keep but ensure real paths are used when sources exist.
- Routes defined in `lib/core/router.dart`; major screens present and mostly wired.
- Supabase client initialization in `lib/main.dart` and `lib/core/backend/supabase_service.dart` with `.env` keys.
- Edge functions for RAG (`answer_query`, `ingest_source`, `web_search`) deployed via `scripts/deploy_supabase.ps1`.

## Implementation Plan
### 1) Environment & Supabase
- Confirm `.env` has `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_FUNCTIONS_URL`, `SUPABASE_MEDIA_BUCKET`.
- Keep secrets out of code; use provided initialization and warning banner.
- Validate RPC `vector_search_cosine` and function endpoints via the existing scripts and providers.

### 2) Audio Player Controls
- Implement `skip_previous`/`skip_next` in `lib/features/studio/audio_player_sheet.dart` using `audioPlaybackProvider`/`just_audio` queue navigation.
- Ensure UI state reflects current track and duration; reuse existing play/pause logic.
- Add error handling and disabled state when queue bounds are reached.

### 3) Share & Download in Audio Player
- Implement `share` via exporting current audio or link using `share_plus` (add dependency if missing) with safe file access via `path_provider`/cache.
- Implement `download` to app documents directory and show a toast/snackbar confirmation.
- Respect permissions and platform nuances; no hard-coded paths.

### 4) Source Item Open Action
- Wire trailing `open_in_new` in `lib/features/sources/sources_screen.dart` to open the source:
  - If URL: use `url_launcher` to open in browser.
  - If stored asset: navigate to `artifact_viewer_screen.dart` with proper provider data.
- Add loading/error states and graceful fallbacks.

### 5) Button Audit & Fixes
- Review all screens for buttons with missing handlers:
  - Chat exports (`_exportAsMarkdown|Text|JSON`) ensure they write real data and confirm success.
  - Studio action tiles `_generateArtifact`/`_generateAudioOverview` validate provider outputs and handle empty states.
  - Home add notebook and logout flows verified; fix any errors first.
- Remove placeholder onPressed stubs; ensure every button performs a meaningful action.

### 6) Error Handling & UX
- Standardize error reporting via existing snackbar/dialog patterns.
- Disable buttons when action not possible (e.g., no selection, empty message).
- Follow UI component patterns in `lib/ui/*`.

### 7) Verification
- Run the app and exercise each route; confirm button behavior and absence of runtime errors.
- Add quick widget tests for critical interactions where feasible.
- Validate Supabase calls with test script; ensure 200 responses and correct payloads.

### 8) Documentation References
- Align changes with existing docs:
  - `.trae/documents/Integrate Supabase Backend.md`
  - `.trae/documents/Finalize Cleanup And Implement Real Functionality.md`
  - `.trae/documents/Fix Enhanced Chat Screen...md`
  - `README.md`

## Deliverables
- Implemented audio transport and share/download.
- Functional source open action.
- Audited and fixed buttons across screens.
- Verified app behavior end-to-end with Supabase integration.

## Notes
- No placeholders or hard-coded values.
- Fix errors before moving to new features.
- Keep unused imports only if they gain real functionality as part of these changes.