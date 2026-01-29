# Gitu AI Router - Database Model Loading Implementation

## Summary

Successfully completed the implementation of database model loading for the Gitu AI Router service. The service now dynamically loads AI models from the `ai_models` database table instead of using hardcoded model definitions.

## Changes Made

### 1. Database Model Loading (`gituAIRouter.ts`)

**Added:**
- `DBModel` interface for database model structure
- `mapProviderName()` function to map database provider names to AIModel provider types
- `loadModelsFromDatabase()` method to query and cache models from database
- `getModels()` method with cache management (5-minute TTL)
- Model cache variables: `modelsCache`, `modelsCacheTimestamp`, `MODELS_CACHE_TTL`

**Updated Methods:**
- `selectModel()` - Now uses database-loaded models
- `findModelWithLargerContext()` - Uses database models
- `estimateCost()` - Uses database models for alternatives
- `fallback()` - Uses database models for finding alternatives
- `suggestCheaperModel()` - Uses database models
- `getAvailableModels()` - Filters database models based on user's API keys

### 2. Provider Mapping

The service now correctly maps database provider names to the AIModel interface:
- `google` or `gemini` → `gemini`
- `openrouter` → `openrouter`
- `openai` → `openai`
- `anthropic` → `anthropic`

### 3. Cost Calculation

Models loaded from database include separate `input_cost_per_token` and `output_cost_per_token` fields. The service calculates an average cost per 1k tokens for the `AIModel` interface:

```typescript
const avgCostPer1kTokens = ((dbModel.input_cost_per_token + dbModel.output_cost_per_token) / 2) * 1000;
```

### 4. Cache Management

- Models are cached for 5 minutes to reduce database queries
- Cache is automatically refreshed when expired
- Cache timestamp is tracked to determine validity

### 5. Error Handling

- Returns empty object on database error (triggers fallback behavior)
- Throws descriptive error when no models are available
- Logs model loading success/failure

## Test Updates

Updated `gituAIRouter.test.ts` to:
- Mock database responses with realistic model data
- Test database model loading
- Test cache behavior
- Test error handling when no models available
- Verify provider mapping works correctly

## Database Schema

The service expects the following columns in the `ai_models` table:
- `id` (UUID)
- `name` (TEXT)
- `model_id` (TEXT) - Used as the key in the models cache
- `provider` (TEXT) - Mapped to AIModel provider type
- `context_window` (INTEGER)
- `input_cost_per_token` (DECIMAL)
- `output_cost_per_token` (DECIMAL)
- `is_active` (BOOLEAN) - Only active models are loaded

## Benefits

1. **Dynamic Configuration**: Admins can add/remove models through the admin panel without code changes
2. **Cost Flexibility**: Supports different input/output costs per model
3. **Performance**: 5-minute cache reduces database load
4. **Scalability**: Easy to add new providers and models
5. **Maintainability**: No hardcoded model definitions to update

## Usage Example

```typescript
// Models are automatically loaded from database on first use
const router = new GituAIRouter();

// Select model for a task (loads from database if cache expired)
const model = await router.selectModel('chat', userPreferences);

// Get available models for a user (respects personal API keys)
const availableModels = await router.getAvailableModels(userId);

// Models are cached for 5 minutes
// Next call within 5 minutes uses cached models
const model2 = await router.selectModel('research', userPreferences);
```

## Integration Points

The service integrates with:
1. **Admin Panel**: Models configured in admin panel are immediately available (after cache refresh)
2. **User Preferences**: Stored in `users.gitu_settings` JSONB column
3. **AI Service**: Routes requests to `generateWithGemini()` or `generateWithOpenRouter()`
4. **Database**: Queries `ai_models` table for active models

## Next Steps

1. Add admin panel UI for managing AI models
2. Implement model usage tracking
3. Add model performance metrics
4. Consider adding model-specific configuration (temperature, top_p, etc.)
5. Add webhook/event to invalidate cache when models are updated in admin panel

## Files Modified

- `backend/src/services/gituAIRouter.ts` - Core implementation
- `backend/src/__tests__/gituAIRouter.test.ts` - Test updates
- `backend/migrations/complete_schema.sql` - Database schema (already existed)

## Verification

The implementation has been verified to:
- ✅ Load models from database successfully
- ✅ Cache models for performance
- ✅ Map provider names correctly
- ✅ Calculate costs from separate input/output rates
- ✅ Handle missing models gracefully
- ✅ Support all existing functionality (fallback, cost estimation, etc.)
- ✅ Pass TypeScript compilation with no errors

## Conclusion

The Gitu AI Router now fully supports dynamic model loading from the database, enabling admins to configure available AI models through the admin panel. The implementation includes proper caching, error handling, and maintains backward compatibility with all existing features.
