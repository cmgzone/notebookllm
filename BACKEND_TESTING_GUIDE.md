# Backend Testing Guide - YouTube & Google Drive Integration

## Overview

This guide helps you test the YouTube and Google Drive content extraction Edge Functions.

## Prerequisites

1. ✅ Supabase project set up
2. ✅ Edge Functions deployed
3. ✅ API keys configured as secrets
4. ✅ Flutter app running

## Quick Start

### 1. Deploy Functions

```powershell
# Windows PowerShell
.\scripts\deploy_youtube_gdrive.ps1
```

Or manually:
```bash
supabase functions deploy extract_youtube
supabase functions deploy extract_google_drive
supabase functions deploy ingest_source
```

### 2. Set Required Secrets

```bash
# Required
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...

# Optional (for enhanced features)
supabase secrets set YOUTUBE_API_KEY=AIza...
supabase secrets set GOOGLE_DRIVE_API_KEY=AIza...
supabase secrets set GEMINI_API_KEY=AIza...
```

### 3. Verify Deployment

```bash
supabase functions list
```

Expected output:
```
extract_youtube
extract_google_drive
ingest_source
... (other functions)
```

## Testing YouTube Extraction

### Test 1: Basic YouTube Video

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/extract_youtube \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "video_id": "dQw4w9WgXcQ",
  "text": "Full transcript...",
  "title": "Rick Astley - Never Gonna Give You Up",
  "has_transcript": true
}
```

### Test 2: YouTube Short URL

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/extract_youtube \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://youtu.be/dQw4w9WgXcQ"
  }'
```

### Test 3: Video Without Transcript

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/extract_youtube \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.youtube.com/watch?v=VIDEO_WITHOUT_CAPTIONS"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "video_id": "...",
  "text": "Video title and description",
  "has_transcript": false,
  "warning": "Transcript not available, using metadata only"
}
```

### Test 4: Invalid URL

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/extract_youtube \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://invalid-url.com"
  }'
```

**Expected Response:**
```json
{
  "error": "Invalid YouTube URL or video ID"
}
```

## Testing Google Drive Extraction

### Test 1: Public Google Doc

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/extract_google_drive \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://docs.google.com/document/d/YOUR_DOC_ID/edit"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "file_id": "YOUR_DOC_ID",
  "text": "Document content...",
  "title": "Document Title",
  "file_type": "document"
}
```

### Test 2: Google Sheet

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/extract_google_drive \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID/edit"
  }'
```

### Test 3: Private File (Should Fail)

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/extract_google_drive \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://docs.google.com/document/d/PRIVATE_DOC_ID/edit"
  }'
```

**Expected Response:**
```json
{
  "error": "File is not publicly accessible",
  "suggestion": "Please make the file public or share it with 'Anyone with the link'",
  "file_id": "PRIVATE_DOC_ID"
}
```

## Testing Full Integration (ingest_source)

### Step 1: Create a Source in Flutter App

1. Open the app
2. Tap "+" to add source
3. Select "YouTube" or "Google Drive"
4. Paste URL
5. Note the source_id from the database

### Step 2: Test Ingestion

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/ingest_source \
  -H "Authorization: Bearer YOUR_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "source_id": "YOUR_SOURCE_ID"
  }'
```

**Expected Response:**
```json
{
  "status": "ok",
  "chunks": 15,
  "embeddings": 15
}
```

### Step 3: Verify in Database

Check the `chunks` and `embeddings` tables:

```sql
-- Check chunks
SELECT * FROM chunks WHERE source_id = 'YOUR_SOURCE_ID';

-- Check embeddings
SELECT * FROM embeddings WHERE chunk_id LIKE 'YOUR_SOURCE_ID%';
```

## Testing from Flutter App

### Test YouTube

1. Open app
2. Tap "+" button
3. Select "YouTube"
4. Paste: `https://www.youtube.com/watch?v=dQw4w9WgXcQ`
5. Tap "Add Video"
6. Wait for success message
7. Check Sources list

### Test Google Drive

1. Create a public Google Doc
2. Copy the share link
3. In app, tap "+"
4. Select "Google Drive"
5. Paste the link
6. Tap "Add File"
7. Wait for success message
8. Check Sources list

## Common Test Cases

### YouTube URLs to Test

