## Goals
- Eliminate remaining deprecation and lint warnings for a clean analyzer run.
- Replace placeholder behaviors with real functionality per project rules.
- Keep unused-but-important imports by adding real usages.
- Verify end-to-end with analyzer and a local run.

## Deprecation & Lint Cleanup
- Replace `withOpacity(...)` with `withValues(alpha: ...)` across UI files:
  - `lib/features/chat/chat_screen.dart`
  - `lib/features/chat/citation_drawer.dart`
  - `lib/features/home/home_screen.dart`
  - `lib/features/sources/add_source_sheet.dart`
  - `lib/features/sources/add_url_sheet.dart`
  - `lib/features/sources/sources_screen.dart`
  - `lib/theme/app_theme.dart` (chipTheme, dividerTheme still use `withOpacity`)
  - `lib/ui/widgets/notebook_card.dart`
- Add missing `const` to constructor calls flagged by analyzer in:
  - `lib/features/sources/add_source_sheet.dart`
  - `lib/features/sources/sources_screen.dart`
  - Other spots indicated by analyzer suggestions.
- Keep or remove unused imports according to rules:
  - If import is important, add actual usage (e.g., navigate to source/artifact screens from citations).

## Real Functionality: Add URL Content
- Add `http` dependency to `pubspec.yaml`.
- Implement real fetch in `AddUrlSheet`:
  - Validate URL; fetch HTML via `http.get`.
  - Extract readable text (basic HTML strip to keep dependencies minimal).
  - Store in `SourceNotifier.addSource(...)` with real `content` and `addedAt`.

## Real Functionality: Citations & Sources
- Enhance `CitationDrawer` entries to open a Source detail screen showing the actual `content`:
  - Add a simple `SourceDetailScreen` that renders the source title and content.
  - Wire the trailing open button to navigate.
- Ensure `SourcesScreen` “open” button also navigates to the same detail screen.

## Real Functionality: Chat Grounding (Incremental)
- Update `ChatNotifier.send(text)` to ground responses on stored sources:
  - If sources exist, build an answer by concatenating relevant snippets from `Source.content`.
  - Create `Citation` entries pointing to actual snippets with `start/end` indices.
  - If no sources, return a helpful message explaining to add sources first.
- Keep logic deterministic and side-effect free (no external services/secrets).

## UX Consistency
- Confirm icon replacements are complete and consistent (`Icons.mic_none`/`Icons.mic`).
- Verify `endDrawer` opens from the correct context (already fixed via `Builder`).

## Verification
- Run `dart pub get`.
- Run `dart analyze` to ensure 0 errors and minimal warnings.
- Launch the app and smoke test:
  - Add a web URL; confirm real content fetched and listed with correct date.
  - Open a source detail screen from both Sources and Citations.
  - Ask a question; see grounded answer with citations.

## Notes
- No secrets/hardcoded credentials will be introduced.
- All new functionality is real, deterministic, and contained within the app.
- Minimally add dependencies (`http`) only when used.

Please confirm, and I will implement these changes and verify end-to-end.