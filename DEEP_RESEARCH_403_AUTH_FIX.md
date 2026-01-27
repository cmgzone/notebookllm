# Deep Research 403 Authentication Fix

## Issue
Deep research endpoints were returning 403 Forbidden errors because the controller was checking for `userId` in the wrong location.

## Root Cause
The `deepResearchController.ts` was using `(req as any).user?.userId` to get the user ID, but the authentication middleware (`authenticateToken`) sets the user ID at `req.userId` directly.

**Incorrect code:**
```typescript
const userId = (req as any).user?.userId;
```

**Correct code:**
```typescript
const userId = req.userId;
```

## Changes Made

### backend/src/controllers/deepResearchController.ts

1. **Updated imports** (Line 1)
   - Changed: `import type { Request, Response } from 'express';`
   - To: `import type { Response } from 'express';`
   - Added: `import type { AuthRequest } from '../middleware/auth.js';`

2. **Fixed performDeepResearch function** (Line 28)
   - Changed parameter type from `Request` to `AuthRequest`
   - Changed: `const userId = (req as any).user?.userId;`
   - To: `const userId = req.userId;`

3. **Fixed getResearchHistory function** (Line 193)
   - Changed parameter type from `Request` to `AuthRequest`
   - Changed: `const userId = (req as any).user?.userId;`
   - To: `const userId = req.userId;`

4. **Fixed getResearchSession function** (Line 230)
   - Changed parameter type from `Request` to `AuthRequest`
   - Changed: `const userId = (req as any).user?.userId;`
   - To: `const userId = req.userId;`

## How Authentication Works

The authentication flow:
1. Client sends request with `Authorization: Bearer <token>` header
2. `authenticateToken` middleware validates the token
3. Middleware sets `req.userId` with the authenticated user's ID
4. Controller accesses `req.userId` to get the authenticated user

## Testing
After these changes:
1. Deep research endpoints should work without 403 errors
2. Authentication will properly identify the user
3. Research sessions will be correctly associated with users

## Related Files
- `backend/src/middleware/auth.ts` - Defines `AuthRequest` interface and sets `req.userId`
- `backend/src/routes/deepResearch.ts` - Routes that use `authenticateToken` middleware
- `backend/src/controllers/deepResearchController.ts` - Fixed controller

## Impact
- Fixes 403 Forbidden errors on all deep research endpoints
- Enables proper user authentication for research features
- Allows research sessions to be saved and retrieved correctly
