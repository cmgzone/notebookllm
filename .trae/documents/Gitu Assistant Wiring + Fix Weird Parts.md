## What’s Wired (Already Works)
- Backend Gitu API router exists and is feature-rich: [gitu.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/routes/gitu.ts)
- Proactive insights endpoint exists (so the UI can load insights): [gitu.ts:L1939-L1946](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/routes/gitu.ts#L1939-L1946)
- Proactive service aggregates data (WhatsApp/tasks/suggestions): [gituProactiveService.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituProactiveService.ts)
- Message gateway stores and broadcasts messages + insight updates: [gituMessageGateway.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMessageGateway.ts)
- Websocket services are wired in server startup: [index.ts:L62-L106](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/index.ts#L62-L106)
- Flutter screens/providers exist for chat + proactive dashboard: [gitu_chat_screen.dart](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/lib/features/gitu/gitu_chat_screen.dart), [gitu_proactive_dashboard.dart](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/lib/features/gitu/gitu_proactive_dashboard.dart), [proactive_insights_provider.dart](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/lib/features/gitu/proactive_insights_provider.dart)

## What’s Weird / Risky (Needs Fix)
- DB schema drift for `gitu_messages` between migrations vs runtime “ensure schema” vs code:
  - Migrations define `created_at + content TEXT + user_id UUID`: [add_gitu_messages.sql](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/migrations/add_gitu_messages.sql)
  - Core migration defines `timestamp + content JSONB + user_id TEXT` (also FK type mismatch vs users.id UUID): [add_gitu_core.sql:L36-L45](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/migrations/add_gitu_core.sql#L36-L45)
  - Runtime startup forces a third schema (`created_at`, `content TEXT`, `user_id UUID`) via `ensureGituSchema()`: [gituSchema.ts:L86-L102](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/config/gituSchema.ts#L86-L102) called in [index.ts:L76-L78](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/index.ts#L76-L78)
  - Runtime code reads/writes `timestamp` and parses JSON from `content`: [gituMessageGateway.ts:L546-L561](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMessageGateway.ts#L546-L561), [gituMessageGateway.ts:L704-L713](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMessageGateway.ts#L704-L713), WhatsApp summary uses `timestamp`: [gituProactiveService.ts:L254-L262](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituProactiveService.ts#L254-L262)
- Migration ordering bug: `add_gitu_core.sql` alters `gitu_linked_accounts` before it’s created: [add_gitu_core.sql:L51-L54](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/migrations/add_gitu_core.sql#L51-L54)
- Platform mismatch: DB constraints include `web` after migration, but runtime identity/platform types don’t include `web`: [update_gitu_platforms.sql](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/migrations/update_gitu_platforms.sql), [gituIdentityManager.ts:L3](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituIdentityManager.ts#L3)
- Scheduler has a real stub: `plugin.execute` only logs and never executes plugins: [gituScheduler.ts:L276-L281](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituScheduler.ts#L276-L281)
- Docs are outdated vs reality (checklist claims insights endpoint missing, but it exists): [GITU_WIRING_CHECKLIST.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/GITU_WIRING_CHECKLIST.md)

## Plan (Step-by-Step Fix)
1) Make `gitu_messages` schema canonical
- Choose canonical columns that match real runtime needs: `user_id UUID`, `platform`, `platform_user_id`, `content JSONB`, `timestamp TIMESTAMPTZ`, plus optional `role` + `session_id` (since there’s a migration that expects them).
- Add a new “safe repair” migration that:
  - Adds missing columns (including `timestamp`) if absent
  - Backfills `timestamp` from `created_at` when needed
  - Converts `content TEXT` -> `content JSONB` when needed (wrapping plain text as `{ "text": ... }` only if required)
  - Ensures FK types align with `users(id)` which is UUID: [complete_schema.sql:L10-L25](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/migrations/complete_schema.sql#L10-L25)

2) Fix broken/unsafe migrations
- Fix `add_gitu_core.sql` ordering (move the `ALTER TABLE gitu_linked_accounts ...` after `CREATE TABLE gitu_linked_accounts`, or guard it with an `IF EXISTS`).
- Reconcile `add_gitu_messages.sql` so it no longer conflicts (either update it to match canonical schema or make it a noop if the canonical migration exists).

3) Align runtime `ensureGituSchema()` with migrations
- Update [gituSchema.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/config/gituSchema.ts) to create/alter tables to the same canonical schema (especially `gitu_messages` and `gitu_linked_accounts` platform constraints).
- Optionally gate `ensureGituSchema()` behind an env flag so production uses migrations only, but dev can still self-heal.

4) Fix platform enum drift (`web`)
- Update platform union types and constraints to match `('flutter','whatsapp','telegram','email','terminal','web')` everywhere, including:
  - [gituIdentityManager.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituIdentityManager.ts)
  - Any constraints in migrations (also consider `gitu_sessions` constraint in [add_gitu_core.sql:L16-L27](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/migrations/add_gitu_core.sql#L16-L27))

5) Replace scheduler stub with real plugin execution
- Wire `plugin.execute` to call the existing plugin system and record executions in `gitu_plugin_executions` (table already exists in core migration).

6) Update docs to reflect real wiring
- Update [GITU_WIRING_CHECKLIST.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/GITU_WIRING_CHECKLIST.md) so it lists what is actually wired and what remains.

7) Verify (after code changes)
- Run backend tests and add one focused test that ensures `gitu_messages` read/write works with the canonical columns.
- Do a migration dry-run against a clean DB and confirm server boot no longer produces schema errors.
