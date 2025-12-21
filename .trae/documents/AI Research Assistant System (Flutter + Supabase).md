## System Overview

* Build a full research assistant on the existing Flutter + Supabase stack, adding web search + credibility scoring, AI-powered note improvement, robust safety filters, multimedia generation (images + audio), and automatic visualizations.

* Keep all secrets in `.env` and reuse Supabase Edge Functions for server-side tasks with streaming responses.

## Existing Stack (baseline)

* Flutter app with Riverpod/GoRouter; Supabase client initialized from `.env`.

* Supabase Postgres with pgvector, RLS; tables: `notebooks`, `sources`, `chunks`, `embeddings`, `conversations`, `messages`.

* Edge Functions already present: `answer_query`, `ingest_source`, `stt`, `tts`, `voices`, `web_search` (extend rather than replace).

* Gemini and OpenAI are already integrated for generation and embeddings, with SSE streaming.

* References: see `AGENTS.md` and `.trae/documents/Integrate Supabase Backend.md` for intended architecture and tooling context.

## Architecture

* Client (Flutter):

  * Providers for research session state, search results, credibility scores, note improvements, moderation verdicts, and visualization assets.

  * UI in `lib/features/*` to orchestrate research pipeline and display sources, notes, visuals, and generated media.

* Server (Supabase Edge Functions):

  * `web_search` → aggregators for search engines/APIs + site verification hooks.

  * `answer_query` → retrieval + LLM synthesis remains central to research answers.

  * New functions: `moderation`, `visualize`, `improve_notes`, `generate_image` (Gemini image), `generate_audio` (TTS based on notes/resources).

* Data:

  * Store improved notes as `sources`, re-chunk and embed via existing ingestion.

  * Track moderation logs, credibility signals, and visualization metadata to ensure reproducibility.

## Web Search & Credibility

* Extend `web_search` function to support:

  * Multi-provider search (e.g., serperAPI via env).

  * Source metadata extraction: author, publication date, domain, schema.org types, citation counts (where available), and HTTPS status.

  * Credibility scoring:

    * Domain reputation list with allow/deny weights.

    * Fact consistency checks via cross-result agreement.

    * Recency weighting and reference presence (DOIs/journal sites > blogs).

  * Site verification (e.g., "Do YouTube buttons work?"):

    * Integrate a headless-browser API provider (Browserless/Playwright-as-a-service) via server call.

    * Execute small DOM assertions (presence of like/share buttons, interactability) and capture screenshots.

  * Persist:

    * Save `search_runs`, `search_results`, `credibility_signals`, and `verifier_artifacts` tables.

  * Client UI:

    * Show results with trust score, evidence, and quick actions to cite/ingest.

## Note Processing (AI Improvement)

* Client captures raw notes and sends to `improve_notes` function:

  * Summarization: concise abstract + key takeaways.

  * Enhancement: clarify ambiguous statements, add citations placeholders when sources are known, propose next-steps/questions.

  * Structure: outline, sections, bullets, tags, and metadata (topics, entities, confidence).

* Storage & reuse:

  * Save improved note as a `source` (text) and trigger `ingest_source` for chunking/embeddings.

  * Link improved notes back to originating notebook entries for traceability.

* UI:

  * Side-by-side original vs improved content; accept/merge workflow; versioning with rollback.

## Content Filtering & Moderation

* Pre-check prompts and sources:

  * Text moderation via OpenAI moderation endpoint (configurable) and Gemini Safety settings.

  * Risk classification (violence, sexual content, hate, self-harm, illegal instructions) with thresholds.

* Image generation filters:

  * Enforce Gemini image safety parameters; optionally validate outputs via Vision SafeSearch-like APIs.

* Output Quality Control:

  * Heuristics for hallucination risk (low citation density, conflicting facts), spam/SEO link farms.

  * Require minimum credibility score before inclusion in final outputs.

