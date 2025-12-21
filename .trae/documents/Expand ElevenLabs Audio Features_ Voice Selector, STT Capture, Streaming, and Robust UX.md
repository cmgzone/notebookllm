## Goals
- Let users choose and persist an ElevenLabs voice for TTS
- Add local STT capture using ElevenLabs Speech-to-Text and stream results into Chat
- Improve TTS playback UX with controls, segmented synthesis, and caching
- Keep all secrets server-side; client only uses Functions with bearer auth

## API & Config
- Server env: `ELEVENLABS_API_KEY`, optional `ELEVENLABS_VOICE_ID`, `SUPABASE_TTS_BUCKET`
- Client env already uses `SUPABASE_FUNCTIONS_URL`; reuse bearer auth from Supabase session
- No client-side secrets; all ElevenLabs calls remain in Edge Functions

## Edge Functions
- TTS (`supabase/functions/tts/index.ts`)
  - Add `GET /voices` passthrough to ElevenLabs list voices; return id, name, can_do_tts
  - Accept `voice_id` on TTS POST and store audio to `tts` bucket with signed URL
- STT (`supabase/functions/stt/index.ts` new)
  - Accept multipart audio upload; use `POST /v1/speech-to-text/convert` to return transcript JSON
  - Optional diarization flags; return plain `text` for Chat

## Client — Voice Selector & Persistence
- Settings UI: modal or page under `Home` to list voices and select default
  - Fetch from Functions `/voices`, display name + language; filter by `can_do_text_to_speech`
  - Persist selection in Supabase (user `profiles.voice_id`) or `shared_preferences` fallback
- Provider: `voiceSettingsProvider` to read default voice and hand to TTS calls

## Client — TTS UX
- Enhanced controls in Chat bubbles
  - Play/Pause/Stop buttons; show progress and duration using `just_audio`
  - Use selected voice; pass `voice_id` in TTS POST body
- Segmented synthesis
  - Split long text into ~500–800 chars segments; synthesize sequentially; enqueue to playlist
  - Cache signed URLs in memory for replays; optional write to `shared_preferences`

## Client — STT Capture
- Mic capture: integrate `record` plugin to capture short utterances (push-to-talk)
  - On send, upload audio blob to Functions `/stt` and insert returned text into Chat input
  - Streaming STT (optional next): chunked mic capture, periodic sends, append partial text to input

## Chat Integration
- Add mic button to `_ChatInputArea` (`lib/features/chat/enhanced_chat_screen.dart`) to start/stop recording
- On transcript returned, animate insertion into input; user can edit before send

## Performance & UX
- Guard rails for rate limiting and retries; backoff on Functions failures
- Visual states: recording indicator, uploading, transcribing…; handle errors with actionable messages
- Keep 60fps; avoid rebuilds via scoped providers

## Security
- Only Supabase Functions talk to ElevenLabs; client passes bearer token for auth
- Do not log secrets; redact errors from providers; ensure signed URLs TTLs are limited

## Verification
- Manual tests: TTS generation with multiple voices; STT capture across file formats
- UI tests: Chat bubble TTS controls; mic capture flows
- Confirm audio files stored in `tts` bucket and expire appropriately via signed URL

## References
- `lib/features/chat/enhanced_chat_screen.dart` (current TTS button)
- `supabase/functions/tts/index.ts` (server TTS)
- `supabase/functions/ingest_source/index.ts` (ElevenLabs STT; Gemini vision)
- `pubspec.yaml` (add voice selector UI dependencies if needed)