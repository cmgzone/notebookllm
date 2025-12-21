# Troubleshooting Guide - Nothing is Working

## Current Issue

**Error**: `ClientException: Failed to fetch, uri=https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1/web_search`

This means the Edge Functions are either:
1. Not deployed
2. Not accessible
3. Missing required secrets
4. Have CORS issues

## Step-by-Step Fix

### Step 1: Verify Supabase CLI is Installed

```powershell
# Check if Supabase CLI is installed
supabase --version

# If not installed, install it
npm install -g supabase
```

### Step 2: Link Your Project

```powershell
# Link to your Supabase project
supabase link --project-ref ndwovuxiuzbdhdqwpaau

# You'll be prompted for your database password
# Get it from: https://app.supabase.com/project/ndwovuxiuzbdhdqwpaau/settings/database
```

### Step 3: Check Current Functions

```powershell
# List all deployed functions
supabase functions list
```

**Expected output:**
```
answer_query
extract_youtube
extract_google_drive
generate_image
improve_notes
ingest_source
moderation
stt
tts
visualize
voices
web_search
```

If functions are missing, they need to be deployed.

### Step 4: Set ALL Required Secrets

```powershell
# Core secrets (REQUIRED)
supabase secrets set SUPABASE_URL=https://ndwovuxiuzbdhdqwpaau.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
supabase secrets set OPENAI_API_KEY=sk-proj-your_key_here

# For web search (REQUIRED for search to work)
supabase secrets set SERPER_API_KEY=your_serper_key_here

# Optional but recommended
supabase secrets set GEMINI_API_KEY=your_gemini_key_here
supabase secrets set ELEVENLABS_API_KEY=your_elevenlabs_key_here
supabase secrets set YOUTUBE_API_KEY=your_youtube_key_here
supabase secrets set GOOGLE_DRIVE_API_KEY=your_drive_key_here

# Verify secrets are set
supabase secrets list
```

### Step 5: Deploy ALL Functions

```powershell
# Deploy all functions at once
supabase functions deploy

# Or deploy individually
supabase functions deploy web_search
supabase functions deploy answer_query
supabase functions deploy ingest_source
supabase functions deploy extract_youtube
supabase functions deploy extract_google_drive
```

### Step 6: Test Functions Directly

```powershell
# Test web_search function
curl -X POST https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1/web_search `
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5kd292dXhpdXpiZGhkcXdwYWF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyODY5NjUsImV4cCI6MjA3ODg2Mjk2NX0.d992B3cr0DlonC4AMGJD1mUCukWv_jg-55AJlI16NGo" `
  -H "Content-Type: application/json" `
  -d '{\"q\": \"test search\"}'
```

### Step 7: Check Function Logs

```powershell
# View logs for web_search
supabase functions logs web_search --follow

# View logs for other functions
supabase functions logs answer_query --follow
supabase functions logs ingest_source --follow
```

## Common Issues & Solutions

### Issue 1: "supabase: command not found"

**Solution:**
```powershell
npm install -g supabase
```

### Issue 2: "Project not linked"

**Solution:**
```powershell
supabase link --project-ref ndwovuxiuzbdhdqwpaau
# Enter your database password when prompted
```

### Issue 3: "SERPER_API_KEY not set"

The web_search function requires a Serper API key.

**Solution:**
1. Go to https://serper.dev/
2. Sign up for free account
3. Get your API key
4. Set it:
```powershell
supabase secrets set SERPER_API_KEY=your_key_here
```

### Issue 4: "Functions not deployed"

**Solution:**
```powershell
# Deploy all functions
supabase functions deploy
```

### Issue 5: "CORS error"

**Solution:**
Check that functions have CORS headers. All functions should have:
```typescript
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
```

### Issue 6: "Service role key not set"

**Solution:**
1. Go to https://app.supabase.com/project/ndwovuxiuzbdhdqwpaau/settings/api
2. Copy the "service_role" key (not anon key)
3. Set it:
```powershell
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

## Quick Diagnostic Script

Run this to check everything:

```powershell
# Check CLI
Write-Host "Checking Supabase CLI..." -ForegroundColor Cyan
supabase --version

# Check project link
Write-Host "`nChecking project link..." -ForegroundColor Cyan
supabase status

