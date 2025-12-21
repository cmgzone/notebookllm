## Priority Order
1) Fix compile blocker in router
2) Remove hard-coded secrets and placeholder URLs
3) Guard unsafe null assertions and runtime crash risks
4) Address diagnostics (deprecated APIs, unused variables, prints)
5) Improve Supabase Edge Function fallback and error handling
6) Verify end-to-end (Flutter build + backend test)

## Immediate Fixes
- Router import/usage
  - Replace mismatched import and undefined identifier
  - `lib/core/router.dart:44` use `SourcesScreen` only if imported from `lib/features/sources/sources_screen.dart`
  - Align import: change `import '../features/sources/enhanced_sources_screen.dart';` to `import '../features/sources/sources_screen.dart';` or update route builder to `EnhancedSourcesScreen()`
  - Add safe handling for `state.extra` casting: `lib/core/router.dart:67`

## Security and Config
- Gemini key removal
  - `lib/core/ai/gemini_config.dart:3` remove hard-coded key; load `GEMINI_API_KEY` via `flutter_dotenv` and surface a clear error if missing
- Serper key removal
  - `lib/core/search/serper_config.dart:6, 9–15` remove demo key and environment default; load `SERPER_API_KEY` via `.env`
- Supabase Functions URL
  - `lib/features/chat/stream_provider.dart:57` remove placeholder `'https://YOUR_PROJECT.functions.supabase.co'`
  - Require `SUPABASE_FUNCTIONS_URL` from `.env`; if missing, send a visible stream error token and disable remote streaming

## Runtime Safety
- Audio handler map lookups
  - `lib/core/audio/audio_handler.dart:31` replace `[...]!` with safe lookup and default (`AudioProcessingState.idle`)
  - Hide or disable skip controls until queue is implemented; remove TODOs or implement minimal queue
- Share target null-guard
  - `lib/features/studio/artifact_viewer_screen.dart:77` guard `box != null` before `localToGlobal`; provide fallback `Share.share(...)` without `sharePositionOrigin` when null
- Router extra casting
  - `lib/core/router.dart:67` guard `state.extra` type before casting to `Artifact`; if invalid, redirect to a safe screen or show error

## Diagnostics and Lints
- Replace prints with logging
  - `lib/main.dart:22`, `lib/core/rag/real_ingestion_service.dart:48`, `lib/features/sources/source_provider.dart:16,20,27,29,47`, `lib/features/notebook/notebook_provider.dart:13,17,24,26,43` → use `debugPrint(...)` or a consistent logger
- Remove/Use unused locals
  - `lib/features/chat/stream_provider.dart:47` remove unused `score` or use it meaningfully
  - `lib/features/onboarding/onboarding_completion_screen.dart:193` remove unused `scheme`
- Fix always-true condition
  - `lib/core/backend/supabase_service.dart:15` remove redundant null check or correct logic so the condition is meaningful
- Update deprecated API usage
  - Replace `.withOpacity(...)` calls with `.withValues(alpha: ...)` (or equivalent) in:
    - `lib/features/onboarding/onboarding_screen.dart:60–297`
    - `lib/features/search/web_search_screen.dart:99–641`
    - `lib/features/onboarding/onboarding_completion_screen.dart:60–201`

## Supabase Edge Functions
- Answer query fallback logic
  - `supabase/functions/answer_query/index.ts:54–66` replace `.order('embedding', ...)` fallback with SQL cosine distance using `<=>` operator or call `rpc('vector_search_cosine', ...)` correctly
  - Improve error handling: if vector search fails, return an explicit degraded-mode message and restrict results to recent chunks
- Type tightening
  - Reduce `any` usage; add interfaces for chunks/messages to prevent silent errors

## Verification
- Flutter app
  - Run Dart analyzer and build; ensure router compiles and onboarding/search screens pass deprecation checks
  - Validate runtime paths that previously used `!` are now safe
- Backend
  - Invoke `answer_query` with known inputs; verify top-K behaves and errors surface clearly
- Configuration
  - Confirm `.env` values (`GEMINI_API_KEY`, `SERPER_API_KEY`, `SUPABASE_FUNCTIONS_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`) load via `flutter_dotenv` in `lib/main.dart`

## References
- `README.md`: project overview and environment setup
- `AGENTS.md`: tooling and coding rules
- `.trae/documents/*.md`: integration notes and development guidelines