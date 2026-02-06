# OpenRouter Custom AI Models Fix

## Problem Summary

Custom AI models added via the admin panel (especially those with provider='openrouter', 'openai', or 'anthropic') were not working even after being selected in settings. This was caused by a fundamental architectural issue in how the application determined which AI service to use.

## Root Causes

### 1. **Provider Mismatch**
- When a custom model was added via admin panel with `provider='openrouter'` (or 'openai'/'anthropic'), it was saved to the database correctly
- However, the selected model ID was stored in SharedPreferences, but the provider detection relied entirely on the `'ai_provider'` SharedPreferences key
- This key was only updated when the user manually clicked the "Gemini" or "OpenRouter" card in settings

### 2. **No Automatic Provider Detection**
- The code used `_getSelectedProvider()` which simply read from SharedPreferences
- It didn't look up the selected model's actual provider from the database
- This meant custom models with provider='openai' or provider='anthropic' wouldn't be routed to OpenRouter service

### 3. **Provider Grouping vs Actual Provider Field**
- Models with provider='openrouter', 'openai', and 'anthropic' were all grouped under the 'openrouter' key in `availableModelsProvider`
- But when the AI service was called, it checked `if (provider == 'openrouter')` using SharedPreferences
- If SharedPreferences said 'gemini' but the selected model was 'openrouter', the wrong service was used

## Fixes Implemented

### 1. **Added Provider Lookup in AISettingsService** (`ai_settings_service.dart`)
```dart
/// Get the actual provider for a specific model by looking it up in the database
static Future<String> getProviderForModel(String modelId, Ref ref) async {
  final service = ref.read(aiModelServiceProvider);
  final models = await service.listModels();
  
  final model = models.where((m) => m.modelId == modelId).firstOrNull;
  
  if (model != null) {
    // Map the provider field to the correct service
    if (model.provider == 'openrouter' || 
        model.provider == 'openai' || 
        model.provider == 'anthropic') {
      return 'openrouter';
    }
    return model.provider;
  }
  
  // Fallback to SharedPreferences
  return await getProvider();
}
```

### 2. **Updated All _getSelectedProvider() Methods**
Modified the following files to auto-detect provider from the selected model:
- `lib/core/ai/ai_provider.dart`
- `lib/features/chat/stream_provider.dart`
- `lib/core/ai/deep_research_service.dart`
- `lib/core/ai/context_engineering_service.dart`

Each now uses this logic:
```dart
Future<String> _getSelectedProvider() async {
  final model = await AISettingsService.getModel();
  
  if (model != null && model.isNotEmpty) {
    // Auto-detect provider from the model
    return await AISettingsService.getProviderForModel(model, ref);
  }
  
  // Fallback to saved provider
  return await AISettingsService.getProvider();
}
```

### 3. **Auto-Sync Provider in Settings Screen**
Modified `ai_model_settings_screen.dart` to:
- **Auto-detect provider on load**: When settings load, it looks up the saved model's provider from the database and sets the UI accordingly
- **Auto-save on model selection**: When a model is selected from the dropdown, settings are automatically saved
- This ensures the provider always matches the selected model

## How It Works Now

1. **User adds custom model via admin panel**:
   - Model is saved with `provider='openrouter'` (or 'openai'/'anthropic')
   
2. **User selects the model in settings**:
   - Settings screen auto-saves the selection
   - Provider is auto-synced based on the model
   
3. **When AI is used**:
   - `_getSelectedProvider()` looks up the model ID from SharedPreferences
   - It queries the database to find the model's actual provider field
   - It maps 'openrouter', 'openai', and 'anthropic' to the OpenRouter service
   - The correct service (Gemini or OpenRouter) is used

## Testing

To verify the fix works:

1. **Add a custom OpenRouter model** via admin panel (`/admin/ai-models`)
   - Set provider to 'openrouter', 'openai', or 'anthropic'
   - Set model_id to a valid OpenRouter model (e.g., 'anthropic/claude-3-opus')

2. **Select the model** in AI Model Settings
   - Go to Settings → AI Model Settings
   - Click "OpenRouter" card
   - Select your custom model from dropdown
   - It should auto-save

3. **Test the model**:
   - Go to chat, deep research, or any AI feature
   - The custom model should be used correctly via OpenRouter

## Files Modified

```
lib/core/ai/ai_settings_service.dart
lib/core/ai/ai_provider.dart
lib/features/chat/stream_provider.dart
lib/core/ai/deep_research_service.dart
lib/core/ai/context_engineering_service.dart
lib/features/settings/ai_model_settings_screen.dart
```

## Future Improvements

Consider:
- Caching the provider lookup to avoid repeated database queries
- Adding provider validation when models are added via admin panel
- Showing the detected provider in the settings UI for transparency
- Adding a "test model" button in admin panel to verify model configuration
