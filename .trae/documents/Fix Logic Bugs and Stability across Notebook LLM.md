## Findings Summary
- Env var fallbacks hide critical errors; `.env` bundled in app: `pubspec.yaml:42`, `lib/main.dart:17–26`
- Supabase functions URL unchecked; no format/status validation: `lib/features/chat/stream_provider.dart:55–63`, `lib/features/sources/source_provider.dart:72–84`
- SSE parsing swallows errors; HTTP status unchecked: `lib/features/chat/stream_provider.dart:69–92`
- Supabase result parsing brittle and assumes types: `lib/features/sources/source_provider.dart:33–49`, `lib/features/notebook/notebook_provider.dart:30–45`
- Controllers created without disposal in stateless/dialog contexts: `lib/features/chat/chat_screen.dart:138`, `lib/features/sources/add_url_sheet.dart:10`, dialogs in `enhanced_*`

## Phase 1: Stream and HTTP Robustness
- Update `lib/features/chat/stream_provider.dart`:
  - Check `resp.statusCode` before reading stream; on non-200 add an error `StreamToken` and close.
  - Parse SSE safely; add error token path and ensure a single close (guard `isClosed`).
  - Include `user_id` only when non-null; otherwise add a user-facing token explaining login required.
- Update `lib/features/sources/source_provider.dart`:
  - Validate `functionsUrl`; check `resp.statusCode` and log body on failure.
  - Use `Authorization` only if token present; surface missing token clearly.

## Phase 2: Safe Supabase Parsing
- Harden mapping in `lib/features/sources/source_provider.dart` and `lib/features/notebook/notebook_provider.dart`:
  - Avoid unchecked casts; validate `added_at`/`updated_at` and safely parse `DateTime`.
  - Default optional fields (`content`, `source_count`) without hiding schema mismatches; log anomalies.
- Keep `supabaseClientProvider` but introduce a readiness provider for clearer gating of load calls.

## Phase 3: Controller Lifecycle
- Convert `_PromptBar` in `lib/features/chat/chat_screen.dart` to `ConsumerStatefulWidget` that disposes its `TextEditingController`.
- Convert `lib/features/sources/add_url_sheet.dart` to `ConsumerStatefulWidget` and dispose controller.
- Ensure dialog-local controllers are disposed:
  - `lib/features/sources/enhanced_sources_screen.dart` AI Research dialog.
  - `lib/features/chat/enhanced_chat_screen.dart` AI Writing dialog (keep local but ensure disposal via dedicated widget or explicit dispose on close).

## Phase 4: Env Var Validation
- In `lib/main.dart`, fail loudly when `SUPABASE_URL`/`SUPABASE_ANON_KEY` are missing: show startup banner/toast and disable Supabase features gracefully.
- Validate `SUPABASE_FUNCTIONS_URL` format early; guide users to configure.
- Replace configs that return `''` (Gemini/Serper) with explicit error signaling.
- Review `.env` asset inclusion for production security per docs.

## Phase 5: ID Generation and Integrity
- Stop generating `id` via `millisecondsSinceEpoch`; let Supabase generate IDs server-side.
- After insert, re-fetch or use returned row to maintain local state integrity.

## Phase 6: Tests and Verification
- Add unit tests for:
  - SSE error handling (non-200 response ⇒ error token, controller closes once).
  - Safe parsing of Supabase rows with missing/invalid fields.
  - Controller disposal in refactored widgets.
- Add integration smoke for missing env vars to verify visible error and disabled features.

## References
- See `README.md` for project setup and environment details.
- See `.trae/documents/Fix Critical Bugs, Secrets, and Stability Issues.md` for security and stability guidance.
- See `.trae/documents/Integrate Supabase Backend.md` for backend configuration best practices.