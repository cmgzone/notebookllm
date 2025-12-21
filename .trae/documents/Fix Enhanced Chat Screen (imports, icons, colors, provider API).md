## Goals
- Make `lib/features/chat/enhanced_chat_screen.dart` compile and pass analyzer.
- Align with project conventions (providers, icons, color APIs), avoid deprecated usage.

## Changes
- Imports
  - Add `import 'dart:convert';` to support `JsonEncoder.withIndent(...)`.
  - Remove unused `import 'package:flutter/services.dart';` (no references in file).

- Provider API
  - Replace `ref.read(chatProvider.notifier).sendMessage(text, context);` with `ref.read(chatProvider.notifier).send(text);` to match `ChatNotifier.send(String)`.

- Icons (lucide_icons)
  - Normalize to snake_case identifiers supported by the package:
    - `LucideIcons.fileText` → `LucideIcons.file_text`
    - `LucideIcons.clipboardList` → `LucideIcons.clipboard_list`
    - `LucideIcons.fileStack` → `LucideIcons.file_stack`
    - `LucideIcons.messageCircle` → `LucideIcons.message_circle`

- Colors (deprecated API)
  - Replace all `withOpacity(...)` calls with `withValues(alpha: ...)` per Flutter SDK deprecation guidance:
    - AI writing status gradient and border
    - _WritingModeChip background/border/icon/text colors
    - Empty chat view gradient, icon, helper text
    - Export option tile leading background and trailing icon opacity
    - Chat input area outlines and surfaceVariant background
    - Message bubble citations pill background and text opacity

## Verification
- Run `flutter analyze lib/features/chat/enhanced_chat_screen.dart` to ensure no errors or warnings.
- Sanity-check UI interactions (AI writing dialog, export dialog, message sending) compile against existing providers.

## Notes
- No routing changes are required; the screen doesn’t use `context.push`.
- No MD documentation updates needed for this fix. If desired, we can later add a usage note in an existing MD doc.

## Outcome
- The screen compiles cleanly, icon names match the `lucide_icons` package, provider calls are correct, and color APIs avoid deprecation warnings.