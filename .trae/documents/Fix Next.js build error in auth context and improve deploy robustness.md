Here’s what’s breaking your deployment and how I propose to fix it.

**What’s failing now**
- Your Docker build runs `npm run build` for the Next.js app (`web_app`).
- TypeScript fails with:
  - `./lib/auth-context.tsx:29:25 Type error: Property 'clearToken' does not exist on type 'ApiService'. Did you mean 'clearTokens'?`
- In code:
  - `web_app/lib/api.ts` defines `class ApiService` with:
    - `setTokens(accessToken, refreshToken)`
    - `clearTokens()`
    - `getToken()`
  - `web_app/lib/auth-context.tsx` calls `api.clearToken()` inside the `useEffect` error handler.
- So the build error is accurate: the method is named `clearTokens`, but we call `clearToken`.

**Planned changes**

**1. Fix the auth context to use the correct API method**
- Update `web_app/lib/auth-context.tsx`:
  - In the `useEffect` block where we call `api.getCurrentUser()` on mount,
  - Change the `.catch` handler from `api.clearToken()` to `api.clearTokens()`.
- Rationale:
  - We already have `ApiService.clearTokens()` implemented to clear both access and refresh tokens plus localStorage.
  - Using the correct method name resolves the TS error and ensures a clean logout path when the initial token check fails.

**2. Rebuild locally to validate**
- From `web_app/`, run:
  - `npm run lint` (or `npm run typecheck` if available) to confirm TS types pass.
  - `npm run build` to ensure Next.js builds successfully outside Docker.
- If these pass, the same step inside the Docker build (`RUN npm run build`) will no longer fail.

**3. Re-deploy via your platform (Coolify)**
- Trigger a fresh deployment of `cmgzone/notebookllm:master`.
- Confirm the logs show:
  - `> next build` completes successfully.
  - No auth-context type errors.
- Once the container is up, verify in the browser that:
  - The app loads without build-time errors.
  - If there’s a stale/invalid token in localStorage, the app gracefully clears it and shows you as logged out.

**4. (Optional, but recommended) Harden auth error handling**
- After the main fix, consider a small follow-up hardening:
  - In `auth-context.tsx`, broaden the `.catch` handler to also log the error (for debugging) before calling `api.clearTokens()`.
  - This doesn’t affect types but makes future production debugging easier.

Once you approve this plan, I’ll:
- Apply the `clearToken` → `clearTokens` change in `auth-context.tsx`.
- Run the local TypeScript / build checks.
- Ensure the Dockerfile build step is clean, and then you can redeploy with confidence.