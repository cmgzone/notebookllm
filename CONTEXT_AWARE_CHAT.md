# Context-Aware Chat Implementation

## What Changed
The AI chat now has full awareness of your sources and conversation history, making it much more intelligent and contextual.

## Features Added

### 1. **Sources Context** 
Every chat message now includes your sources automatically:
- AI can reference your documents, notes, URLs, YouTube videos, etc.
- Limited to 10 most recent sources (500 chars each) to avoid token limits
- Shows source title, type, and content preview

### 2. **Chat History**
AI remembers your conversation:
- Includes last 5 messages for context
- Maintains conversation flow
- AI can reference previous questions and answers

## How It Works

### Before (No Context)
```
User: "What did the article say about climate?"
AI: "I don't have access to any articles."
```

### After (With Context)
```
=== AVAILABLE SOURCES ===
Source: Climate Change Report 2024
Type: url
Content: Global temperatures have risen 1.5°C...

=== CONVERSATION HISTORY ===
User: Tell me about renewable energy
Assistant: Based on your sources, renewable energy...

=== CURRENT QUESTION ===
User: What did the article say about climate?
```

AI Response: "According to the Climate Change Report 2024 in your sources, global temperatures have risen 1.5°C..."

## Technical Details

### Files Modified
- `lib/features/chat/stream_provider.dart` - Added context building logic
- `lib/features/chat/chat_provider.dart` - Passes history to stream provider

### Context Limits (to avoid token overflow)
- **Sources**: Max 10 sources, 500 chars each = ~5,000 chars
- **History**: Last 5 messages = ~2,000 chars
- **Total context**: ~7,000 chars + your question

### Smart Context Building
The `_buildContextualPrompt()` method:
1. Reads all sources from `sourceProvider`
2. Formats them with clear headers
3. Adds recent chat history
4. Appends current question
5. Sends complete context to AI

## Benefits

✅ **Smarter Responses** - AI knows what you're talking about
✅ **Better Citations** - Can reference specific sources
✅ **Conversation Flow** - Remembers what you discussed
✅ **No Manual Context** - Automatic, no extra steps needed

## Token Usage Note
With context, each message uses more tokens:
- **Free models** (OpenRouter): May hit rate limits faster
- **Gemini**: Uses more of your quota
- Consider this when choosing between providers

## Testing
1. Add some sources (URLs, notes, etc.)
2. Start a chat: "Summarize my sources"
3. Follow up: "What about the second one?"
4. AI should remember both your sources and previous question

## Future Enhancements
- Toggle to disable context (for simple questions)
- Adjustable history length (3, 5, 10 messages)
- Source selection (choose which sources to include)
- Smart context pruning (only relevant sources)
