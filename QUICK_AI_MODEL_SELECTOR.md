# Quick AI Model Selector - Feature Documentation

## Overview
Added a compact, always-visible AI model selector to every page of the application. Users can now quickly switch between AI models without navigating to the settings page.

## What Was Added

### 1. New Widget: `QuickAIModelSelector`
**Location**: `lib/ui/quick_ai_model_selector.dart`

A compact dropdown widget that:
- **Displays current AI model** with an icon
- **Shows all available models** grouped by provider (Gemini, OpenRouter)
- **Allows instant switching** with a single tap
- **Auto-saves selection** to SharedPreferences
- **Auto-detects provider** based on the selected model
- **Shows visual confirmation** via SnackBar when switching

### 2. Integration
**Location**: `lib/ui/app_scaffold.dart`

The selector is positioned in the **top-right corner** of every page:
- Uses `Positioned` widget within the existing `Stack`
- Wrapped in `SafeArea` to respect device notches/status bar
- Appears above all content but below any modals

## User Experience

### Visual Design
- **Compact pill shape** with rounded corners
- **Semi-transparent background** with subtle border
- **Icon + Model Name** display
- **Color-coded models**:
  - 🔵 Blue icon for Gemini models
  - 🟢 Green icon for free OpenRouter models
  - 🟡 Amber icon + 💎 for premium OpenRouter models

### Interaction Flow
1. User taps the current model name
2. Dropdown appears with grouped models:
   - **GEMINI** section header
   - List of Gemini models
   - **OPENROUTER** section header
   - List of OpenRouter models (with premium indicators)
3. User selects a model
4. Selection is instantly saved
5. Provider is auto-detected and saved
6. Confirmation SnackBar appears: "✓ Switched to [Model Name]"

## Technical Details

### State Management
- Uses Riverpod's `ConsumerWidget`
- Watches `availableModelsProvider` for model list
- Watches `selectedAIModelProvider` for current selection
- Updates both providers when selection changes

### Model Provider Detection
```dart
// Auto-detects if openai/anthropic should use OpenRouter service
final provider = model.provider;
String mappedProvider = provider;
if (provider == 'openai' || provider == 'anthropic') {
  mappedProvider = 'openrouter';
}
await AISettingsService.setProvider(mappedProvider);
```

### Persistence
- Model ID saved to `SharedPreferences` key: `'ai_model'`
- Provider saved to `SharedPreferences` key: `'ai_provider'`
- Changes take effect immediately across the app

## Benefits

1. **Instant Access**: No need to navigate to settings
2. **Context Awareness**: See which model you're using at a glance
3. **Quick Experimentation**: Easy to switch between models to compare results
4. **Visual Feedback**: Icons and labels make it clear which models are which
5. **Premium Indication**: Users know which models require payment

## Positioning Considerations

The selector is in the top-right because:
- ✓ Doesn't interfere with page content
- ✓ Consistent across all pages
- ✓ Familiar pattern (similar to language/theme selectors)
- ✓ Above the MiniAudioPlayer (bottom)
- ✓ Respects safe area for devices with notches

## Future Enhancements

Potential improvements:
- Add keyboard shortcut (Ctrl+M) to open dropdown
- Show model cost/limits in dropdown
- Add "Recommended" badge for certain models
- Include model performance indicators
- Allow filtering models by capability (e.g., vision, long-context)
