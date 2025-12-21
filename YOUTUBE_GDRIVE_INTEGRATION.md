# YouTube & Google Drive Integration

## Overview

Your Notebook AI app now supports adding content from YouTube videos and Google Drive files, in addition to the existing support for images, videos, audio, and web URLs.

## Features Added

### 1. YouTube Integration
- **URL Support**: Accepts multiple YouTube URL formats:
  - `https://youtube.com/watch?v=VIDEO_ID`
  - `https://youtu.be/VIDEO_ID`
  - `https://youtube.com/embed/VIDEO_ID`
  - `https://youtube.com/v/VIDEO_ID`

- **Functionality**:
  - Validates YouTube URLs before submission
  - Extracts video ID from URL
  - Calls backend to fetch transcript
  - Stores transcript for AI processing

### 2. Google Drive Integration
- **Supported File Types**:
  - Google Docs
  - Google Sheets
  - Google Slides
  - PDFs and other documents

- **URL Support**:
  - `https://drive.google.com/file/d/FILE_ID`
  - `https://drive.google.com/open?id=FILE_ID`
  - `https://docs.google.com/document/d/FILE_ID`
  - `https://docs.google.com/spreadsheets/d/FILE_ID`
  - `https://docs.google.com/presentation/d/FILE_ID`

- **Functionality**:
  - Validates Google Drive URLs
  - Extracts file ID and type
  - Calls backend to fetch content
  - Stores content for AI processing

### 3. Content Extractor Service
A new service (`ContentExtractorService`) handles content extraction for:
- YouTube videos (transcript extraction)
- Google Drive files (content extraction)
- Web URLs (web scraping)

## Files Created/Modified

### New Files:
1. `lib/features/sources/add_youtube_sheet.dart` - YouTube URL input sheet
2. `lib/features/sources/add_google_drive_sheet.dart` - Google Drive URL input sheet
3. `lib/core/sources/content_extractor_service.dart` - Content extraction service

### Modified Files:
1. `lib/features/sources/add_source_sheet.dart` - Added YouTube and Google Drive options
2. `lib/features/sources/add_url_sheet.dart` - Enhanced with content extractor

## Backend Requirements

### Supabase Edge Function: `ingest_source`

The backend function should handle these request types:

```typescript
// YouTube request
{
  "url": "https://youtube.com/watch?v=...",
  "type": "youtube"
}

// Google Drive request
{
  "url": "https://drive.google.com/file/d/...",
  "type": "drive"
}

// Web URL request
{
  "url": "https://example.com/article",
  "type": "url"
}
```

### Expected Response:
```json
{
  "content": "Extracted text content...",
  "transcript": "Video transcript..." // for YouTube
}
```

### Required API Keys (in Supabase Secrets):
- `OPENAI_API_KEY` or `GEMINI_API_KEY` - For embeddings
- YouTube API key (optional, for enhanced metadata)
- Google Drive API credentials (for private files)

## Usage

### For Users:
1. Tap the "+" button to add a source
2. Select "YouTube" or "Google Drive"
3. Paste the URL
4. The app will:
   - Validate the URL
   - Extract content via backend
   - Store in your notebook
   - Make it searchable via AI

### For Developers:

#### Adding YouTube Video:
```dart
final extractor = ref.read(contentExtractorServiceProvider);
final content = await extractor.extractYouTubeContent(youtubeUrl);

await ref.read(sourceProvider.notifier).addSource(
  title: 'YouTube: $videoId',
  type: 'youtube',
  content: content,
);
```

#### Adding Google Drive File:
```dart
final extractor = ref.read(contentExtractorServiceProvider);
final content = await extractor.extractGoogleDriveContent(driveUrl);

await ref.read(sourceProvider.notifier).addSource(
  title: 'Google Doc: $fileId',
  type: 'drive',
  content: content,
);
```

## Error Handling

The implementation includes graceful error handling:
- Invalid URLs show user-friendly error messages
- Backend failures fall back to storing the URL for later processing
- Network errors are caught and displayed to users

## UI/UX Features

### YouTube Sheet:
- Icon: `Icons.video_library`
- Validates URL format before submission
- Shows loading indicator during processing
- Displays helpful hint text

### Google Drive Sheet:
- Icon: `Icons.drive_folder_upload`
- Validates URL format before submission
- Shows supported file types
- Reminds users about file permissions
- Shows loading indicator during processing

## Testing

### Manual Testing:
1. **YouTube**:
   - Try various YouTube URL formats
   - Test with public videos
   - Verify transcript extraction

2. **Google Drive**:
   - Test with Google Docs
   - Test with Google Sheets
   - Test with PDFs
   - Verify file permissions (public vs private)

### Edge Cases:
- Invalid URLs
- Private/restricted content
- Network failures
- Backend API failures

## Future Enhancements

1. **YouTube**:
   - Extract video metadata (title, description, duration)
   - Support playlists
   - Download video thumbnails
   - Support timestamps in transcripts

2. **Google Drive**:
   - OAuth integration for private files
   - Support for folders
   - Batch import
   - Preview file content before adding

3. **General**:
   - Progress indicators for long extractions
   - Retry mechanism for failed extractions
   - Cache extracted content
   - Background processing queue

## Troubleshooting

### "Invalid YouTube URL" error:
- Ensure the URL is from youtube.com or youtu.be
- Check that the video ID is present in the URL

### "Invalid Google Drive URL" error:
- Ensure the URL is from drive.google.com or docs.google.com
- Check that the file ID is present in the URL

### "Content extraction failed":
- Verify SUPABASE_FUNCTIONS_URL is set in .env
- Check that the backend function is deployed
- Verify API keys are set in Supabase secrets
- Check file permissions (for Google Drive)

### "Authentication required":
- Ensure user is logged in
- Check Supabase session is valid

## Notes

- Content extraction happens asynchronously via backend
- Large files may take time to process
- Google Drive files must be publicly accessible or shared with the service account
- YouTube videos must have captions/transcripts available
