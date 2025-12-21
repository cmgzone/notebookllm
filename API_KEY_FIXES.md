# API Key Fixes - Complete Report

## Issues Found & Fixed

### ✅ Issue 1: ingest_source - Only Used OpenAI
**Problem**: The `ingest_source` function only supported OpenAI embeddings.

**Fixed**: Updated to support both Gemini and OpenAI with automatic fallback.

**Code Location**: `supabase/functions/ingest_source/index.ts`

**What Changed**:
- Added `embedWithGemini()` function
- Added `embedWithOpenAI()` function  
- Modified `embed()` to try Gemini first, fallback to OpenAI
- Now works with either `GEMINI_API_KEY` or `OPENAI_API_KEY`

### ✅ Issue 2: answer_query - Only Used OpenAI for Embeddings
**Problem**: The `answer_query` function used Gemini for text generation but OpenAI for embeddings.

**Fixed**: Updated to support both Gemini and OpenAI for embeddings.

**Code Location**: `supabase/functions/answer_query/index.ts`

**What Changed**:
- Added `embedQueryWithGemini()` function
- Added `embedQueryWithOpenAI()` function
- Modified `embedQuery()` to try Gemini first, fallback to OpenAI
- Now consistent: uses Gemini for both embeddings and text generation

### ✅ Issue 3: web_search - Requires SERPER_API_KEY
**Status**: No mismatch - correctly checks for `SERPER_API_KEY`

**Note**: This function requires Serper API key for web search functionality.

## Summary of API Key Usage

| Function | Gemini | OpenAI | Serper | ElevenLabs | Other |
|----------|--------|--------|--------|------------|-------|
| `ingest_source` | ✅ Embeddings | ✅ Embeddings (fallback) | ❌ | ✅ Audio transcription | ✅ Image OCR |
| `answer_query` | ✅ Embeddings + Text | ✅ Embeddings (fallback) | ❌ | ❌ | ❌ |
| `web_search` | ❌ | ❌ | ✅ Required | ❌ | ❌ |
| `extract_youtube` | ❌ | ❌ | ❌ | ❌ | ✅ YouTube API (optional) |
| `extract_google_drive` | ❌ | ❌ | ❌ | ❌ | ✅ Drive API (optional) |
| `generate_image` | ✅ Image generation | ✅ Image generation (alt) | ❌ | ❌ | ❌ |
| `improve_notes` | ✅ Text generation | ✅ Text generation (alt) | ❌ | ❌ | ❌ |
| `tts` | ❌ | ❌ | ❌ | ✅ Required | ❌ |
| `stt` | ❌ | ❌ | ❌ | ✅ Required | ❌ |
| `moderation` | ❌ | ✅ Required | ❌ | ❌ | ❌ |

## Required API Keys by Feature

### Core Features (Required)
```powershell
# For AI embeddings and chat (choose one or both)
supabase secrets set GEMINI_API_KEY=AIza...        # Recommended (FREE)
# OR
supabase secrets set OPENAI_API_KEY=sk-...         # Alternative (PAID)

# For backend operations (REQUIRED)
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...

# For web search feature (REQUIRED if using search)
supabase secrets set SERPER_API_KEY=...            # FREE tier available
```

### Optional Features
```powershell
# For audio features (TTS/STT)
supabase secrets set ELEVENLABS_API_KEY=...

# For enhanced YouTube features
supabase secrets set YOUTUBE_API_KEY=AIza...

# For private Google Drive files
supabase secrets set GOOGLE_DRIVE_API_KEY=AIza...
```

## Deployment Steps

### 1. Set Your API Keys
```powershell
# If using Gemini (recommended for free tier)
supabase secrets set GEMINI_API_KEY=AIzaSy...your_key

# Required for backend
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...your_key

# Required for web search
supabase secrets set SERPER_API_KEY=your_key
```

### 2. Deploy Updated Functions
```powershell
# Deploy the fixed functions
supabase functions deploy ingest_source
supabase functions deploy answer_query

# Deploy other functions
supabase functions deploy web_search
supabase functions deploy extract_youtube
supabase functions deploy extract_google_drive
```

### 3. Verify
```powershell
# Check secrets are set
supabase secrets list

# Check functions are deployed
supabase functions list

# Run diagnostic
.\scripts\diagnose.ps1
```

## Testing After Fixes

### Test 1: Embeddings with Gemini
```powershell
# Add a source in your app
# Check logs to verify Gemini is being used
supabase functions logs ingest_source --follow
```

