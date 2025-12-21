-- ============================================
-- VERIFY NEON DEPLOYMENT
-- ============================================
-- Run these queries in Neon SQL Editor to verify everything is deployed

-- 1. Check all tables are created
SELECT 
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Expected: users, notebooks, sources, tags, source_tags, shares

-- 2. List all custom functions
SELECT 
    routine_name as function_name,
    routine_type as type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'
ORDER BY routine_name;

-- Expected: 15 functions including:
-- - get_user_stats
-- - get_notebook_analytics
-- - search_sources
-- - search_sources_filtered
-- - get_or_create_tag
-- - add_tag_to_source
-- - remove_tag_from_source
-- - get_popular_tags
-- - bulk_delete_sources
-- - bulk_add_tags
-- - bulk_remove_tags
-- - bulk_move_sources
-- - get_user_media_size
-- - cleanup_orphaned_media
-- - create_share_token
-- - validate_share_token
-- - list_shares
-- - revoke_share
-- - get_related_sources

-- 3. Check triggers
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY trigger_name;

-- Expected: 
-- - source_update_notebook_trigger
-- - cleanup_tags_trigger

-- 4. Check indexes
SELECT 
    indexname,
    tablename
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Expected: Multiple indexes on sources, notebooks, tags, etc.

-- 5. Test a function (should return empty result but no error)
SELECT get_user_stats('test-user-id');

-- 6. Count tables
SELECT COUNT(*) as table_count
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE';

-- Expected: 6 tables

-- 7. Count functions
SELECT COUNT(*) as function_count
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION';

-- Expected: 15+ functions

-- ============================================
-- QUICK VERIFICATION (Run this one query)
-- ============================================

SELECT 
    'Tables' as type,
    COUNT(*)::text as count
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE'

UNION ALL

SELECT 
    'Functions' as type,
    COUNT(*)::text as count
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'

UNION ALL

SELECT 
    'Triggers' as type,
    COUNT(*)::text as count
FROM information_schema.triggers
WHERE trigger_schema = 'public'

UNION ALL

SELECT 
    'Indexes' as type,
    COUNT(*)::text as count
FROM pg_indexes
WHERE schemaname = 'public';

-- Expected Results:
-- Tables: 6
-- Functions: 15+
-- Triggers: 2
-- Indexes: 10+