```
✅ Standard: https://www.youtube.com/watch?v=dQw4w9WgXcQ
✅ Short: https://youtu.be/dQw4w9WgXcQ
✅ Embed: https://www.youtube.com/embed/dQw4w9WgXcQ
✅ Shorts: https://www.youtube.com/shorts/VIDEO_ID
❌ Invalid: https://youtube.com/invalid
❌ Private: https://www.youtube.com/watch?v=PRIVATE_VIDEO
```

### Google Drive URLs to Test

```
✅ Doc: https://docs.google.com/document/d/FILE_ID/edit
✅ Sheet: https://docs.google.com/spreadsheets/d/FILE_ID/edit
✅ Slides: https://docs.google.com/presentation/d/FILE_ID/edit
✅ Drive: https://drive.google.com/file/d/FILE_ID/view
❌ Invalid: https://drive.google.com/invalid
❌ Private: https://docs.google.com/document/d/PRIVATE_ID/edit
```

## Monitoring & Debugging

### View Function Logs

```bash
# Real-time logs
supabase functions logs extract_youtube --follow
supabase functions logs extract_google_drive --follow
supabase functions logs ingest_source --follow
```

### Check Function Status

```bash
supabase functions list
```

### View Secrets

```bash
supabase secrets list
```

### Test Connectivity

```bash
# Test if functions are accessible
curl https://YOUR_PROJECT.supabase.co/functions/v1/extract_youtube \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## Troubleshooting

### YouTube Issues

**Problem**: "No transcript available"
- **Solution**: Video must have captions/subtitles enabled
- **Workaround**: Function falls back to metadata (title, description)

**Problem**: "Invalid YouTube URL"
- **Solution**: Check URL format matches supported patterns
- **Test**: Try with a known working video ID

**Problem**: Rate limiting
- **Solution**: Add YOUTUBE_API_KEY for higher limits
- **Alternative**: Implement caching

### Google Drive Issues

**Problem**: "File is not publicly accessible"
- **Solution**: 
  1. Open file in Google Drive
  2. Click "Share"
  3. Change to "Anyone with the link"
  4. Copy new link

**Problem**: "Failed to extract content"
- **Solution**: Check file format is supported
- **Supported**: Docs, Sheets, Slides, PDFs (metadata)
- **Test**: Try exporting manually first

**Problem**: Empty content
- **Solution**: File might be empty or format not supported
- **Check**: View file in browser to verify content

### General Issues

**Problem**: "unauthorized"
- **Solution**: Check Authorization header has valid token
- **Test**: Get fresh token from Supabase auth

**Problem**: "OPENAI_API_KEY not set"
- **Solution**: Set secret: `supabase secrets set OPENAI_API_KEY=sk-...`
- **Verify**: `supabase secrets list`

**Problem**: Function timeout
- **Solution**: Content might be too large
- **Workaround**: Implement chunking or pagination

## Performance Benchmarks

| Operation | Expected Time | Notes |
|-----------|--------------|-------|
| YouTube transcript | 2-5 seconds | Depends on video length |
| YouTube metadata | 1-2 seconds | Fallback when no transcript |
| Google Doc | 1-3 seconds | Depends on document size |
| Google Sheet | 2-4 seconds | Depends on data size |
| Embeddings | 3-10 seconds | Depends on content length |

## Success Criteria

✅ YouTube videos with captions extract successfully
✅ Public Google Docs extract successfully
✅ Content is chunked and embedded correctly
✅ Sources appear in Flutter app
✅ AI chat can reference the content
✅ Error messages are user-friendly
✅ Private files show appropriate error

## Next Steps

1. ✅ Deploy functions
2. ✅ Test with sample URLs
3. ✅ Verify in Flutter app
4. ✅ Test error cases
5. ✅ Monitor logs
6. ✅ Set up alerting (optional)
7. ✅ Document for users

## Support Resources

- **Supabase Dashboard**: https://app.supabase.com
- **Function Logs**: Dashboard → Edge Functions → Logs
- **Database**: Dashboard → Table Editor
- **Secrets**: Dashboard → Edge Functions → Secrets

## Sample Test Data

### YouTube Videos (Public, with captions)
- Rick Astley: `dQw4w9WgXcQ`
- TED Talks: Usually have captions
- Educational channels: Khan Academy, Crash Course

### Google Drive (Create test files)
1. Create a public Google Doc with sample text
2. Create a public Google Sheet with sample data
3. Share with "Anyone with the link"
4. Use for testing

---

**Happy Testing! 🚀**
