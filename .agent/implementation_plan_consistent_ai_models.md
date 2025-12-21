---
description: Enforcing AI Model Selection Consistency
---

# Implementation Plan - Enforcing AI Model Selection Consistency

This plan outlines the changes made to ensure the user's selected AI model and provider (Gemini or OpenRouter) are consistently used across all application features, replacing hardcoded defaults.

## User Objective

To ensure that the AI model selected in settings (e.g., GPT-4o, Gemini 1.5 Pro) is used for all AI-powered features, including Podcast generation, Tutoring, Quizzes, Meal Planning, Story Generation, Research, and Ebook Agents.

## Changes Implemented

### 1. Extended OpenRouter Support
-   **`lib/core/ai/openrouter_service.dart`**: Added `paidModels` to support premium models like GPT-4o and Claude 3.5 Sonnet.
-   **`lib/features/settings/ai_model_settings_screen.dart`**: Updated UI to display and allow selection of these paid models.

### 2. Feature Providers Updated
The following providers were updated to read `ai_model` from `SharedPreferences` and pass it explicitly to `GeminiService.generateContent` or `OpenRouterService`:

-   **Podcast / Audio Overview**: `lib/features/studio/audio_overview_provider.dart`
-   **Mind Map**: `lib/features/mindmap/mind_map_provider.dart`
-   **Artifacts**: `lib/features/studio/artifact_provider.dart`
-   **Quiz**: `lib/features/quiz/quiz_provider.dart`
-   **Tutor**: `lib/features/tutor/tutor_provider.dart`
-   **Meal Planner**: `lib/features/meal_planner/meal_planner_provider.dart`
-   **Story Generator**: `lib/features/story_generator/story_generator_provider.dart`

### 3. Services Refactored
-   **Deep Research**: `lib/core/ai/deep_research_service.dart` - Updated to use selected model for sub-query generation and report synthesis.
-   **Context Engineering**: `lib/core/ai/context_engineering_service.dart` - Updated to pass selected model to Gemini service calls.
-   **Background AI**: `lib/core/services/background_ai_service.dart` - Updated `_runResearchInBackground` to support dynamic model parameters.
-   **Suggestions**: `lib/features/chat/services/suggestion_service.dart` - Completely refactored to support both Gemini and OpenRouter based on settings (removed hardcoded `gemini-1.5-flash`).
-   **Voice Action Handler**: `lib/core/audio/voice_action_handler.dart` - Updated ebook creation flow to use selected model.

### 4. Chat & Ebook Integrations
-   **Chat**: `lib/features/chat/chat_provider.dart` - New Ebooks created via chat now initialize with the user's preferred model.
-   **ElevenLabs Agent**: `lib/features/chat/elevenlabs_agent_screen.dart` - Ebooks created via voice agent now initialize with the user's preferred model.

## Verification
-   **Static Analysis**: Ran `flutter analyze` on modified files to ensure no syntax errors.
-   **Code Review**: Verified that hardcoded `'gemini-1.5-flash'` strings in critical paths were replaced with dynamic logic.

## Next Steps
-   User should verify functionality by selecting a distinct model (e.g., a paid OpenRouter model) and testing various features to ensure they work as expected.
