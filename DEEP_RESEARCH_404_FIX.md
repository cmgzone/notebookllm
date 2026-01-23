# Deep Research 404 Error Fix

## Problem
The Deep Research feature was failing with a 404 error:
```
Exception: Network error. This exception was thrown because the response has a status code of 494 and RequestOptions.validateStatus was configured to throw for this status code.
The status code of 404 has the following meaning: "Client error - the request contains bad syntax or cannot be fulfilled"
```

## Root Cause
The frontend was calling the wrong endpoint:
- **Frontend was calling**: `/ai/deep-research-stream`
- **Backend endpoint is**: `/research/stream`

The `/ai/deep-research-stream` endpoint never existed in the backend, causing the 404 error.

## Solution

### 1. Fixed API Service Endpoint (lib/core/api/api_service.dart)
Changed the endpoint from `/ai/deep-research-stream` to `/research/stream` and updated the request format to match the backend's expected parameters:

```dart
// Before
final response = await _dio.post(
  '/ai/deep-research-stream',
  data: {
    'query': query,
    'notebookId': notebookId,
    'maxResults': maxResults,
    'includeImages': includeImages,
    'provider': provider,
    'model': model,
  },
  ...
);

// After
final response = await _dio.post(
  '/research/stream',
  data: {
    'query': query,
    'depth': depth,  // Mapped from maxResults
    'template': 'general',
    'notebookId': notebookId,
  },
  ...
);
```

### 1.1 Fixed Stream Handling (lib/core/api/api_service.dart)
Fixed the type casting issue with the stream transformer:

**Error**: `Type 'Utf8Decoder' is not a subtype of type 'StreamTransformer<Uint8List, String>'`

**Solution**: Properly handle the stream by:
1. Casting to `Stream<Uint8List>` instead of `Stream<List<int>>`
2. Manually decoding bytes using `utf8.decode()` instead of using `.transform()`
3. Buffering incomplete lines to handle SSE events that span multiple chunks
4. Processing complete lines only

```dart
// Get the response stream
final responseStream = response.data.stream as Stream<Uint8List>;

// Buffer to accumulate incomplete lines
String buffer = '';

await for (final chunk in responseStream) {
  // Decode bytes to string
  final text = utf8.decode(chunk, allowMalformed: true);
  buffer += text;
  
  // Process complete lines
  final lines = buffer.split('\n');
  buffer = lines.last; // Keep incomplete line in buffer
  
  for (int i = 0; i < lines.length - 1; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    
    if (line.startsWith('data: ')) {
      final data = line.substring(6).trim();
      if (data == '[DONE]') break;
      
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        yield json;
      } catch (e) {
        debugPrint('[ApiService] Error decoding research event: $e');
      }
    }
  }
}
```

### 2. Updated Response Parsing (lib/core/ai/deep_research_service.dart)
Updated the event parsing to match the backend's actual response format:

**Backend sends**:
```typescript
{
  status: string,
  progress: number,
  sources?: ResearchSource[],
  images?: string[],
  videos?: string[],
  result?: string,
  isComplete: boolean
}
```

**Frontend now correctly parses**:
- `status` - Progress message
- `progress` - Progress value (0.0 to 1.0)
- `sources` - Array of research sources with credibility scores
- `images` - Array of image URLs
- `isComplete` - Whether research is complete
- `result` - Final research report (when complete)

### 3. Added Credibility Parsing
Added proper parsing for source credibility from backend:
```dart
credibility: _parseCredibility(s['credibility'] as String?),
credibilityScore: s['credibilityScore'] as int? ?? s['credibility_score'] as int? ?? 60,
```

## Backend Endpoints
The correct research endpoints are in `backend/src/routes/research.ts`:
- `POST /research/stream` - Streaming research with SSE
- `POST /research/cloud` - Synchronous research (waits for completion)
- `POST /research/background` - Async research (returns job ID)
- `GET /research/jobs/:jobId` - Get background job status
- `GET /research/sessions` - Get research history
- `GET /research/sessions/:id` - Get specific research session

## Testing
To test the fix:
1. Navigate to the Search/Research screen
2. Enter a query (e.g., "kenya")
3. Click "Deep Research"
4. The research should now stream progress updates and complete successfully

## Files Modified
- `lib/core/api/api_service.dart` - Fixed endpoint and request format
- `lib/core/ai/deep_research_service.dart` - Updated response parsing

## Related Documentation
- Backend research service: `backend/src/services/researchService.ts`
- Backend research routes: `backend/src/routes/research.ts`
- Deep Research Guide: `DEEP_RESEARCH_GUIDE.md`
