## Objectives
- Add Supabase to the Flutter app for Auth, Storage, Postgres (pgvector), and Edge Functions.
- Replace in-memory providers with real persistence and secure server-side LLM calls.
- Keep secrets server-side; no hardcoded keys in client.

## References
- See .trae/documents/Choose and Integrate Backend for Notebook LLM (Supabase RAG).md for architecture and data model.

## Dependencies & Config
- Add `supabase_flutter` and `http` (for SSE) to `pubspec.yaml`.
- Inject `SUPABASE_URL` and `SUPABASE_ANON_KEY` via Dart defines (`--dart-define`), read with `String.fromEnvironment`.

## App Initialization
- Initialize Supabase in `lib/main.dart` before `runApp`.
- Gate router on Auth state: unauthenticated → onboarding/login; authenticated → normal routes.

## Backend Setup (Supabase Project)
- Enable `pgvector`.
- Create tables: `users`, `notebooks`, `sources`, `chunks`, `embeddings`, `conversations`, `messages`, `llm_keys`, `quotas`.
- Create indexes: vector index on `embeddings.embedding`, common FKs and timestamps.
- Apply RLS policies enforcing `user_id = auth.uid()` across user-scoped tables.
- Create Storage buckets (e.g., `sources`, `artifacts`) with signed URL access rules.

## Edge Functions
- `ingest_source`: upload/extract, chunk, embed, upsert embeddings; return status.
- `answer_query`: embed query, vector search, build context, call LLM, stream tokens as SSE (`text`, `citation`, `done`); persist messages/citations.
- Store provider keys in Supabase secrets; optional BYO keys encrypted in DB.

## Flutter Services & Providers
- Create `lib/services/supabase_service.dart` to wrap Auth, Storage, and table CRUD.
- Update `features/notebook/notebook_provider.dart` to load/save notebooks via Supabase tables.
- Update `features/sources/source_provider.dart` to upload to Storage, create `sources` row, trigger `ingest_source`.
- Update `features/chat/stream_provider.dart` to replace `_simulateStream` with SSE stream from `answer_query`, yielding `text/citation/done` tokens.
- Update `features/chat/chat_provider.dart` to persist `messages` per `conversation_id`.

## Routing & UI
- Keep existing routes; add an Auth gate using Supabase session.
- Use existing enhanced screens; wire Riverpod providers to Supabase-backed services.

## Security & Compliance
- No provider secrets in client; all LLM calls server-side.
- Signed URLs for Storage reads; input validation; quotas and rate limits per user.

## Verification
- Run end-to-end: sign in, add a source (file/url/note), ingest, query, receive streaming with citations, and see persisted conversations.
- Measure TTFB and p95 latency; review Supabase logs.

## Milestones
1. Add dependency, config, and Supabase init in `main.dart`; basic Auth gate.
2. Backend bootstrap: schema, RLS, Storage.
3. Implement `ingest_source` and `answer_query`.
4. Migrate providers to Supabase; implement SSE client.
5. End-to-end tests and performance checks.

## Notes
- Ensure `router.dart` continues to resolve enhanced screens (already present) and verify no broken imports.
- Keep local UI/UX unchanged while providers switch to backend persistence.

Approve to proceed with Milestone 1 (SDK, config, init) and backend bootstrap steps.