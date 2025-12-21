## Capability
- Yes. The app includes a Web Search feature backed by Serper (Google SERP).
- Core pieces:
  - `lib/core/search/serper_service.dart:33–55` — POST to `https://google.serper.dev/search` with `X-API-KEY`.
  - `lib/core/search/serper_config.dart:5–14` — loads `SERPER_API_KEY` from `.env` and sets `baseUrl`.
  - `lib/core/search/search_provider.dart:13–20` — Riverpod notifier calling `SerperService.search`.
  - `lib/features/search/web_search_screen.dart:27–32, 250–267` — UI to run search and list results; add sources.
  - `lib/core/router.dart:58–61` — route `/search` for Web Search.

## Configuration Steps
1. Add `SERPER_API_KEY` to `.env` (no hard‑coded keys) and ensure `.env` is loaded (already listed in `pubspec.yaml:48`).
2. Verify network permissions and that `http` dependency is present (confirmed in `pubspec.yaml:25`).

## Usage Verification
- Navigate to `/search` and enter a query; results stream into the list.
- Use “Add Source” to fetch page content (`serper_service.dart:75–87`) and save as a web source.
- Open Chat and ask questions; answers cite added web sources.

## Enhancements (Optional, real functionality)
- Expose filters using `SerperConfig.dateRanges` and domain restriction (`serper_service.dart:36–54`).
- Replace basic HTML stripping with a parser for cleaner content extraction.
- Move search/content fetch to a Supabase Edge Function for quota/rate‑limit control and secure key storage.

## Security & Compliance
- No hard‑coded secrets; `.env` only. Prefer server‑side key usage if moving to Edge Functions.

## Validation Plan
- Run the Web Search screen with a valid `SERPER_API_KEY`, perform searches, add sources, and confirm citation‑backed chat works end‑to‑end.
- Check error handling when the key is missing (“Missing SERPER_API_KEY”) to ensure clear feedback.