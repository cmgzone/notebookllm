# Default AI Model Feature

## Overview
Admins can now set a global default AI model that will be used across the application when users don't specify a model.

## Changes Made

### 1. Database Migration
**File**: `backend/migrations/add_default_ai_model.sql`
- Added `is_default` boolean column to `ai_models` table
- Created unique index to ensure only one model can be default
- Automatically sets `gemini-2.0-flash` as default (or first active model if not found)

**Run migration**:
```bash
cd backend
npm run ts-node src/scripts/run-default-model-migration.ts
```

### 2. Backend API Endpoints

#### Admin Endpoints (require admin role)
- `PUT /api/admin/models/:id/set-default` - Set a model as the default
- `GET /api/admin/models/default` - Get the current default model

#### Public Endpoint (requires authentication)
- `GET /api/ai/models/default` - Get the default model for use in the app

**Updated Files**:
- `backend/src/routes/admin.ts` - Added admin endpoints
- `backend/src/routes/ai.ts` - Added public endpoint and updated model listing to show default

### 3. Admin Panel UI
**File**: `admin_panel/src/pages/AIModels.jsx`

**Features Added**:
- "Default" badge displayed on the current default model
- "Set Default" button for non-default active models
- Clicking "Set Default" updates the global default model

**API Client**: `admin_panel/src/lib/api.js`
- Added `setDefaultAIModel(id)` method
- Added `getDefaultAIModel()` method

## Usage

### For Admins
1. Navigate to Admin Panel → AI Models
2. Find the model you want to set as default
3. Click "Set Default" button
4. The model will be marked with a blue "Default" badge
5. Only one model can be default at a time

### For Developers
```javascript
// Get the default model
const response = await fetch('/api/ai/models/default', {
  headers: { 'Authorization': `Bearer ${token}` }
});
const { model } = await response.json();

// Use the default model
const chatResponse = await fetch('/api/ai/chat', {
  method: 'POST',
  headers: { 
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    messages: [...],
    model: model.model_id,  // Use default model
    provider: model.provider
  })
});
```

### In Flutter App
The app can fetch the default model on startup and use it when no model is explicitly selected:

```dart
// In ai_settings_service.dart or similar
Future<AIModel> getDefaultModel() async {
  final response = await apiService.get('/ai/models/default');
  return AIModel.fromJson(response['model']);
}
```

## Benefits

1. **Consistency**: All users get the same default experience
2. **Cost Control**: Admins can set a cost-effective model as default
3. **Performance**: Can set the fastest model as default for better UX
4. **Flexibility**: Easy to change the default without code changes
5. **Fallback**: If no default is set, system falls back to gemini-2.0-flash

## Database Schema

```sql
ALTER TABLE ai_models 
ADD COLUMN is_default BOOLEAN DEFAULT FALSE;

CREATE UNIQUE INDEX idx_ai_models_default 
ON ai_models (is_default) 
WHERE is_default = TRUE;
```

## API Response Format

### GET /api/ai/models/default
```json
{
  "success": true,
  "model": {
    "id": "uuid",
    "name": "Gemini 2.0 Flash",
    "model_id": "gemini-2.0-flash",
    "provider": "gemini",
    "description": "Fast and efficient model",
    "context_window": 1000000,
    "is_active": true,
    "is_premium": false,
    "is_default": true
  }
}
```

### PUT /api/admin/models/:id/set-default
```json
{
  "success": true,
  "model": { ... },
  "message": "Default model updated successfully"
}
```

## Testing

1. **Set Default Model**:
   - Login as admin
   - Go to AI Models page
   - Click "Set Default" on any active model
   - Verify the "Default" badge appears

2. **Get Default Model**:
   ```bash
   curl -H "Authorization: Bearer YOUR_TOKEN" \
        http://localhost:3000/api/ai/models/default
   ```

3. **Verify Only One Default**:
   - Try setting multiple models as default
   - Verify only the last one selected remains default

## Notes

- Only active models can be set as default
- Deleting the default model will not automatically set a new default
- The unique index ensures database integrity
- Models are now sorted with default first in the list

## Future Enhancements

- Per-user default model preferences
- Default models per feature (chat, research, code review, etc.)
- Automatic fallback chain if default model is unavailable
- Usage analytics for default model
