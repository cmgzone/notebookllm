# Quick Start Guide - YouTube & Google Drive Integration

## 🚀 5-Minute Setup

### Step 1: Set Secrets (2 min)
```bash
supabase secrets set OPENAI_API_KEY=sk-proj-...
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

### Step 2: Deploy Functions (2 min)
```powershell
.\scripts\deploy_youtube_gdrive.ps1
```

### Step 3: Apply Security Fixes (1 min)
```bash
supabase db push
supabase auth update --enable-leaked-password-protection
```

### Step 4: Test (30 sec)
```bash
# Test YouTube
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/extract_youtube \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
```

### Step 5: Use in App (30 sec)
1. Open app
2. Tap "+"
3. Select "YouTube" or "Google Drive"
4. Paste URL
5. Done! ✅

---

## 📖 Full Documentation

- **User Guide**: `YOUTUBE_GDRIVE_INTEGRATION.md`
- **Deployment**: `DEPLOYMENT_CHECKLIST.md`
- **Testing**: `BACKEND_TESTING_GUIDE.md`
- **Security**: `SECURITY_FIXES.md`
- **Complete Summary**: `FINAL_IMPLEMENTATION_SUMMARY.md`

---

## 🆘 Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| "unauthorized" | Check auth token |
| "OPENAI_API_KEY not set" | Run: `supabase secrets set OPENAI_API_KEY=...` |
| "No transcript" | Video needs captions |
| "File not public" | Share file publicly |
| Function timeout | Content too large |

---

## 📞 Support

- **Logs**: `supabase functions logs FUNCTION_NAME --follow`
- **Dashboard**: https://app.supabase.com
- **Docs**: See documentation files above

---

**Ready to go!** 🎉
