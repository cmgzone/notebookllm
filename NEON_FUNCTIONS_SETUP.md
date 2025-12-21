# Neon PostgreSQL Functions Setup Guide

This guide explains how to set up and use PostgreSQL functions in Neon as a replacement for Firebase Functions.

## Architecture Overview

**Firebase**: Authentication only (Firebase Auth)
**Neon PostgreSQL**: All business logic, data storage, and media storage

## Setup Instructions

### 1. Run the SQL Functions

Connect to your Neon database and run the `neon_functions.sql` file:

```bash
# Option 1: Using psql
psql "postgresql://neondb_owner:npg_86DhEiUzwJAW@ep-steep-butterfly-ad9nrtp4-pooler.c-2.us-east-1.aws.neon.tech/neondb?sslmode=require" -f neon_functions.sql

# Option 2: Using Neon Console
# Copy and paste the contents of neon_functions.sql into the SQL Editor
```

### 2. Verify Functions Are Created

```sql
-- List all custom functions
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE 'get_%' OR routine_name LIKE 'bulk_%' OR routine_name LIKE 'search_%';
```

### 3. Use in Your Flutter App

```dart
// Get the service
final neonFunctions = ref.read(neonFunctionsServiceProvider);

// Get user statistics
final stats = await neonFunctions.getUserStats();
print('Total notebooks: ${stats['total_notebooks']}');

// Search sources
final results = await neonFunctions.searchSources('machine learning');

// Bulk operations
await neonFunctions.bulkAddTags(
  ['source-id-1', 'source-id-2'],
  ['tag-id-1']
);
```

## Available Functions

### Analytics
- `getUserStats()` - Get comprehensive user statistics
- `getNotebookAnalytics(notebookId)` - Get notebook-specific analytics

### Search
- `searchSources(query)` - Full-text search across sources
- `searchSourcesFiltered(query, type, tags)` - Advanced filtered search
- `getRelatedSources(sourceId)` - Find similar sources

### Tag Management
- `getOrCreateTag(name, color)` - Get or create a tag
- `addTagToSource(sourceId, tagId)` - Add tag to source
- `removeTagFromSource(sourceId, tagId)` - Remove tag from source
- `getPopularTags()` - Get most used tags

### Bulk Operations
- `bulkDeleteSources(sourceIds)` - Delete multiple sources
- `bulkAddTags(sourceIds, tagIds)` - Add tags to multiple sources
- `bulkMoveSources(sourceIds, notebookId)` - Move sources to notebook

### Media Management
- `getUserMediaSize()` - Get total media storage used
- `cleanupOrphanedMedia()` - Remove orphaned media files

### Sharing
- `createShareToken(notebookId)` - Create shareable link
- `validateShareToken(token)` - Validate share token

## Performance Features

### Automatic Triggers
- **Auto-update timestamps**: Notebooks automatically update when sources change
- **Auto-cleanup**: Unused tags are automatically removed after 30 days

### Optimized Indexes
- Full-text search indexes for fast searching
- Composite indexes for common queries
- Media-specific indexes for storage queries

## Media Storage in Neon

Media files are stored as BYTEA in the `sources` table:

```dart
// Store media
await mediaService.uploadBytes(
  imageBytes,
  filename: 'photo.jpg',
  type: 'image',
  sourceId: sourceId,
);

// Retrieve media
final bytes = await mediaService.getMediaBytes(sourceId);
```

### Storage Limits
- Neon Free Tier: 512 MB total storage
- Neon Pro: 10 GB+ (scalable)
- Consider using external storage (S3, Cloudflare R2) for large media

## Migration from Firebase Functions

### Before (Firebase Functions)
```dart
final response = await functions.httpsCallable('searchSources').call({
  'query': 'machine learning',
});
```

### After (Neon Functions)
```dart
final results = await neonFunctions.searchSources('machine learning');
```

## Benefits

✅ **No Cold Starts**: Database functions are always warm
✅ **Lower Latency**: Direct database access, no HTTP overhead
✅ **Cost Effective**: No function invocation costs
✅ **Transactional**: All operations are ACID compliant
✅ **Type Safe**: PostgreSQL enforces data types
✅ **Scalable**: Neon auto-scales with your needs

## Monitoring

### Check Function Performance
```sql
-- View slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
WHERE query LIKE '%get_user_stats%'
ORDER BY mean_exec_time DESC;
```

### Monitor Storage Usage
```sql
-- Check database size
SELECT pg_size_pretty(pg_database_size('neondb'));

-- Check table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Troubleshooting

### Function Not Found
```sql
-- Recreate the function
DROP FUNCTION IF EXISTS get_user_stats(TEXT);
-- Then run the CREATE FUNCTION statement again
```

### Permission Issues
```sql
-- Grant execute permissions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO neondb_owner;
```

### Performance Issues
```sql
-- Analyze tables for better query planning
ANALYZE sources;
ANALYZE notebooks;
ANALYZE tags;
```

## Next Steps

1. Run `neon_functions.sql` in your Neon database
2. Update your app to use `NeonFunctionsService`
3. Remove Firebase Functions dependencies
4. Test all functionality
5. Monitor performance and storage usage

Your app now runs entirely on Neon + Firebase Auth! 🚀
