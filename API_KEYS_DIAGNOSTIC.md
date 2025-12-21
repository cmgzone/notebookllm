# API Keys Diagnostic Report

## Required API Keys in Supabase Secrets

Based on the analysis of your Supabase Edge Functions, here are ALL the API keys that need to be configured:

### 1. **Core Required Keys** (App won't work without these)
- `SUPABASE_SERVICE_ROLE_KEY` or `SERVICE_ROLE_KEY` - Used by all functions
- `OPENAI_API_KEY` - Required for:
  - `answer_query` (embeddings & LLM)
  - `ingest_source` (embeddings)
  - `moderation` (content moderation)

### 2. **LLM Provider Keys** (At least one required)
- `GEMINI_API_KEY` - Used by:
  - `answer_query` (primary LLM)
  - `ingest_source` (content processing)
  - `improve_notes` (note enhancement)
  - `generate_image` (image generation)

### 3. **Audio/Voice Keys** (For TTS/STT features)
- `ELEVENLABS_API_KEY` - Required for:
  - `tts` (text-to-speech)
  - `stt` (speech-to-text)
  - `voices` (voice listing)
  - `ingest_source` (audio processing)

### 4. **Search & Web Features** (Optional but important)
- `SERPER_API_KEY` - Required for `web_search` function
- `BROWSERLESS_TOKEN` - Optional for YouTube verification in `web_search`

### 5. **Storage Configuration**
- `SUPABASE_TTS_BUCKET` - Defaults to 'tts' if not set

## How to Add Secrets in Supabase

### Via Supabase Dashboard:
1. Go to your project: https://ndwovuxiuzbdhdqwpaau.supabase.co
2. Navigate to **Settings** → **Edge Functions** → **Secrets**
3. Add each secret with the exact name shown above

### Via Supabase CLI:
```bash
# Set secrets one by one
supabase secrets set OPENAI_API_KEY=your_key_here
supabase secrets set GEMINI_API_KEY=your_key_here
supabase secrets set ELEVENLABS_API_KEY=your_key_here
supabase secrets set SERPER_API_KEY=your_key_here
supabase secrets set BROWSERLESS_TOKEN=your_token_here

# List all secrets to verify
supabase secrets list
```

## Common Issues & Solutions

### Issue 1: "Missing Supabase config" banner
**Cause:** `.env` file not loaded or missing keys
**Solution:** Ensure `.env` has valid `SUPABASE_URL` and `SUPABASE_ANON_KEY`

### Issue 2: Functions fail with "OPENAI_API_KEY not set"
**Cause:** Secret not configured in Supabase
**Solution:** Add the secret via dashboard or CLI

### Issue 3: Functions timeout or fail silently
**Cause:** Missing required API keys for the specific function
**Solution:** Check function logs in Supabase dashboard

### Issue 4: Edge Functions return 500 errors
**Cause:** Multiple possible reasons:
- Missing API keys
- Invalid API keys
- API rate limits exceeded
- Network issues

**Debug Steps:**
1. Check Supabase Edge Function logs
2. Verify all secrets are set: `supabase secrets list`
3. Test individual functions via Supabase dashboard
4. Check API key validity with providers

## Verification Checklist

- [ ] `.env` file exists with SUPABASE_URL and SUPABASE_ANON_KEY
- [ ] SUPABASE_SERVICE_ROLE_KEY set in Supabase secrets
- [ ] OPENAI_API_KEY set in Supabase secrets
- [ ] GEMINI_API_KEY set in Supabase secrets
- [ ] ELEVENLABS_API_KEY set (if using audio features)
- [ ] SERPER_API_KEY set (if using web search)
- [ ] All Edge Functions deployed: `supabase functions list`
- [ ] Database migrations applied
- [ ] Storage buckets created (media, tts)

## Testing Individual Functions

Test each function to identify which ones are failing:

```bash
# Test answer_query
curl -X POST https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1/answer_query \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "test question"}'

# Test web_search
curl -X POST https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1/web_search \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"q": "test search"}'
```

## Next Steps

1. **Verify secrets are set:** Run `supabase secrets list`
2. **Check function logs:** Go to Supabase Dashboard → Edge Functions → Logs
3. **Test the app:** Run `flutter run` and check for specific error messages
4. **Enable debug mode:** Add error logging in the Flutter app to see API responses