# List functions
Write-Host "`nListing deployed functions..." -ForegroundColor Cyan
supabase functions list

# List secrets
Write-Host "`nListing secrets..." -ForegroundColor Cyan
supabase secrets list

Write-Host "`nDiagnostic complete!" -ForegroundColor Green
```

## Required API Keys

### 1. OpenAI API Key (REQUIRED)
- Get from: https://platform.openai.com/api-keys
- Used for: Embeddings, chat completions
- Cost: ~$0.0001 per 1K tokens

### 2. Serper API Key (REQUIRED for web search)
- Get from: https://serper.dev/
- Used for: Web search functionality
- Free tier: 2,500 searches/month

### 3. Gemini API Key (OPTIONAL)
- Get from: https://makersuite.google.com/app/apikey
- Used for: Image OCR, alternative LLM
- Free tier: Available

### 4. ElevenLabs API Key (OPTIONAL)
- Get from: https://elevenlabs.io/
- Used for: Text-to-speech, speech-to-text
- Free tier: 10,000 characters/month

### 5. YouTube API Key (OPTIONAL)
- Get from: https://console.cloud.google.com/
- Used for: Enhanced YouTube metadata
- Free tier: 10,000 units/day

### 6. Google Drive API Key (OPTIONAL)
- Get from: https://console.cloud.google.com/
- Used for: Private Google Drive files
- Free tier: Available

## Step-by-Step Recovery

### If Nothing Works, Start Fresh:

```powershell
# 1. Unlink project
supabase unlink

# 2. Link again
supabase link --project-ref ndwovuxiuzbdhdqwpaau

# 3. Set ALL secrets
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...
supabase secrets set SERPER_API_KEY=...

# 4. Deploy all functions
supabase functions deploy

# 5. Verify
supabase functions list
supabase secrets list

# 6. Test
curl -X POST https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1/web_search `
  -H "Authorization: Bearer YOUR_ANON_KEY" `
  -H "Content-Type: application/json" `
  -d '{\"q\": \"test\"}'
```

## Verify Your .env File

Make sure your Flutter app's `.env` file has:

```env
SUPABASE_URL=https://ndwovuxiuzbdhdqwpaau.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5kd292dXhpdXpiZGhkcXdwYWF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyODY5NjUsImV4cCI6MjA3ODg2Mjk2NX0.d992B3cr0DlonC4AMGJD1mUCukWv_jg-55AJlI16NGo
SUPABASE_FUNCTIONS_URL=https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1
SUPABASE_MEDIA_BUCKET=media
```

## Test Each Function

### Test 1: Web Search
```powershell
curl -X POST https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1/web_search `
  -H "Authorization: Bearer YOUR_ANON_KEY" `
  -H "Content-Type: application/json" `
  -d '{\"q\": \"test search\"}'
```

### Test 2: Answer Query
```powershell
curl -X POST https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1/answer_query `
  -H "Authorization: Bearer YOUR_ANON_KEY" `
  -H "Content-Type: application/json" `
  -d '{\"query\": \"test question\"}'
```

### Test 3: Extract YouTube
```powershell
curl -X POST https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1/extract_youtube `
  -H "Authorization: Bearer YOUR_ANON_KEY" `
  -H "Content-Type: application/json" `
  -d '{\"url\": \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\"}'
```

## Check Supabase Dashboard

1. Go to: https://app.supabase.com/project/ndwovuxiuzbdhdqwpaau
2. Navigate to **Edge Functions**
3. Check if functions are listed
4. Click on each function to see logs
5. Look for errors in the logs

## Still Not Working?

### Check These:

1. **Database Password**: Make sure you have the correct database password
2. **Service Role Key**: Verify it's the service_role key, not anon key
3. **API Keys**: Verify all API keys are valid and not expired
4. **Network**: Check if you can access Supabase from your network
5. **Firewall**: Ensure no firewall is blocking Supabase

### Get More Help:

```powershell
# View detailed logs
supabase functions logs web_search --follow

# Check database status
supabase db status

# Check project status
supabase status
```

## Contact Information

If still having issues:
1. Check Supabase Dashboard logs
2. Review function deployment status
3. Verify all API keys are set correctly
4. Test functions with curl commands
5. Check network connectivity

---

**Most Common Fix**: Deploy the functions!
```powershell
supabase functions deploy
```
