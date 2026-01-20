# Chat Message Delay Fix & Credit Charging Implementation

## Problem
Messages were delayed when sending to AI because the app was waiting for the database INSERT to complete before showing the message or starting the AI stream.

## Solution

### 1. Non-Blocking Message Sending
**Before:** 
```dart
await ref.read(apiServiceProvider).saveChatMessage(...); // BLOCKS
state = [...state, userMsg]; // Only then add to UI
```

**After:**
```dart
state = [...state, userMsg]; // Add to UI IMMEDIATELY
unawaited(ref.read(apiServiceProvider).saveChatMessage(...)); // Save in background
```

### 2. Credit Charging on AI Output
Added automatic credit deduction when AI generates a response:

- **Base cost:** 1 credit per chat message
- **Deep search:** +5 credits (if enabled)
- **Image analysis:** +1 credit (if image provided)

Credits are charged **after** the AI response completes, so users see the response before being charged.

## Changes Made

### File: `lib/features/chat/chat_provider.dart`

1. **Added imports:**
   - `import 'dart:async';` - for `unawaited()`
   - `import '../subscription/services/credit_manager.dart';` - for credit management

2. **Updated `send()` method:**
   - Messages now appear instantly in UI
   - User message saved to backend in background (non-blocking)
   - AI response streamed immediately
   - Credits charged after response completes
   - AI response saved to backend in background

3. **New method `_chargeCreditsForAIOutput()`:**
   - Calculates credit cost based on features used
   - Deducts credits without blocking UI
   - Logs errors but doesn't disrupt user experience

## Benefits

✅ **Instant message appearance** - No waiting for database
✅ **Faster AI response** - Streaming starts immediately
✅ **Automatic credit tracking** - Users charged for AI usage
✅ **Non-blocking operations** - All database saves happen in background
✅ **Error resilient** - Failed saves/charges don't break chat

## Credit Costs Reference

From `CreditCosts` class:
- Chat message: 1 credit
- Deep research: 5 credits
- Web search: 1 credit
- Image analysis: 1 credit (added in this implementation)

## Testing

To verify the fix works:
1. Send a message in chat
2. Message appears instantly (no delay)
3. AI response streams immediately
4. Check user's credit balance - should be deducted after response completes
5. Check database - messages are saved in background

## Notes

- Token counting is approximate (4 chars ≈ 1 token) for metadata tracking
- Credit charging happens asynchronously and won't block the UI
- If credit charging fails, it's logged but doesn't affect the chat experience
- All database operations use `unawaited()` to prevent blocking
