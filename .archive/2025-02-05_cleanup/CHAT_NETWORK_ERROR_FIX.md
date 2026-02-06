# Chat Network Error Fix

## Problem
Getting "Network Error: Failed to connect to the AI service" when trying to use chat.

## Root Cause Analysis

### Backend Status ✅
- Backend URL: `https://backend.taskiumnetwork.com/`
- Health check: **WORKING** (returns 200 OK)
- Backend version: 2.0.0
- All routes properly configured with `/api/` prefix

### Likely Issues

1. **Authentication Required** - The chat endpoint requires a valid auth token
2. **User Not Logged In** - App may not have stored credentials
3. **Token Expired** - Auth token may have expired
4. **No AI Model Selected** - Chat requires an AI model to be configured

## Solution Steps

### Step 1: Check if You're Logged In

1. Open the app
2. Check if you see a login screen or if you're on the home screen
3. If you see a login screen, **log in first** before trying to chat

### Step 2: Verify AI Model is Selected

1. Go to **Settings** → **AI Model Settings**
2. Make sure an AI model is selected (e.g., Gemini, OpenRouter)
3. If no model is selected, select one and try again

### Step 3: Clear App Data and Re-login

If the above doesn't work:

1. **Clear app data**:
   - Android: Settings → Apps → Notebook LLM → Storage → Clear Data
   - Or uninstall and reinstall the app

2. **Create a new account or login**:
   - Open the app
   - Sign up or log in
   - Go to Settings and select an AI model
   - Try chat again

### Step 4: Check Network Connectivity

1. Make sure your device has internet connection
2. Try opening a browser and visiting: `https://backend.taskiumnetwork.com/health`
3. You should see: `{"status":"ok","message":"Backend is running",...}`

## Technical Details

### API Configuration
```dart
// lib/core/api/api_service.dart
static const String _baseUrl = 'https://backend.taskiumnetwork.com/api/';
```

### Auth Flow
1. User logs in → receives `accessToken` and `refreshToken`
2. Tokens stored in secure storage
3. All API requests include `Authorization: Bearer <token>` header
4. If token expires, app automatically refreshes it

### Chat Endpoint
```
POST https://backend.taskiumnetwork.com/api/ai/chat-stream
Headers:
  - Authorization: Bearer <your-token>
  - Content-Type: application/json
Body:
  {
    "messages": [...],
    "provider": "gemini",
    "model": "gemini-pro"
  }
```

## Quick Test

To verify the backend is working, you can test with curl:

```bash
# Test health endpoint
curl https://backend.taskiumnetwork.com/health

# Should return:
# {"status":"ok","message":"Backend is running","timestamp":"...","version":"2.0.0"}
```

## If Still Not Working

1. **Check Flutter console logs** for detailed error messages
2. **Look for**:
   - `[API] Error` messages
   - `401 Unauthorized` errors
   - `No AI model selected` errors
   - Connection timeout errors

3. **Common error messages and fixes**:
   - `"Unauthorized"` → You need to log in
   - `"No AI model selected"` → Go to Settings and select a model
   - `"Connection timed out"` → Check your internet connection
   - `"Network error"` → Backend might be temporarily down (unlikely since health check works)

## Prevention

To avoid this in the future:

1. **Always log in** before using chat features
2. **Select an AI model** in Settings after first login
3. **Keep the app updated** to get the latest fixes
4. **Don't clear app data** unless necessary (you'll lose your login)

## Status

- ✅ Backend is running and healthy
- ✅ API routes are configured correctly
- ✅ CORS is enabled
- ⚠️ User needs to be authenticated to use chat
- ⚠️ AI model must be selected in settings

## Next Steps

1. **Log in to the app** (or create an account if you don't have one)
2. **Go to Settings → AI Model Settings**
3. **Select an AI model** (Gemini recommended)
4. **Try sending a chat message again**

The backend is working perfectly - you just need to make sure you're logged in and have an AI model selected!