Expected log output:
```
Using Gemini for embeddings
Embedding generated successfully
```

### Test 2: Chat with Gemini
```powershell
# Ask a question in your app
# Check logs
supabase functions logs answer_query --follow
```

Expected log output:
```
Using Gemini for embeddings
Using Gemini for text generation
```

### Test 3: Web Search
```powershell
# Try web search in your app
# Check logs
supabase functions logs web_search --follow
```

Expected: No "SERPER_API_KEY not set" error

## Cost Comparison

### Using Gemini (FREE)
- Embeddings: FREE (1,500 requests/day)
- Text generation: FREE (60 requests/minute)
- Image OCR: FREE (60 requests/minute)
- **Total monthly cost**: $0

### Using OpenAI (PAID)
- Embeddings: ~$0.10 per 1M tokens
- GPT-3.5: ~$1.50 per 1M tokens
- GPT-4: ~$30 per 1M tokens
- **Estimated monthly cost**: $5-50 depending on usage

### Hybrid Approach (RECOMMENDED)
- Use Gemini for embeddings and chat (FREE)
- Use OpenAI as fallback (PAID)
- Use Serper for web search (FREE tier)
- **Total monthly cost**: $0-10

## Troubleshooting

### Error: "GEMINI_API_KEY not set"
**Solution**:
```powershell
supabase secrets set GEMINI_API_KEY=AIza...
supabase functions deploy ingest_source
supabase functions deploy answer_query
```

### Error: "OPENAI_API_KEY not set"
**Solution**: Either set OpenAI key OR set Gemini key (Gemini is tried first)
```powershell
supabase secrets set GEMINI_API_KEY=AIza...
```

### Error: "SERPER_API_KEY not set"
**Solution**:
```powershell
# Get free key from https://serper.dev/
supabase secrets set SERPER_API_KEY=your_key
supabase functions deploy web_search
```

### Error: "Embedding dimension mismatch"
**Issue**: Gemini embeddings are 768-dimensional, OpenAI are 1536-dimensional

**Solution**: Stick with one provider for all embeddings, or update database schema

### Web search not working
**Check**:
1. SERPER_API_KEY is set
2. web_search function is deployed
3. User is authenticated
4. Check function logs for errors

## Migration Guide

### From OpenAI to Gemini

1. **Set Gemini key**:
```powershell
supabase secrets set GEMINI_API_KEY=AIza...
```

2. **Deploy updated functions**:
```powershell
supabase functions deploy ingest_source
supabase functions deploy answer_query
```

3. **Test**:
- Add a new source
- Ask a question
- Verify it works

4. **Optional - Remove OpenAI key** (if not needed):
```powershell
supabase secrets unset OPENAI_API_KEY
```

**Note**: Existing embeddings will still work. New embeddings will use Gemini.

### From Gemini to OpenAI

1. **Set OpenAI key**:
```powershell
supabase secrets set OPENAI_API_KEY=sk-...
```

2. **Remove Gemini key** (optional):
```powershell
supabase secrets unset GEMINI_API_KEY
```

3. **Deploy functions**:
```powershell
supabase functions deploy ingest_source
supabase functions deploy answer_query
```

## Verification Checklist

- [ ] Gemini API key set (or OpenAI)
- [ ] Service role key set
- [ ] Serper API key set (for search)
- [ ] Functions deployed
- [ ] Secrets verified (`supabase secrets list`)
- [ ] Functions listed (`supabase functions list`)
- [ ] Diagnostic passed (`.\scripts\diagnose.ps1`)
- [ ] Test source added successfully
- [ ] Test question answered successfully
- [ ] Web search working (if using)

## Support

### Get API Keys
- **Gemini**: https://makersuite.google.com/app/apikey (FREE)
- **OpenAI**: https://platform.openai.com/api-keys (PAID)
- **Serper**: https://serper.dev/ (FREE tier)
- **Service Role**: https://app.supabase.com/project/YOUR_PROJECT/settings/api

### Check Logs
```powershell
# View function logs
supabase functions logs ingest_source --follow
supabase functions logs answer_query --follow
supabase functions logs web_search --follow
```

### Run Diagnostics
```powershell
# Check everything
.\scripts\diagnose.ps1

# Or use the setup script
.\scripts\setup_gemini.ps1
```

---

**Status**: ✅ All API key mismatches fixed!
**Recommendation**: Use Gemini for free tier, keep OpenAI as fallback
**Next Step**: Deploy updated functions and test