* Persistence:

  * `moderation_logs` table with input/output, risk labels, decision, reviewer feedback.

* UI:

  * Transparent moderation badges, viewable logs, and override request flow.

## Multimedia Generation

* Images:

  * Integrate Gemini Image generation (Gemini 2.5 Flash Image aka "Nano Banana" \[1]\[3]\[4]).

  * Inputs: research context + user instructions; outputs: PNG/WebP along with prompt + safety metadata.

* Audio:

  * Use existing `tts`/`voices` functions to synthesize audio summaries from notes and sources; add style parameters (voice, speed, tone).

  * Optional: stitch audio segments for multi-section notes; attach transcript.

* Simultaneous assets:

  * Generate images with annotated notes; build diagrams/charts alongside textual analysis.

  * Bundle outputs into a single research run artifact for export.

## Visualization Tools

* Automatic visuals when users write notes:

  * Mind maps: derive from structured outline; render via Kroki (PlantUML/Mermaid) to PNG/SVG.

  * Concept diagrams: entity-relation or flow diagrams from extracted entities/relations.

  * Charts: generate simple data visuals (bar/line/pie) from tabular findings.

* Accuracy:

  * Require provenance links and section references; avoid speculative nodes without sources.

* Storage:

  * Save `visuals` with type, source references, render parameters, and images.

## End-to-End Research Workflow

1. Accept user input (question/notes).
2. Search: aggregate results + credibility scoring; optional site verification.
3. Retrieve: use embeddings to pull relevant chunks.
4. Improve notes: summarize/enhance/structure.
5. Generate outputs: answer synthesis, images, audio, and visuals.
6. Moderation/QA: apply filters, log decisions, request user approval for overrides.
7. Deliver: present annotated results with citations and assets.
8. Feedback loop: collect user ratings, corrections, and ground truth; update credibility weights.

## Data Model Additions

* `search_runs`, `search_results` (per result metadata), `credibility_signals`, `verifier_artifacts`.

* `moderation_logs` with labels/thresholds/decisions.

* `visuals` with render params and provenance.

* Link tables from `research_runs` to outputs (notes, images, audio, diagrams).

## Environment & Config

* `.env` additions (no hard-coded values):

  * `SUPABASE_ANON_KEY`, `SUPABASE_FUNCTIONS_URL`

  * `GEMINI_API_KEY` (image generation)

  * `OPENAI_API_KEY` (embeddings/moderation) or alternative

  * `SEARCH_API_KEYS` (provider-specific)

  * `BROWSERLESS_TOKEN` (for DOM verification)

* Feature flags for moderation strictness and image safety.

## Security & Privacy

* RLS on all user-owned tables; server-side checks in every function.

* Never log secrets; redact PII in logs; opt-in telemetry only.

* Signed URLs for media; short-lived tokens; rate limits per user.

## Testing & Verification

* Unit tests for functions: search aggregation, credibility scoring, moderation decisions.

* Golden tests for note improvement prompts; snapshot tests for visuals rendering.

* E2E flow tests: user → search → improve → generate → moderate → deliver.

* Manual verification hooks for site checks with screenshot artifacts.

## Incremental Implementation Steps

1. Extend `web_search` with multi-provider aggregation and credibility scoring.
2. Add `improve_notes` function and client UI for review/accept.
3. Implement `moderation` function and wire pre/post checks in workflows.
4. Integrate Gemini Image generation in `generate_image` with safety controls.
5. Implement `visualize` function using Kroki to render mind maps/diagrams.
6. Enhance `tts` orchestration for audio summaries with transcripts and packaging.
7. Wire the pipeline in client providers; add research run export.
8. Add tables/migrations for new entities with RLS; update ingestion path.

## References

* \[1] <https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/image-generation>

* \[3] <https://ai.google.dev/gemini-api/docs/image-generation>

* \[4] <https://docs.cloud.google.com/vertex-ai/generative-ai/docs/multimodal/image-generation>

