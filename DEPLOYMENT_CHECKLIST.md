# Deployment Checklist

## Pre-Deployment

### Backend Setup
- [ ] Backend server is running (`npm run dev` in backend directory)
- [ ] Database migrations are complete
- [ ] Environment variables are set in `backend/.env`
- [ ] API endpoints are responding (test with curl or Postman)
- [ ] CORS is configured for Flutter app URL
- [ ] JWT secret is set and secure

### Flutter App Setup
- [ ] Flutter SDK is installed and up to date
- [ ] All dependencies are installed (`flutter pub get`)
- [ ] `.env` file has correct backend URL
- [ ] API service is configured with correct base URL
- [ ] Auth service is properly initialized

### Code Quality
- [ ] No compilation errors (`flutter analyze`)
- [ ] No lint warnings
- [ ] All imports are correct
- [ ] No unused variables or imports

## Testing

### Authentication Flow
- [ ] User can sign up with email/password
- [ ] User can log in with credentials
- [ ] Token is stored securely
- [ ] Token is sent with API requests
- [ ] Expired token triggers re-login
- [ ] Logout clears token

### API Integration
- [ ] Notebooks API returns data
- [ ] Sources API works correctly
- [ ] Chat API streams responses
- [ ] Error responses are handled gracefully
- [ ] Network timeouts are handled
- [ ] Empty responses don't crash app

### Error Handling
- [ ] 401 errors trigger login screen
- [ ] 403 errors show session expired message
- [ ] 429 errors show rate limit message
- [ ] Network errors show connection message
- [ ] Invalid JSON responses are handled
- [ ] Empty responses are handled

## Deployment Steps

### Step 1: Prepare Code
```powershell
# Clean build artifacts
flutter clean

# Get latest dependencies
flutter pub get

# Run analysis
flutter analyze

# Run tests (if available)
flutter test
```

### Step 2: Build Release
```powershell
# For Web
flutter build web --release

# For Windows
flutter build windows --release

# For Android
flutter build apk --release
```

### Step 3: Commit to Git
```powershell
git add .
git commit -m "fix: backend integration and deployment"
git push origin main
```

### Step 4: Deploy Backend
```powershell
# In backend directory
npm install
npm run build
npm start
```

### Step 5: Deploy Frontend
- Upload web build to hosting service
- Or distribute desktop/mobile builds

## Post-Deployment

### Verification
- [ ] App loads without errors
- [ ] Login works correctly
- [ ] Notebooks display properly
- [ ] API calls complete successfully
- [ ] No console errors
- [ ] Performance is acceptable

### Monitoring
- [ ] Check backend logs for errors
- [ ] Monitor API response times
- [ ] Track user authentication issues
- [ ] Monitor database performance
- [ ] Check for memory leaks

### Rollback Plan
If issues occur:
1. Stop the app
2. Revert to previous commit: `git revert HEAD`
3. Rebuild and redeploy
4. Investigate root cause

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| App won't start | Check Flutter installation, run `flutter doctor` |
| Backend not responding | Verify backend is running, check URL in API service |
| Login fails | Check auth endpoint, verify credentials, check token storage |
| API returns 401 | Token expired or invalid, clear cache and re-login |
| CORS error | Add Flutter app URL to backend CORS whitelist |
| Database errors | Run migrations, check connection string |
| Memory issues | Check for memory leaks, optimize large lists |

## Performance Targets

- App startup time: < 3 seconds
- API response time: < 1 second
- Login time: < 2 seconds
- Notebook load time: < 2 seconds
- Memory usage: < 200MB

## Security Checklist

- [ ] JWT secret is strong and unique
- [ ] Tokens are stored securely (not in SharedPreferences)
- [ ] HTTPS is enforced for all API calls
- [ ] Sensitive data is not logged
- [ ] API keys are not exposed in code
- [ ] CORS is properly configured
- [ ] Rate limiting is enabled
- [ ] Input validation is implemented

## Documentation

- [ ] README.md is updated
- [ ] API documentation is current
- [ ] Deployment guide is documented
- [ ] Troubleshooting guide is available
- [ ] Team is notified of changes

## Sign-Off

- [ ] QA testing complete
- [ ] Performance testing complete
- [ ] Security review complete
- [ ] Code review approved
- [ ] Ready for production deployment
