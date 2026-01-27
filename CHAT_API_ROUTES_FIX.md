# Chat API Routes Fix

## Issue
The Flutter frontend was calling incorrect API endpoints that didn't exist in the backend, causing 404 errors:
- `POST /api/ai/chat-stream` → Should be `POST /api/ai/chat/stream`
- `POST /api/chat/global/messages` → Should be `POST /api/ai/chat/message`
- `GET /api/chat/{notebookId}/history` → Should be `GET /api/ai/chat/history?notebookId={notebookId}`

## Root Cause
Mismatch between frontend API service endpoints and backend route definitions.

## Changes Made

### lib/core/api/api_service.dart

1. **Fixed chat streaming endpoint** (Line ~759)
   - Changed: `/ai/chat-stream`
   - To: `/ai/chat/stream`

2. **Fixed save chat message endpoint** (Line ~711)
   - Changed: `/chat/$notebookId/messages`
   - To: `/ai/chat/message`
   - Updated payload to include `notebookId` in request body

3. **Fixed get chat history endpoint** (Line ~701)
   - Changed: `/chat/$notebookId/history`
   - To: `/ai/chat/history?notebookId=$notebookId`
   - Changed from path parameter to query parameter

## Backend Routes (Confirmed)
All routes are defined in `backend/src/routes/ai.ts`:
- ✅ `POST /api/ai/chat/stream` - Stream chat responses
- ✅ `POST /api/ai/chat/message` - Save chat message
- ✅ `GET /api/ai/chat/history` - Get chat history (with notebookId query param)

## Testing
After these changes:
1. Chat streaming should work without 404 errors
2. Chat messages should be saved to backend
3. Chat history should load correctly on app start

## Impact
- Fixes chat functionality across the app
- Resolves 404 errors in logs
- Enables proper chat persistence
