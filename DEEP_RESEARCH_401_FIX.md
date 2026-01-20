# Deep Research 401 Error Fix

## Problem
Deep Research feature is failing with "Exception: Failed to stream: 401" error.

## Root Cause
The 401 Unauthorized error indicates an authentication issue. Possible causes:
1. JWT token is expired
2. Token is not being sent correctly
3. Backend authentication middleware is rejecting the token
4. Backend server might not be running

## Investigation Steps

### 1. Added Logging to Auth Middleware
Added console.log statements to `backend/src/middleware/auth.ts` to track:
- Whether auth header is present
- Whether token is extracted
- JWT validation success/failure
- User ID from decoded token

### 2. Check Backend Server
Ensure the backend server is running on the correct port (default: 3000)

### 3. Check Token Validity
The Flutter app stores JWT tokens in secure storage. These tokens may expire.

## Solution

### Immediate Fix: Restart Backend with Logging
```bash
cd backend
npm run dev
```

Then test deep research again and check the console logs for authentication details.

### If Token is Expired
User needs to log out and log back in to get a fresh JWT token.

### If Backend Not Running
Start the backend server:
```bash
cd backend
npm install
npm run dev
```

## Files Modified
- `backend/src/middleware/auth.ts` - Added debug logging

## Testing
1. Start backend server
2. Open app and try deep research
3. Check backend console for auth logs
4. If token expired, log out and log back in
5. Try deep research again

## Next Steps
If issue persists after logging:
1. Check JWT_SECRET environment variable matches between login and validation
2. Check token expiration time in JWT generation
3. Consider implementing token refresh mechanism
