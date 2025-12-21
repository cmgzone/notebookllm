## Overview
- Implement manual dark mode toggle on top of existing theming.
- Persist user choice (`system`/`light`/`dark`) using `SharedPreferences`.
- Drive `MaterialApp.themeMode` from a Riverpod provider.

## Current State
- Theme definitions exist in `lib/theme/app_theme.dart:5-6` with `AppTheme.light` and `AppTheme.dark`.
- `MaterialApp` uses `themeMode: ThemeMode.system` in `lib/main.dart:103-106`.
- Screens use `AppBar`/`SliverAppBar` (e.g., `lib/features/home/home_screen.dart:19-50`, `lib/features/search/web_search_screen.dart:81-89`). No theme toggle UI.

## Implementation Steps
### Theme Provider
- Create `lib/core/theme/theme_provider.dart` with a `StateNotifier<ThemeMode>` backed by `SharedPreferences`.
- API: `setSystem()`, `setLight()`, `setDark()`, `toggle()` (cycle light↔dark; long-press for system optional), `load()` on init.
- Persist selections under key `theme_mode` as `"system"|"light"|"dark"`.

### Wire Into App
- Update `NotebookLlmApp` in `lib/main.dart` to watch `themeModeProvider` and pass it to `MaterialApp.router(themeMode: currentMode)`, replacing the hard-coded `ThemeMode.system` at `lib/main.dart:103`.
- Ensure provider is available via `ProviderScope` (already present at `lib/main.dart:78-81`).

### UI Toggle
- Add a small reusable widget `ThemeModeAction` (stateless, Riverpod `Consumer`) exposing an `IconButton` that reflects current mode:
  - `ThemeMode.light` → `Icons.light_mode`
  - `ThemeMode.dark` → `Icons.dark_mode`
  - `ThemeMode.system` → `Icons.brightness_auto`
- Place the action in app bars:
  - `HomeScreen` `SliverAppBar.actions` (`lib/features/home/home_screen.dart:28-49`).
  - `WebSearchScreen` `AppBar.actions` (`lib/features/search/web_search_screen.dart:83-88`).
- Optional: reuse in other screens incrementally.

### Persistence & Startup
- On provider initialization, read `SharedPreferences` to set initial `ThemeMode`.
- No hard-coded secrets or values beyond mode strings; follow user rules for real functionality and no placeholders.

### Testing & Verification
- Add a widget test that:
  - Initializes the provider to `ThemeMode.dark`.
  - Pumps `NotebookLlmApp` and verifies `Theme.of(context).brightness == Brightness.dark` for a scaffold.
- Manual run: start the app, toggle theme from Home/Search, confirm persistence across restarts.

## Notes
- Keep existing color schemes; dark theme already defined in `lib/theme/app_theme.dart`.
- If `CardThemeData` at `lib/theme/app_theme.dart:46` causes build errors (Flutter typically uses `CardTheme`), correct it during implementation to avoid lint failures.
- No changes to `.env`/Supabase.
