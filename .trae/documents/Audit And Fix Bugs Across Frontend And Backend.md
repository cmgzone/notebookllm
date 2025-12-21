## Scope
- Audit the entire codebase (Flutter frontend + Supabase backend + scripts).
- Implement real fixes, no placeholders or hard‑coded secrets.
- Verify via analyzer, local run, and test script.

## Key Findings (to fix)
- Router import/name collision: `lib/core/router.dart:83` uses `SourcesScreen` while both `lib/features/sources/enhanced_sources_screen.dart:21` and `lib/features/sources/sources_screen.dart:9` define `SourcesScreen` — ambiguous and error‑prone.
- Env validation is too silent: `lib/main.dart:37–46` swallows `.env`/Supabase init errors.
- Backend migration not idempotent: `supabase/migrations/20251118000001_rls_policies.sql:4–34` duplicates policies from `0001_init.sql` and will fail on re‑apply.
- Hard‑coded non‑secret default: `supabase/functions/tts/index.ts:8` default voice id `'21m00Tcm4TlvDq8ikWAM'` (violates “no hard coded values”).
- Error hygiene and input validation gaps in functions: `answer_query`, `web_search`, `stt`, `tts`, `ingest_source` return upstream bodies and accept oversized inputs.
- Script secrets & error handling: `scripts/test_ai.ps1:4` hard‑coded password; multiple `Invoke-RestMethod` calls without `-ErrorAction Stop`; null‑unsafe response reads at `57–59`.
- Testsprite doc notes to honor: `.trae/documents/*` include guidance on secrets, router, and deprecation fixes.

## Frontend Fixes
1. Router unambiguity and safety
- Update `lib/core/router.dart` to explicitly use `EnhancedSourcesScreen` and rename import or class to avoid collision; keep guarded `state.extra` use for `/artifact`.
- Reference: `lib/core/router.dart:51–55, 75–84` and `lib/features/sources/enhanced_sources_screen.dart:21`.

2. Environment validation and UX feedback
- In `lib/main.dart:37–46`, validate `.env` and Supabase keys; show a non‑intrusive banner or log when missing; keep features disabled gracefully.
- Reference docs: `.trae/documents/Fix Logic Bugs and Stability across Notebook LLM.md`.

3. Minor robustness
- Keep existing `.withValues(alpha: ...)` usage; ensure controllers are disposed (already done in `enhanced_chat_screen.dart:46–52`).

## Backend Fixes
1. Idempotent RLS migration
- Wrap each `create policy` in existence checks or remove the duplicate migration `20251118000001_rls_policies.sql`.
- Reference: `supabase/migrations/0001_init.sql` already uses `do $$ begin ... if not exists ... end $$;`.

2. TTS voice id and error hygiene
- `supabase/functions/tts/index.ts`: require `voice_id` from request or `ELEVENLABS_VOICE_ID` env; if absent, return 400; stop echoing upstream error bodies.
- Add text length cap and standard error object `{ error: { code, message } }`.

3. Standardize inputs and errors across functions
- `answer_query/index.ts`: enforce `query` type and max length; on error in plain mode, return generic message with status; keep SSE structured.
- `web_search/index.ts`: bound `num` (1–20), sanitize `domain`, do not return upstream bodies.
- `stt/index.ts`: enforce file size/type; standardize errors.
- `ingest_source/index.ts`: cap `content` and chunk counts; reject invalid `source_id` format.

4. CORS tightening (optional if needed)
- Replace `'*'` with known app origin(s) in `CORS_HEADERS` of all functions.

## Script Fixes
1. Secure credentials and deterministic env
- `scripts/test_ai.ps1`: read password from env or secure prompt; resolve `.env` via `Resolve-Path`; fail with helpful message if missing keys.

2. REST error handling and null guards
- Add `-ErrorAction Stop` everywhere; special‑case 409 on signup; validate `$signin.access_token`, `$user.id`, and guard `$resp.answer`/`$resp.citations` before use.
- Fix log wording: it calls plain JSON (`?plain=1`), not SSE.

## Verification Plan
- Run `flutter analyze`; fix any lints raised.
- Build and run on web (`flutter run -d chrome --web-port 5173`); open app, test routes, login, sources, chat, TTS/STT flows.
- Execute `scripts/test_ai.ps1` with env set to verify end‑to‑end answering and citations.
- Validate Supabase local policies apply cleanly by re‑running migrations.

## Deliverables
- Code updates in the files referenced above, following existing style and patterns; no comments added.
- No secrets committed; all keys read from env.
- Concise summary of changes and verification results.

## References (MD)
- `.trae/documents/Fix Critical Bugs, Secrets, and Stability Issues.md`
- `.trae/documents/Fix Logic Bugs and Stability across Notebook LLM.md`
- `.trae/documents/Enable And Verify Web Search Via Serper.md`
- `.trae/documents/Integrate Supabase Backend.md`