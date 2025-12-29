# Custom AI Model Setup Guide

## How to Add Custom Models via Admin Panel

When adding custom AI models through the admin panel, make sure to set the **context window** properly to avoid "Context limit exceeded" errors.

### Required Fields

1. **Name**: Display name (e.g., "Nano Mini")
2. **Model ID**: The actual model identifier used by the API (e.g., "google/gemini-nano-mini")
3. **Provider**: Which service to use
   - `gemini` - For Google Gemini models
   - `openrouter` - For OpenRouter
   - `openai` - Routes to OpenRouter
   - `anthropic` - Routes to OpenRouter
4. **Context Window**: **IMPORTANT** - Set this to the model's actual token limit

### Common Model Context Windows

#### Google Models
- **Gemini 1.5 Pro**: 2,000,000 tokens
- **Gemini 1.5 Flash**: 1,000,000 tokens
- **Gemini 2.0 Flash**: 1,000,000 tokens
- **Gemini Nano**: 128,000 tokens

#### OpenAI Models
- **GPT-4o**: 128,000 tokens
- **GPT-4 Turbo**: 128,000 tokens
- **GPT-4**: 8,192 tokens
- **GPT-3.5 Turbo**: 4,096 tokens
- **GPT-3.5 Turbo 16K**: 16,000 tokens

#### Anthropic (Claude) Models
- **Claude 3.5 Sonnet**: 200,000 tokens
- **Claude 3 Opus**: 200,000 tokens
- **Claude 3 Sonnet**: 200,000 tokens
- **Claude 3 Haiku**: 200,000 tokens

#### Other Models
- **Mistral Large**: 128,000 tokens
- **Mistral Medium**: 32,000 tokens
- **Llama 3.3/3.2**: 128,000 tokens
- **Llama 3.1**: 128,000 tokens
- **DeepSeek**: 64,000 tokens
- **Qwen**: 32,000 tokens

### Example: Adding "Nano Mini"

```
Name: Nano Mini
Model ID: google/gemini-nano-mini
Provider: gemini (or openrouter if via OpenRouter)
Context Window: 128000
Cost Input: 0
Cost Output: 0
Is Active: ✓
Is Premium: (depends on your setup)
```

### What Happens If You Don't Set Context Window?

If you leave context window at 0 or don't set it:
- The app will try to auto-detect based on the model ID
- For "nano mini", it will now detect 128K tokens
- For unknown models, it defaults to 32K tokens
- **BUT** it's always better to set it explicitly!

### Auto-Detection Logic

The app now auto-detects context windows for:
- ✅ Gemini models (1M-2M tokens)
- ✅ Nano models (128K tokens)
- ✅ Claude models (200K tokens)
- ✅ GPT-4 models (8K-128K tokens)
- ✅ Mistral models (32K-128K tokens)
- ✅ Llama models (8K-128K tokens)
- ✅ And more...

### Troubleshooting "Context Limit Exceeded"

If you see this error:
1. **Check your model's context window** in the admin panel
2. **Update it** to the correct value
3. **OR** switch to a model with larger context:
   - Gemini 1.5 Pro (2M tokens)
   - GPT-4 Turbo (128K tokens)
   - Claude 3.5 (200K tokens)

## UI Positioning Fix

The AI model selector has been moved from top-right to **bottom-left** (above the navigation bar) to avoid blocking page buttons and controls.

### New Position
- **Location**: Bottom-left corner
- **Above**: Navigation bar (80px from bottom)
- **No longer blocks**: Top app bars, buttons, or controls
- **Still accessible**: On every page

### How to Use
1. Look at bottom-left corner
2. Tap current model name
3. Select new model
4. Done! ✓

## Troubleshooting: Missing Context Window Field

If you do not see the **Context Window** field in your Admin Panel or cannot save it, it is likely because your database table is missing the context_window column.

### Fix 1: Run the Migration

1.  Connect to your Neon SQL Console (or local PostgreSQL).
2.  Run the contents of ackend/migrations/add_context_window_to_ai_models.sql:
    `sql
    ALTER TABLE ai_models 
    ADD COLUMN IF NOT EXISTS context_window INTEGER DEFAULT 0;
    `

### Fix 2: Check Admin Panel Version

- If you are using the **Flutter App**, make sure to **Full Restart** (stop and run) the app to pick up the code changes.
- If you are using the **React Admin Panel**, force refresh the page (Ctrl+F5) to clear the cache.

### Verification

Once fixed, you should see:
1.  **Context Window (tokens)** field in the Add/Edit Modal.
2.  Quick preset buttons (**128K**, **200K**, **1M**, **2M**).
3.  The value saving correctly to the database.
