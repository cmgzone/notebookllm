## Goal
Enable real phone-call and in‑app VoIP conversations where an AI can listen and answer, using ElevenLabs for voice, and a realtime conversational AI.

## Architecture
- Telephony (PSTN): Twilio Programmable Voice with bidirectional Media Streams.
- In‑App VoIP: WebRTC via `flutter_webrtc` to a media server (LiveKit/Daily/Agora). 
- AI Pipeline: 
  - STT: OpenAI Realtime (built‑in), or Deepgram.
  - LLM: OpenAI GPT‑4o Realtime for dialog and tool use.
  - TTS: ElevenLabs streaming TTS.
- Storage/Orchestration: Supabase Edge Functions and Storage already in use.

References:
- Existing ElevenLabs TTS upload/sign URL flow in `supabase/functions/tts/index.ts:14–61`.
- Existing ElevenLabs STT ingestion in `supabase/functions/ingest_source/index.ts:160–180`.
- Supabase backend patterns documented in `.trae/documents/Integrate Supabase Backend.md` and `.trae/documents/Choose and Integrate Backend for Notebook LLM (Supabase RAG).md`.

## Recommended AI
- Primary: OpenAI GPT‑4o Realtime API (handles low‑latency audio I/O, turn‑taking, tools). 
- Alternatives: Deepgram Aura + Claude Sonnet; Retell/VAPI (managed telephony agents) if you prefer turnkey.
- TTS: ElevenLabs Realtime/Streaming TTS for natural voice; pick a Voice ID per user.

## Server‑Side (Supabase + Voice Gateway)
1. Create Edge Function `voice_agent_webhook` (Deno):
   - Verify Twilio signatures; return TwiML `<Connect><Stream>` to a voice gateway URL.
   - Configuration via env vars: `TWILIO_AUTH_TOKEN`, `VOICE_GATEWAY_URL`.
2. Stand up a Voice Gateway (Node/TypeScript):
   - Accept Twilio Media Streams (WebSocket), decode µ‑law PCM.
   - Connect to OpenAI Realtime session over WebRTC or WS; forward user audio.
   - Receive AI audio, synthesize with ElevenLabs streaming TTS; stream audio back to Twilio over the same bidirectional stream.
   - Implement barge‑in (interruptions) and latency controls.
3. Logging & transcripts:
   - Store call metadata and transcripts in Supabase tables (`calls`, `call_turns`), upload recordings to Storage.

## Client‑Side (Flutter VoIP)
1. In‑app VoIP:
   - Use `flutter_webrtc` for media capture and playback; connect to a room/SFU (LiveKit/Daily/Agora).
   - Mirror the server pipeline: send mic audio to AI, play ElevenLabs TTS audio in real time.
2. UI additions:
   - "Call AI" button; call screen with waveforms, mute, end, and transcript panel.
   - Settings page: choose AI voice (ElevenLabs Voice ID), greeting, and call behavior.

## Configuration & Env Vars
- `ELEVENLABS_API_KEY` and `ELEVENLABS_VOICE_ID` (already used in `supabase/functions/tts/index.ts:6–9`).
- `OPENAI_API_KEY` (already referenced in `supabase/functions/ingest_source/index.ts:6,22–38`).
- `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`.
- `VOICE_GATEWAY_URL` for Media Streams.
- Store secrets in Supabase secrets; never hard‑code.

## User Setup Flow
- Admin:
  - Acquire ElevenLabs API key; select Voice IDs per workspace.
  - Create Twilio account and phone number; set webhook to `voice_agent_webhook` URL.
  - Enable OpenAI Realtime; set `OPENAI_API_KEY`.
  - Configure call policies (hours, allowed callers) in app settings.
- End User:
  - In Settings, choose voice and greeting.
  - Use "Call AI" (in‑app) or dial the Twilio number; AI answers and converses.

## Security & Compliance
- Verify Twilio signatures on webhooks.
- Encrypt and redact sensitive transcript segments.
- Respect consent and call‑recording laws; configurable opt‑in.

## Milestones
1. Telephony MVP: Twilio number answers, streams to Gateway, AI speaks back with ElevenLabs.
2. In‑app VoIP MVP: WebRTC call to AI, live TTS playback.
3. Settings & personalization: voice selection, greeting, call policies.
4. Transcripts and analytics: searchable logs in Supabase.

## Notes
- We will reuse existing ElevenLabs/STT functions and Supabase patterns from the project docs.
- No hard‑coded values; all secrets via env.
- Real functionality in each step; no placeholders.