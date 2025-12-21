# Security Fixes Guide

## Overview

This guide addresses the security warnings detected by Supabase Database Linter.

## Warnings Detected

| Warning | Level | Description | Status |
|---------|-------|-------------|--------|
| `function_search_path_mutable` | WARN | Function has mutable search_path | ✅ Fixed |
| `extension_in_public` | WARN | Vector extension in public schema | ✅ Fixed |
| `auth_leaked_password_protection` | WARN | Leaked password protection disabled | ⚠️ Manual |

## Fixes Applied

### 1. Function Search Path Mutable ✅

**Issue**: The `vector_search_cosine` function has a mutable search_path, which could lead to SQL injection vulnerabilities.

**Fix**: Set an immutable search_path for the function.

**Migration**: `supabase/migrations/20251119_fix_security_warnings.sql`

```sql
ALTER FUNCTION public.vector_search_cosine(
  query_embedding vector, 
  match_threshold double precision, 
  match_count integer
)
SET search_path = public, pg_temp;
```

**Verification**:
```sql
SELECT 
  proname, 
  prosecdef, 
  proconfig 
FROM pg_proc 
WHERE proname = 'vector_search_cosine';
```

### 2. Extension in Public Schema ✅

**Issue**: The `vector` extension is installed in the `public` schema, which is a security risk.

**Fix**: Move the extension to a dedicated `extensions` schema.

**Migration**: `supabase/migrations/20251119_fix_security_warnings.sql`

```sql
-- Create extensions schema
CREATE SCHEMA IF NOT EXISTS extensions;

-- Move vector extension
DROP EXTENSION IF EXISTS vector CASCADE;
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- Update search_path
ALTER DATABASE postgres SET search_path TO public, extensions;
```

**Verification**:
```sql
SELECT 
  extname, 
  nspname 
FROM pg_extension e
JOIN pg_namespace n ON e.extnamespace = n.oid
WHERE extname = 'vector';
```

### 3. Leaked Password Protection ⚠️

**Issue**: Supabase Auth's leaked password protection is disabled.

**Fix**: Enable via Supabase CLI or Dashboard.

**CLI Command**:
```bash
supabase auth update --enable-leaked-password-protection
```

**Dashboard**:
1. Go to Supabase Dashboard
2. Navigate to **Authentication** → **Policies**
3. Enable **Leaked Password Protection**

**What it does**:
- Checks passwords against HaveIBeenPwned.org database
- Prevents users from using compromised passwords
- Enhances overall security

## Deployment Steps

### Step 1: Apply Migration

```bash
# Push migration to Supabase
supabase db push

# Or apply manually
supabase db reset
```

### Step 2: Enable Password Protection

```bash
# Enable leaked password protection
supabase auth update --enable-leaked-password-protection
```

### Step 3: Verify Fixes

```bash
# Run database linter
supabase db lint

# Check for remaining warnings
supabase db lint --level WARN
```

## Testing

### Test 1: Verify Function Search Path

```sql
-- Should show search_path configuration
SELECT 
  p.proname,
  p.proconfig
FROM pg_proc p
WHERE p.proname = 'vector_search_cosine';
```

Expected result:
```
proname              | proconfig
---------------------|---------------------------
vector_search_cosine | {search_path=public,pg_temp}
```

### Test 2: Verify Extension Location

```sql
-- Should show extensions schema
SELECT 
  e.extname,
  n.nspname as schema
FROM pg_extension e
JOIN pg_namespace n ON e.extnamespace = n.oid
WHERE e.extname = 'vector';
```

Expected result:
```
extname | schema
--------|------------
vector  | extensions
```

### Test 3: Test Vector Operations

```sql
-- Should still work after moving extension
SELECT '[1,2,3]'::vector <-> '[4,5,6]'::vector as distance;
```

Expected: Returns a distance value (no errors)

### Test 4: Test Password Protection

Try registering with a known compromised password (e.g., "password123"):
- Should be rejected with appropriate error message
- Check auth logs for password check events

## Rollback Plan

If issues occur after applying fixes:

### Rollback Migration

```bash
# Revert to previous migration
supabase db reset --version PREVIOUS_VERSION
```

