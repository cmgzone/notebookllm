## Overview
- Add first-class support for image and video upload, storage, and playback using Supabase Storage and Flutter packages.
- Wire into existing Sources UI so uploads become real sources (not placeholders).
- Keep buckets private and use signed URLs for secure viewing.

## Storage Setup
- Create Supabase Storage bucket `media` (or reuse `sources` if aligning with docs) with private access.
- Add RLS policies so each user can read/write only their own folder `user_id/*`.
- Store original files under `media/<user_id>/<yyyyMMdd_HHmmss>/<filename>`.

## Client Upload Flow
- Use `file_picker` for selecting images/videos; supports camera/gallery and filesystem.
- Implement `MediaService` that:
  - Resolves current user from `Supabase.instance.client.auth.currentUser` (lib/core/backend/supabase_service.dart:12–19).
  - Uploads via `supabase.storage.from('media').upload(path, fileBytes, fileOptions)`.
  - Detects MIME type and returns storage `path`.
  - Generates short-lived signed URL for preview `supabase.storage.from('media').createSignedUrl(path, expiresIn)`.
- UI wiring in `AddSourceSheet` to trigger pickers for Image/Video and call `MediaService.upload`.

## Metadata & RLS
- Create `media_assets` table with columns:
  - id (uuid), user_id (uuid), bucket (text), path (text), type (enum: image|video), mime (text), size_bytes (int), width (int, nullable), height (int, nullable), duration_sec (float, nullable), created_at (timestamptz).
- RLS: users can access only rows where `user_id = auth.uid()`.
- After upload, insert a row and return it to the client to show in Sources.

## Display & Playback
- Images: use `Image.network(signedUrl)` with caching `cached_network_image`.
- Videos: use `video_player` (+ optional `chewie` for controls) with `VideoPlayerController.network(signedUrl)`.
- Provide progress UI and error handling; fall back to retry for expired signed URLs.

## Optional Processing (later)
- Thumbnails: generate on client for videos using `video_thumbnail` and upload alongside original.
- OCR for images and transcription for videos via Edge Functions, then attach extracted text to a Source for RAG ingestion.

## How You’ll Use It
- In the app: tap “Add source” → choose Image or Video → pick file → upload runs and adds a Source entry with preview; tap to view.
- Signed URLs prevent public access; links refresh automatically on view.

## Files To Update
- `lib/main.dart:17–25` confirms Supabase init.
- `lib/core/backend/supabase_service.dart:4–19` supplies client and readiness.
- `lib/features/sources/add_source_sheet.dart:44–73` add Image/Video actions and call picker/upload.
- `lib/features/sources/enhanced_sources_screen.dart:279–289` already opens AddSourceSheet.
- New `lib/core/media/media_service.dart` (upload + signed URLs) and `lib/features/sources/media_upload_notifier.dart` (progress/state) for clean architecture.

## Step-by-Step Implementation
1. Add Flutter packages: `file_picker`, `video_player`, `cached_network_image`, `mime`.
2. Create `MediaService` with methods:
   - `Future<MediaAsset> uploadImage(FilePickerResult result)`
   - `Future<MediaAsset> uploadVideo(FilePickerResult result)`
   - `Future<String> signedUrl(MediaAsset asset, {Duration ttl})`
3. Update `AddSourceSheet` to add Image/Video tiles that invoke picker and show progress; on success, insert a Source referencing `media_assets.id` and preview URL.
4. Build viewers:
   - ImageViewer screen using `Image.network`.
   - VideoPlayer screen using `VideoPlayerController.network`.
5. Backend: create `media_assets` table and RLS policies; create Storage bucket and policies.
6. Edge Function hooks (optional): OCR/transcription → enrich Source content and call existing ingest flow.

## Notes
- Aligns with `.trae/documents/Integrate Supabase Backend.md` for Storage buckets and signed URLs.
- No hard-coded secrets; bucket names/constants defined centrally and referenced via config.
- Uploads require logged-in users for ownership enforcement.

Confirm this plan to proceed with implementation and wiring in the Flutter app.