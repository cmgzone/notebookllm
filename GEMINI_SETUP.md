# Gemini Setup Guide

## Using Gemini Instead of OpenAI

If you're using Gemini (Google's AI) instead of OpenAI, follow this guide.

## Step 1: Get Gemini API Key

1. Go to https://makersuite.google.com/app/apikey
2. Click "Create API Key"
3. Copy your API key (starts with `AIza...`)

## Step 2: Set Gemini API Key in Supabase

```powershell
# Set Gemini API key
supabase secrets set GEMINI_API_KEY=AIzaSy...your_key_here

# Verify it's set
supabase secrets list
```

## Step 3: Deploy Updated Functions

The `ingest_source` function has been updated to support Gemini embeddings.

```powershell
# Deploy the updated function
supabase functions deploy ingest_source

# Verify deployment
supabase functions list
```

## Step 4: Set Other Required Secrets

```powershell
# Service role key (required)
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...your_service_role_key

# For web search (required for search feature)
supabase secrets set SERPER_API_KEY=your_serper_key

# For audio features (optional)
supabase secrets set ELEVENLABS_API_KEY=your_elevenlabs_key

# For YouTube (optional, enhances YouTube features)
supabase secrets set YOUTUBE_API_KEY=AIza...your_youtube_key

# For Google Drive (optional, for private files)
supabase secrets set GOOGLE_DRIVE_API_KEY=AIza...your_drive_key
```

## Step 5: Test Gemini Embeddings

```powershell
# Create a test source in your app
# Then test ingestion with curl:

curl -X POST https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1/ingest_source `
  -H "Authorization: Bearer YOUR_USER_TOKEN" `
  -H "Content-Type: application/json" `
  -d '{\"source_id\": \"YOUR_SOURCE_ID\"}'
```

## Gemini vs OpenAI

### Gemini Advantages
- ✅ Free tier available
- ✅ Good for multimodal (text + images)
- ✅ Integrated with Google services
- ✅ No credit card required for API key

### Gemini Limitations
- ⚠️ Embedding dimension: 768 (vs OpenAI's 1536)
- ⚠️ Processes one text at a time (slower for batch)
- ⚠️ Different API structure

### OpenAI Advantages
- ✅ Faster batch processing
- ✅ Larger embedding dimension
- ✅ More mature API

## Gemini API Models

### For Embeddings
- **Model**: `embedding-001`
- **Dimension**: 768
- **Max tokens**: 2048
- **Cost**: Free tier available

### For Text Generation (used in answer_query)
- **Model**: `gemini-pro`
- **Max tokens**: 30,720
- **Cost**: Free tier available

### For Vision (used in image OCR)
- **Model**: `gemini-pro-vision`
- **Supports**: Images + text
- **Cost**: Free tier available

## Update answer_query Function

If you want to use Gemini for chat as well, update the `answer_query` function:

```typescript
// In supabase/functions/answer_query/index.ts
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');

async function generateWithGemini(prompt: string): Promise<string> {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [{ text: prompt }]
        }]
      }),
    }
  );
  
  if (!res.ok) {
    throw new Error(`Gemini generation failed: ${await res.text()}`);
  }
  
  const json = await res.json();
  return json.candidates[0]?.content?.parts[0]?.text || '';
}
```

## Troubleshooting

### Issue: "GEMINI_API_KEY not set"

**Solution:**
```powershell
supabase secrets set GEMINI_API_KEY=AIza...
```

### Issue: "Embedding dimension mismatch"

Gemini embeddings are 768-dimensional, while OpenAI's are 1536-dimensional.

**Solution:** Update your database schema if needed:
```sql
-- Check current dimension
SELECT dim FROM embeddings LIMIT 1;

-- If you need to change, you may need to recreate the table
-- or add a new column for Gemini embeddings
```

### Issue: "Quota exceeded"

**Solution:**
1. Check your Gemini API quota: https://console.cloud.google.com/
2. Enable billing if needed
3. Or use OpenAI as fallback

### Issue: "Slow embedding generation"

Gemini processes one text at a time, which is slower than OpenAI's batch processing.

**Solution:**
- Reduce chunk size
- Or use OpenAI for embeddings (faster)
- Or implement parallel processing

## Cost Comparison

### Gemini (Free Tier)
- Embeddings: Free up to 1,500 requests/day
- Text generation: Free up to 60 requests/minute
- Vision: Free up to 60 requests/minute

### OpenAI (Paid)
- Embeddings: $0.0001 per 1K tokens
- GPT-3.5: $0.0015 per 1K tokens
- GPT-4: $0.03 per 1K tokens

## Complete Setup Commands

```powershell
# 1. Link project
supabase link --project-ref ndwovuxiuzbdhdqwpaau

# 2. Set Gemini key
supabase secrets set GEMINI_API_KEY=AIzaSy...

# 3. Set other required keys
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...
supabase secrets set SERPER_API_KEY=...

# 4. Deploy functions
supabase functions deploy ingest_source
supabase functions deploy answer_query
supabase functions deploy web_search

# 5. Verify
supabase secrets list
supabase functions list

# 6. Test
# Use your app to add a source and see if it works
```

## Verify Setup

Run the diagnostic script:
```powershell
.\scripts\diagnose.ps1
```

Expected output:
```
✅ Supabase CLI installed
✅ Project is linked
✅ Functions are deployed
✅ GEMINI_API_KEY is set
✅ All required secrets are set
```

## Migration from OpenAI to Gemini

If you were using OpenAI and want to switch to Gemini:

1. **Keep existing embeddings**: They'll still work
2. **New embeddings use Gemini**: Set GEMINI_API_KEY
3. **Optional**: Remove OPENAI_API_KEY if not needed
4. **Note**: Mixing embedding models may affect search quality

## Best Practice

Use both for redundancy:
```powershell
# Set both keys
supabase secrets set GEMINI_API_KEY=AIza...
supabase secrets set OPENAI_API_KEY=sk-...

# The function will use Gemini first, fallback to OpenAI
```

## Support

- **Gemini API Docs**: https://ai.google.dev/docs
- **API Key Management**: https://makersuite.google.com/app/apikey
- **Quota Management**: https://console.cloud.google.com/

---

**Ready to use Gemini!** 🚀

Just set the GEMINI_API_KEY and deploy the updated function.
