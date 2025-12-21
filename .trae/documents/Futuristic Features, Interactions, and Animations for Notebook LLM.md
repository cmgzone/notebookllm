## Current Stack Snapshot
- Flutter app with Riverpod, GoRouter, Material 3 and flutter_animate
- Supabase backend with Edge Functions for ingest and answer_query (SSE streaming)
- Screens: Chat, Sources, Studio, Search, Onboarding; Providers per feature
- Reference docs: README.md; .trae/documents/Notebook LLM — Research Findings and Build Plan.md; Integrate Supabase Backend.md

## Product Vision
- A multimodal, agentic notebook that feels alive: responsive, tactile, and context-aware
- Users create, explore, and share knowledge with fluid motion, real-time presence, and AI-powered interactions

## Feature Themes
- Agentic workflows: background tasks, autonomous assistants that operate on sources and notebooks
- Multimodal intelligence: image/video/audio ingestion, understanding, and generation
- Spatial knowledge canvas: graph of sources, notes, and artifacts with zoom/pan and clustering
- Real-time collaboration: live cursors, presence, shared chat and notebooks via Supabase Realtime
- Voice-first interactions: low-latency STT + streaming TTS for hands-free chat and control
- Generative UI: animations and visuals that react to model signals (tokens, confidence, citations)

## Interaction & Motion System
- Motion tokens: durations, easings, delays, and elevation defined centrally
- Page transitions: custom GoRouter transitions (Hero + SharedAxis, fade-through)
- Micro-interactions: press/hover, list reordering, swipe-to-peek, pull-to-expand
- Async feedback: skeletons shimmer, optimistic updates, progress arcs for long tasks
- Haptics and sound: subtle vibrations and auditory cues (mobile) aligned to model events

## Animation Ideas by Screen
- Chat: token stream "typing wave", message enter stagger, citation chips that pulse and connect to source items
- Sources: card stack with parallax, add-source sheet with springy backdrop, upload progress as morphing shapes
- Studio: artifact timeline scrubbable with physics, audio waveforms roll-in, AI transforms with shader-based reveals
- Search: result clusters that group via force layout, hover previews with zoomed thumbnails, facet chips that animate selection
- Onboarding: narrative sequence with step progress ion, confetti from achievements, hero transition into Home

## Multimodal & Voice
- Ingest: images/video/audio to Supabase Storage; metadata + embeddings via Edge Functions
- STT: stream audio chunks client→Edge→model; partial transcript updates to chat
- TTS: streaming playback aligned to token chunks; voice controls for navigation and actions

## Collaboration & Presence
- Supabase Realtime channels per notebook and chat; presence to show avatars and cursors
- Live editing with conflict-free ops (CRDT-like) for notes and artifacts
- Activity feed and comments; emoji reactions that ripple through UI

## 3D/AR & Spatial UI
- Spatial canvas using InteractiveViewer + custom painter for nodes/edges; clustering and focus transitions
- Optional 3D: integrate Rive for GPU-accelerated vector animations; consider flutter_gl for WebGL effects on web
- Mobile AR: overlay notes or search highlights in camera view (ar_flutter_plugin) if scoped later

## Technical Implementation
- Flutter patterns: AnimatedSwitcher, ImplicitlyAnimatedWidgets, AnimationController + flutter_animate chains; Hero/shared axis
- Motion system: a MotionSpec with Riverpod provider; use consistent tokens across app
- GoRouter transitions: custom transition builders per route; shared elements for continuity
- Supabase: Realtime presence and broadcast; storage buckets for media; Edge Functions for embeddings/transforms
- Audio pipeline: just_audio + audio_service for TTS; low-latency audio capture for STT
- Graph canvas: Render tree with CustomPainter; hit-testing and gestures; background worker for layout

## Performance & Accessibility
- Performance budgets: 60fps target; avoid rebuilds via selective Riverpod providers; cache images/video thumbnails
- Accessibility: scalable text via GoogleFonts, focus traversal, screen reader labels, color contrast
- Web/mobile parity: conditional features; degrade gracefully on low-power devices

## Phased Roadmap
1. Motion foundation: MotionSpec, route transitions, core micro-interactions
2. Generative chat UX: token wave, citation animations, skeletons and async states
3. Sources UX: ingest flows with animated feedback; upload progress visuals
4. Spatial canvas (2D): knowledge graph viewer with pan/zoom, clustering, link reveals
5. Multimodal ingest: images/video/audio storage + embeddings + previews
6. Voice interactions: STT into chat, streaming TTS playback with controls
7. Collaboration: presence, live cursors, shared notebooks and chats
8. Optional 3D/AR: Rive-powered effects; AR prototype if mobile-first scope permits

## References (MD)
- .trae/documents/Notebook LLM — Research Findings and Build Plan.md
- .trae/documents/Add Image_Video Support with Supabase Storage (Flutter).md
- .trae/documents/Fix Enhanced Chat Screen (imports, icons, colors, provider API).md
- .trae/documents/Finalize Cleanup And Implement Real Functionality.md