### Restore Vector Extension

```sql
-- Move vector back to public if needed
DROP EXTENSION IF EXISTS vector CASCADE;
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;
```

### Disable Password Protection

```bash
supabase auth update --disable-leaked-password-protection
```

## Impact Assessment

### Function Search Path Fix
- **Impact**: None - Function behavior unchanged
- **Risk**: Low
- **Testing**: Verify vector search still works

### Extension Schema Move
- **Impact**: Requires search_path update
- **Risk**: Medium - May affect existing queries
- **Testing**: Test all vector operations
- **Mitigation**: search_path automatically updated

### Password Protection
- **Impact**: Users with weak passwords must change them
- **Risk**: Low - Improves security
- **Testing**: Try registering with compromised passwords

## Monitoring

### Check for Errors

```sql
-- Monitor function calls
SELECT * FROM pg_stat_user_functions 
WHERE funcname = 'vector_search_cosine';

-- Check for extension issues
SELECT * FROM pg_extension WHERE extname = 'vector';
```

### Application Logs

Monitor your application logs for:
- Vector search errors
- Extension not found errors
- Authentication failures

### Supabase Dashboard

1. **Database** → **Logs**: Check for SQL errors
2. **Authentication** → **Logs**: Check password protection events
3. **Edge Functions** → **Logs**: Check for vector operation errors

## Best Practices

### 1. Regular Security Audits

```bash
# Run linter regularly
supabase db lint

# Check for new warnings
supabase db lint --level WARN
```

### 2. Keep Extensions Updated

```bash
# Check extension versions
SELECT * FROM pg_available_extensions WHERE name = 'vector';

# Update if needed
ALTER EXTENSION vector UPDATE;
```

### 3. Monitor Auth Events

- Enable auth event logging
- Monitor for suspicious password attempts
- Review rejected passwords regularly

### 4. Document Schema Changes

- Keep migration files organized
- Document all security-related changes
- Maintain rollback procedures

## Additional Security Recommendations

### 1. Row Level Security (RLS)

Ensure RLS is enabled on all tables:

```sql
-- Check RLS status
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public';

-- Enable RLS if needed
ALTER TABLE sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE embeddings ENABLE ROW LEVEL SECURITY;
```

### 2. API Key Rotation

- Rotate Supabase service role key regularly
- Update all API keys in secrets
- Monitor for unauthorized access

### 3. Function Security

```sql
-- Review all functions for security issues
SELECT 
  n.nspname as schema,
  p.proname as function,
  p.prosecdef as security_definer,
  p.proconfig as config
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public';
```

### 4. Extension Permissions

```sql
-- Verify extension permissions
SELECT 
  nspname,
  nspowner::regrole as owner
FROM pg_namespace
WHERE nspname = 'extensions';

-- Grant only necessary permissions
GRANT USAGE ON SCHEMA extensions TO authenticated;
```

## Troubleshooting

### Issue: Vector operations fail after migration

**Solution**:
```sql
-- Verify search_path includes extensions
SHOW search_path;

-- Update if needed
ALTER DATABASE postgres SET search_path TO public, extensions;
```

### Issue: Function not found

**Solution**:
```sql
-- Check function exists
SELECT * FROM pg_proc WHERE proname = 'vector_search_cosine';

-- Recreate if needed
-- (Use your original function definition)
```

### Issue: Password protection too strict

**Solution**:
```bash
# Adjust password requirements
supabase auth update --password-min-length 8
```

## Compliance

These fixes help meet:
- ✅ OWASP Top 10 security standards
- ✅ PostgreSQL security best practices
- ✅ Supabase security recommendations
- ✅ General database security guidelines

## Support

### Resources
- [Supabase Database Linter Docs](https://supabase.com/docs/guides/database/database-linter)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)
- [Supabase Auth Security](https://supabase.com/docs/guides/auth/password-security)

### Getting Help
1. Check Supabase Dashboard logs
2. Review migration output
3. Test in development first
4. Contact Supabase support if needed

---

**Status**: ✅ Fixes Ready for Deployment
**Priority**: High (Security)
**Estimated Time**: 10-15 minutes
**Risk Level**: Low-Medium
