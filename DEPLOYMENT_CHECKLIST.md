# Deployment Checklist - YouTube & Google Drive Integration

## Pre-Deployment

### 1. Environment Setup
- [ ] Supabase CLI installed (`npm install -g supabase`)
- [ ] Project linked (`supabase link --project-ref YOUR_REF`)
- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] `.env` file configured with Supabase credentials

### 2. Code Review
- [ ] All TypeScript files compile without errors
- [ ] All Dart files have no diagnostics
- [ ] URL validators tested
- [ ] Error handling implemented
- [ ] CORS headers configured

### 3. API Keys Ready
- [ ] `OPENAI_API_KEY` obtained
- [ ] `SUPABASE_SERVICE_ROLE_KEY` obtained
- [ ] `GEMINI_API_KEY` obtained (optional)
- [ ] `YOUTUBE_API_KEY` obtained (optional)
- [ ] `GOOGLE_DRIVE_API_KEY` obtained (optional)
- [ ] `ELEVENLABS_API_KEY` obtained (optional)

## Backend Deployment

### 1. Set Supabase Secrets
```bash
# Required
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...

# Optional
supabase secrets set GEMINI_API_KEY=AIza...
supabase secrets set YOUTUBE_API_KEY=AIza...
supabase secrets set GOOGLE_DRIVE_API_KEY=AIza...
supabase secrets set ELEVENLABS_API_KEY=...
```

- [ ] All required secrets set
- [ ] Secrets verified (`supabase secrets list`)

### 2. Apply Security Fixes
```bash
# Apply database migration
supabase db push

# Enable password protection
supabase auth update --enable-leaked-password-protection

# Verify fixes
supabase db lint
```

- [ ] Migration applied successfully
- [ ] Password protection enabled
- [ ] No critical warnings in linter

### 3. Deploy Edge Functions
```powershell
# Windows
.\scripts\deploy_youtube_gdrive.ps1

# Or manually
supabase functions deploy extract_youtube
supabase functions deploy extract_google_drive
supabase functions deploy ingest_source
```

- [ ] `extract_youtube` deployed
- [ ] `extract_google_drive` deployed
- [ ] `ingest_source` deployed
- [ ] All functions listed (`supabase functions list`)

### 4. Test Edge Functions

#### Test YouTube
```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/extract_youtube \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
```

- [ ] Returns success response
- [ ] Contains transcript or metadata
- [ ] No errors in logs

#### Test Google Drive
```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/extract_google_drive \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://docs.google.com/document/d/YOUR_DOC_ID"}'
```

- [ ] Returns success response
- [ ] Contains document content
- [ ] No errors in logs

#### Test Ingest Source
- [ ] Create test source in app
- [ ] Call ingest_source with source_id
- [ ] Verify chunks created in database
- [ ] Verify embeddings created in database

## Frontend Deployment

### 1. Update Dependencies
```bash
flutter pub get
```

- [ ] All dependencies resolved
- [ ] No version conflicts
- [ ] `timeago` package added

### 2. Build & Test
```bash
# Run tests
flutter test

# Build for Android
flutter build apk

# Build for iOS (Mac only)
flutter build ios
```

- [ ] All tests pass
- [ ] No build errors
- [ ] App launches successfully

### 3. Test Features in App

#### YouTube Integration
- [ ] Open app
- [ ] Tap "+" button
- [ ] Select "YouTube"
- [ ] Paste valid YouTube URL
- [ ] Video added successfully
- [ ] Source appears in list
- [ ] Can chat about video content

#### Google Drive Integration
- [ ] Tap "+" button
- [ ] Select "Google Drive"
- [ ] Paste public Google Doc URL
- [ ] Document added successfully
- [ ] Source appears in list
- [ ] Can chat about document content

#### Error Handling
- [ ] Invalid YouTube URL shows error
- [ ] Private Google Drive file shows error
- [ ] Network errors handled gracefully
- [ ] Loading indicators work
- [ ] Success messages display

## Post-Deployment

### 1. Monitor Logs
```bash
# Watch function logs
supabase functions logs extract_youtube --follow
supabase functions logs extract_google_drive --follow
supabase functions logs ingest_source --follow
```

