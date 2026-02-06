# Render Deployment Checklist

## Current Status
✅ Code pushed to GitHub (commit: `feat: Add admin notification system and fix messaging circular dependency`)
⏳ Waiting for Render to deploy the latest changes

## What Was Deployed
- Admin notification system
- Messaging circular dependency fix
- Notification routes and services
- Social features (already existed)
- All database migrations

## Deployment Steps

### 1. Check Render Dashboard
Go to: https://dashboard.render.com/
- Check if your backend service is deploying
- Look for the latest commit in the deployment log

### 2. If Auto-Deploy is Disabled
- Click on your backend service
- Click "Manual Deploy" → "Deploy latest commit"
- Wait for deployment to complete (usually 2-5 minutes)

### 3. Run Migrations on Render
After deployment completes, you need to run the migrations on the production database.

**Option A: Using Render Shell**
1. Go to your service in Render dashboard
2. Click "Shell" tab
3. Run these commands:
```bash
npm run migrate:social
npm run migrate:messaging
npm run migrate:notifications
```

**Option B: Using Migration Scripts**
If you have a migration script set up, run:
```bash
npx tsx src/scripts/run-social-features-migration.ts
npx tsx src/scripts/run-messaging-migration.ts
npx tsx src/scripts/run-notifications-migration.ts
```

### 4. Verify Deployment
Test the endpoints:
```bash
# Check health
curl https://notebookllm-ufj7.onrender.com/api/health

# Check social endpoint (requires auth)
curl https://notebookllm-ufj7.onrender.com/api/social/friends \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 5. Check Logs
In Render dashboard:
- Go to "Logs" tab
- Look for:
  - ✅ "Server is running on..."
  - ✅ "WebSocket available at..."
  - ❌ Any error messages

## Common Issues

### Issue: "Error loading social data"
**Cause**: Migrations not run on production database
**Fix**: Run migrations using Render Shell (see step 3)

### Issue: "Module not found" errors
**Cause**: Dependencies not installed
**Fix**: Render should auto-install, but you can manually trigger:
```bash
npm install
```

### Issue: Circular dependency error
**Cause**: Old code still deployed
**Fix**: Force redeploy from latest commit

### Issue: Database connection errors
**Cause**: Environment variables not set
**Fix**: Check Render environment variables match your `.env` file

## Environment Variables to Check
Make sure these are set in Render:
- `NEON_HOST`
- `NEON_DATABASE`
- `NEON_USERNAME`
- `NEON_PASSWORD`
- `NEON_PORT`
- All API keys (GEMINI, OPENROUTER, etc.)

## Post-Deployment Testing

### Test Social Features
1. Log in to the Flutter app
2. Navigate to Social Hub
3. Should see friends/groups interface (not error)

### Test Messaging
1. Try to send a message to a friend
2. Should work without circular dependency error

### Test Notifications
1. Check notification bell in app
2. Admin should be able to send notifications

## Rollback Plan
If deployment fails:
1. Go to Render dashboard
2. Click "Rollback" to previous deployment
3. Investigate issues locally
4. Fix and redeploy

## Notes
- Render free tier may take 30-60 seconds to wake up if inactive
- First request after deployment may be slow
- Check Render logs for any startup errors
- The backend uses the same Neon database for both local and production

## Support
If issues persist:
- Check Render logs for specific errors
- Verify all migrations ran successfully
- Test endpoints directly with curl/Postman
- Check database tables exist in Neon dashboard
