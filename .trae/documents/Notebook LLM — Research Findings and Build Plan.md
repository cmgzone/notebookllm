## Objectives
- Build a premium, professional Flutter app for a source‑grounded Notebook LLM.
- Start with UI/UX: information architecture, design system, navigation, key screens, and interaction/motion.

## Technical Choices
- Flutter (Material 3) with `ColorScheme` + `ThemeData` + custom `ThemeExtension` for premium tokens.
- Navigation: `go_router` (typed routes, deep links); State: `Riverpod` (scalable, testable); Models: `freezed` + `json_serializable`.
- Responsiveness: `responsive_framework`; Motion: `flutter_animate` + `ImplicitlyAnimatedReorderableList`/`AnimatedSwitcher`.
- Typography: `google_fonts` (serif display + humanist sans body); Icons: `material_symbols`.
- Accessibility: semantics, focus order, large text scaling; i18n with `flutter_localizations`.

## Information Architecture
- Bottom nav (mobile): Home, Sources, Chat, Studio; Settings in profile.
- Notebook detail: header (name/share/progress), tabs/panels (Sources | Chat | Studio), right drawer for citations/notes.
- Global search and quick actions (new notebook, add source, audio overview).

## Design System
- Palette: accessible neutrals + signature gradient accent; glassy cards with soft elevation, blurred overlays.
- Typography scale: Display/Title for notebooks; Body for content/chat; Mono for citations and inline quotes.
- Components: notebook card, source chip, citation badge, streaming message bubble, audio player, connectors list, progress toast.
- Tokens: spacings, radii, shadows, motion durations/curves; dark mode parity.

## Key Screens & Components
- Home
  - Notebook cards: emoji, source count, updated date, quick Play for audio; create notebook CTA.
  - Recent activity, pinned artifacts.
- Sources
  - Source list with provenance badges, re‑sync status (Docs/Slides); add source sheet (Drive/files/URL/YouTube/audio).
  - Source viewer: quote selection, copy with citation.
- Chat
  - Prompt box with source filter chips; streaming answers; numbered inline citations; actions: Save as note, Export.
  - Side drawer: citations inspector with highlighted passages.
- Studio
  - Templates grid: Study Guide, Brief, FAQ, Timeline, Mind Map, Audio Overview.
  - Artifact preview with export/share and edit settings.
- Audio Player
  - Full‑screen: chapter markers, transcript with clickable citations; speed/voice; offline toggle; background playback.

## Interaction & Motion
- Streaming shimmer for messages; subtle pulse on citation anchors.
- Non‑blocking generation: progress toast + in‑panel progress bar; continue navigation while tasks run.
- Drawer transitions (slide‑in + focus trap); chip selection with animated feedback.
- Haptics on mobile for key actions (save, download).

## Accessibility & Internationalization
- WCAG AA: contrast, touch targets, keyboard nav; semantics for citations and quotes.
- RTL, locale‑aware formatting; audio language selection.

## Premium Polish
- Knowledge graph overlay toggle in Chat: visualize entities/relations; click to pivot retrieval.
- Comparative synthesis view: split “consensus vs dissent” with per‑claim citations.
- Notebook insights panel: accuracy score, citation coverage, retrieval diagnostics.

## Delivery Phases
- Phase 0: High‑fidelity wireframes (web/mobile) + design tokens + component library.
- Phase 1: Scaffold Flutter app, global theme, bottom nav, Home + notebook cards.
- Phase 2: Sources panel + add source sheet + source viewer; citation components.
- Phase 3: Chat UI with streaming + filters + citation drawer.
- Phase 4: Studio templates grid + artifact preview; Audio player with offline/background.
- Phase 5: Premium overlays (knowledge graph, comparative view) and insights.

## Validation
- UI tests for navigation, accessibility checks (semantics), golden tests for key components.
- Performance targets: 60fps animations, low jank; memory budget limits for lists and images.

## Notes
- No hard‑coded secrets; all connectors/auth resolved later; placeholder content avoided—only real UI with functional flows as implemented per phase.