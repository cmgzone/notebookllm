## Goals
- Enable image/video/audio ingestion with animated progress, previews, and secure storage
- Persist assets in Supabase Storage; reference in `sources` with `storage://bucket/path`
- Trigger Edge Function to chunk/embed text or transcripts; surface citations in Chat

## Architecture
- Client: use existing `MediaService` (`lib/core/media/media_service.dart`) and `AddSourceSheet`
- Buckets: `SUPABASE_MEDIA_BUCKET` (env) default `media` for assets; keep uploads per-user folders
- Source model: add entries with `type: image|video|audio` and `content: storage://...`
- Edge Functions: extend `ingest_source` to handle non-text sources:
  - Image: OCR (server-side) or manual captions; extract text chunks
  - Video/Audio: transcript via server function (or external STT), then chunk and embed

## UI/UX Motion
- Add-source sheet: animated spring backdrop; connector tiles scale on press
- Upload flow: animated progress bar, morphing status icon (pending→uploading→processing→done)
- Preview: image thumbnail; video frame or duration; audio waveform placeholder
- Error feedback: red pulse on failures; retry button with bounce

## Client Implementation
1. Extend `AddSourceSheet` to support audio; keep image/video uploads using `FilePicker`
2. `MediaService.uploadBytes` returns `MediaAsset`; create signed URL for previews
3. Add `SourceProvider.addSource` call with `storageUri`; insert `type`
4. After adding a source, call functions endpoint to `ingest_source` with `source_id`
5. Show animated status (Uploading→Processing→Indexed); update UI to display preview

## Edge Functions
- `ingest_source/index.ts`:
  - If source type is `url` or `file` (text), current chunk+embed path stays
  - If image: perform OCR (e.g., Tesseract or external API) to extract text; then chunk+embed
  - If video/audio: fetch transcript (external STT or stored `transcript` field) then chunk+embed
  - Upsert chunks and embeddings like current flow; link `source_id`

## Security & Config
- Use `.env` keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_FUNCTIONS_URL`, `SUPABASE_MEDIA_BUCKET`
- No hard-coded secrets; service role key and OpenAI key remain server-side only
- Validate user session before uploads; sanitize filenames

## Verification
- Unit tests for `MediaService` path construction and mime detection
- Manual test: upload image and video; confirm source entry; signed preview loads; ingest function runs and returns chunk/embedding counts
- Chat streaming shows citations from new non-text sources

## Rollout Phases
1. Client-side upload UI and animated progress + previews
2. Functions: support image OCR and transcript ingestion
3. Connect ingestion to citations in chat; fallback if no text extracted
4. Optimize performance and add retries/backoff

## References
- `.trae/documents/Add Image_Video Support with Supabase Storage (Flutter).md`
- `lib/core/media/media_service.dart`
- `lib/features/sources/add_source_sheet.dart`
- `supabase/functions/ingest_source/index.ts` and `answer_query/index.ts`