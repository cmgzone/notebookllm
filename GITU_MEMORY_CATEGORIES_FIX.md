# Gitu Memory Categories Fix

## Issue
The `gitu_memories` table had a constraint that only allowed these categories:
- personal
- work
- preference
- fact
- context

However, the memory extraction service was trying to create memories with category `relationship`, causing database constraint violations.

## Error
```
error: new row for relation "gitu_memories" violates check constraint "valid_memory_category"
Failing row contains (..., relationship, User has a contact named Kana in their WhatsApp, ...)
```

## Solution
Expanded the `valid_memory_category` constraint to include additional useful memory types:

### New Categories Added
- **relationship**: Tracks user relationships and contacts
- **skill**: User skills and abilities
- **goal**: User goals and objectives
- **habit**: User habits and routines
- **event**: Important events and dates
- **location**: Frequently visited or important locations
- **contact**: Contact information and details

## Migration

Run the migration:
```bash
cd backend
npm run ts-node src/scripts/run-fix-memory-categories.ts
```

Or manually:
```sql
ALTER TABLE gitu_memories DROP CONSTRAINT IF EXISTS valid_memory_category;

ALTER TABLE gitu_memories ADD CONSTRAINT valid_memory_category 
  CHECK (category IN (
    'personal', 'work', 'preference', 'fact', 'context',
    'relationship', 'skill', 'goal', 'habit', 'event', 'location', 'contact'
  ));
```

## Impact
- Fixes the memory extraction error when processing WhatsApp messages
- Enables richer memory categorization for better personalization
- Allows Gitu to remember relationships, skills, goals, and more

## Testing
After migration, verify:
1. Memory extraction works without constraint violations
2. Relationship memories are created successfully
3. All new categories can be used

## Related Files
- `backend/migrations/fix_gitu_memory_categories.sql`
- `backend/src/scripts/run-fix-memory-categories.ts`
- `backend/src/services/gituMemoryExtractor.ts`