- [ ] No unexpected errors
- [ ] Performance acceptable
- [ ] API calls succeeding

### 2. Database Verification
```sql
-- Check sources
SELECT * FROM sources WHERE type IN ('youtube', 'drive') LIMIT 10;

-- Check chunks
SELECT COUNT(*) FROM chunks;

-- Check embeddings
SELECT COUNT(*) FROM embeddings;
```

- [ ] Sources created correctly
- [ ] Chunks generated
- [ ] Embeddings stored

### 3. Performance Testing
- [ ] YouTube extraction < 5 seconds
- [ ] Google Drive extraction < 3 seconds
- [ ] Embedding generation < 10 seconds
- [ ] App remains responsive
- [ ] No memory leaks

### 4. Security Verification
```bash
# Run database linter
supabase db lint

# Check for warnings
supabase db lint --level WARN
```

- [ ] No critical security warnings
- [ ] RLS policies active
- [ ] API keys secure
- [ ] CORS configured correctly

## Documentation

### 1. User Documentation
- [ ] Update README with new features
- [ ] Add YouTube integration guide
- [ ] Add Google Drive integration guide
- [ ] Document limitations

### 2. Developer Documentation
- [ ] API endpoints documented
- [ ] Error codes documented
- [ ] Environment variables listed
- [ ] Troubleshooting guide updated

### 3. Deployment Documentation
- [ ] Deployment steps documented
- [ ] Rollback procedure documented
- [ ] Monitoring setup documented
- [ ] Support contacts listed

## Rollback Plan

### If Issues Occur

#### Rollback Edge Functions
```bash
# Redeploy previous version
supabase functions deploy extract_youtube --version PREVIOUS
supabase functions deploy extract_google_drive --version PREVIOUS
supabase functions deploy ingest_source --version PREVIOUS
```

#### Rollback Database
```bash
# Revert migration
supabase db reset --version PREVIOUS_VERSION
```

#### Rollback App
```bash
# Revert to previous commit
git revert HEAD
flutter pub get
flutter build apk
```

- [ ] Rollback procedure tested
- [ ] Backup available
- [ ] Recovery time < 15 minutes

## Success Criteria

### Functional
- ✅ YouTube videos can be added
- ✅ Google Drive files can be added
- ✅ Content is extracted correctly
- ✅ AI can answer questions about content
- ✅ Error messages are clear

### Performance
- ✅ YouTube extraction < 5 seconds
- ✅ Google Drive extraction < 3 seconds
- ✅ App remains responsive
- ✅ No crashes or freezes

### Security
- ✅ No critical security warnings
- ✅ API keys secure
- ✅ User data protected
- ✅ RLS policies active

### User Experience
- ✅ Intuitive UI
- ✅ Clear feedback
- ✅ Helpful error messages
- ✅ Smooth animations

## Sign-Off

### Development Team
- [ ] Code reviewed
- [ ] Tests passed
- [ ] Documentation complete
- [ ] Ready for deployment

**Developer**: _________________ **Date**: _________

### QA Team
- [ ] Functional testing complete
- [ ] Performance testing complete
- [ ] Security testing complete
- [ ] Ready for production

**QA Lead**: _________________ **Date**: _________

### Product Owner
- [ ] Features approved
- [ ] Documentation approved
- [ ] Ready for release

**Product Owner**: _________________ **Date**: _________

---

## Quick Reference

### Important URLs
- Supabase Dashboard: `https://app.supabase.com/project/YOUR_PROJECT`
- Function Logs: `https://app.supabase.com/project/YOUR_PROJECT/functions`
- Database: `https://app.supabase.com/project/YOUR_PROJECT/editor`

### Important Commands
```bash
# Deploy all functions
supabase functions deploy

# View logs
supabase functions logs FUNCTION_NAME --follow

# Check secrets
supabase secrets list

# Run linter
supabase db lint

# Apply migrations
supabase db push
```

### Support Contacts
- Supabase Support: support@supabase.com
- OpenAI Support: support@openai.com
- Team Lead: [Your contact]

---

**Deployment Date**: _________________
**Deployed By**: _________________
**Status**: ☐ Success ☐ Issues ☐ Rolled Back
