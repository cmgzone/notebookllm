## Overview
- Current Flutter app uses in‑memory state for notebooks, sources, chat, and simulated streaming.
- Add a real backend to support auth, persistence, file storage, embeddings/vector search, and streaming LLM responses with citations.

## Recommendation
- Use Supabase as the primary backend: managed Postgres with pgvector, Auth + Row Level Security, Storage, Edge Functions, and solid Flutter SDK.
- Alternatives (Firebase, FastAPI+Postgres+pgvector, Hasura) are viable but introduce more complexity for RAG or higher ops burden; Supabase best balances speed-to-production and capability.

## Architecture
- Flutter client: Supabase Flutter SDK for Auth, CRUD, Storage; calls server-side functions for ingestion and query.
- Supabase Postgres + pgvector: core data with RLS policies per user.
- Supabase Storage: raw files (PDFs/audio/web clips) and artifacts.
- Edge Functions:
  - ingest_source: extract, chunk, embed, write to embeddings.
  - answer_query: embed query, KNN search, build context, call LLM, stream tokens via SSE.
- Secrets: provider LLM keys only on server (Supabase secrets). Optional BYO user keys encrypted in DB.

## Data Model
- users: id, email, plan, created_at
- notebooks: id, user_id, title, updated_at
- sources: id, user_id, notebook_id, type(file/url/note), title, storage_path/url, status, created_at
- chunks: id, source_id, user_id, content_text, token_count, chunk_index, metadata_json
- embeddings: id, chunk_id, user_id, embedding(vector), model, dim, created_at (indexed with IVFFlat/HNSW)
- conversations: id, user_id, title, created_at, last_activity_at
- messages: id, conversation_id, role(user/assistant/system), content_text, tokens, created_at
- llm_keys (optional BYO): id, user_id, provider, key_ciphertext, active, created_at
- quotas: user_id, period, embedding_tokens_used, completion_tokens_used, limits_json
- Policies: RLS on user‑scoped tables: user_id = auth.uid(); strict per‑operation grants.

## Server APIs
- ingest_source(input: source_id or file): returns status; runs extraction → chunking → embeddings upsert.
- answer_query(input: conversation_id, query, filters): streams tokens (text/citation/done) via SSE; persists messages and citations.

## Flutter Integration
- Dependencies to add: `supabase_flutter`, and lightweight `http` for SSE client if needed.
- Init: create Supabase client in `main.dart`; gate UI on auth.
- Persistence:
  - notebook_provider: replace in‑memory with CRUD via Supabase tables.
  - source_provider: upload content to Storage, create source row, call ingest_source.
  - chat/stream_provider: replace `_simulateStream` with SSE to `answer_query`, yielding `text/citation/done` tokens.
- Routing: after auth, load notebooks/sources via Riverpod providers.

## Security
- No client‑side secrets; only server functions hold provider keys.
- Signed URLs for Storage access; input validation on functions; rate limits and quotas per user.
- Optional BYO LLM keys: stored encrypted and used server‑side only.

## Milestones
1. Backend bootstrap: Supabase project, enable pgvector, create tables/indexes, RLS policies, Storage buckets.
2. Edge functions: implement `ingest_source` and `answer_query` with SSE; bind provider keys via Supabase secrets.
3. Flutter wiring: add Supabase SDK, auth screen(s), rewrite providers for persistence, implement SSE streaming in `stream_provider`.
4. Verification: run end‑to‑end ingestion and query; measure latency; add basic tests for providers and streaming; monitor function logs.

## Alternatives Considered
- Firebase: excellent mobile SDKs but lacks native vector search; would require an extra vectordb and more glue.
- FastAPI + Postgres + pgvector: full control and performance; higher ops/time to MVP; build auth/RLS/storage yourself.
- Hasura: strong GraphQL and works with pgvector; more moving parts and streaming complexity.

## Next Step
- If approved, start with Milestone 1 (database schema + RLS + Storage buckets), then implement functions and wire the Flutter client step by step.