# Backend Credit Management Implementation

## Overview
Moved credit management from client-side to backend for security, accuracy, and fraud prevention.

## Architecture

### Backend Components

#### 1. Credit Service (`backend/src/services/creditService.ts`)
Centralized credit management with atomic transactions:

```typescript
// Check if user has enough credits
checkCredits(userId, amount): Promise<CreditCheckResult>

// Consume credits atomically (with database transaction)
consumeCredits(userId, amount, feature, metadata): Promise<CreditConsumeResult>

// Calculate credit cost for chat
calculateChatCreditCost({ useDeepSearch, hasImage }): number

// Get current balance
getCreditBalance(userId): Promise<number>
```

**Key Features:**
- **Atomic transactions** - Uses `FOR UPDATE` lock to prevent race conditions
- **Rollback on failure** - Ensures consistency
- **Audit trail** - All transactions logged in `credit_transactions` table

#### 2. Updated AI Stream Endpoint (`backend/src/routes/ai.ts`)

**Flow:**
1. Calculate credit cost based on features
2. Check if user has enough credits
3. **Deduct credits BEFORE AI call** (prevents fraud)
4. If AI call fails, credits already deducted (user paid for attempt)
5. Stream AI response

**Error Handling:**
- `402 Payment Required` - Insufficient credits
- `403 Forbidden` - Premium model access denied (with refund)
- `500 Internal Server Error` - Processing failed

### Client Components

#### 1. API Service (`lib/core/api/api_service.dart`)

**New Exception:**
```dart
class InsufficientCreditsException implements Exception {
  final String message;
  final int required;
  final int available;
}
```

**Updated Stream Method:**
```dart
Stream<String> chatWithAIStream({
  required List<Map<String, dynamic>> messages,
  String provider = 'gemini',
  String? model,
  bool useDeepSearch = false,  // NEW
  bool hasImage = false,        // NEW
})
```

- Passes `useDeepSearch` and `hasImage` flags to backend
- Handles 402 errors and throws `InsufficientCreditsException`

#### 2. Chat Provider (`lib/features/chat/chat_provider.dart`)

**Changes:**
- ✅ Removed client-side credit charging
- ✅ Added try-catch for `InsufficientCreditsException`
- ✅ Shows user-friendly error message
- ✅ Invalidates subscription provider to refresh balance

**Error Display:**
```dart
⚠️ **Insufficient Credits**

You need 6 credits but only have 2 credits available.

Please purchase more credits or upgrade your plan to continue.
```

## Credit Costs

| Feature | Cost | Notes |
|---------|------|-------|
| Chat Message | 1 | Base cost |
| Deep Search | +5 | Added to base |
| Image Analysis | +1 | Added to base |
| Voice Mode | 2 | |
| Meeting Mode | 3 | |
| Flashcards | 2 | |
| Quiz | 2 | |
| Mind Map | 3 | |
| Study Guide | 3 | |
| Infographic | 5 | |
| Podcast | 10 | |
| Audio Overview | 5 | |
| Text-to-Speech | 2 | |
| Transcription | 3 | |
| Ebook | 15 | |
| Story | 5 | |
| Meal Plan | 2 | |
| Tutor Session | 3 | |

## Security Benefits

### Before (Client-Side)
❌ Users could bypass credit checks  
❌ Race conditions with multiple tabs  
❌ Balance could get out of sync  
❌ No enforcement  
❌ Client code could be modified  

### After (Backend)
✅ **Impossible to bypass** - Server enforces all checks  
✅ **Atomic transactions** - No race conditions  
✅ **Single source of truth** - Always accurate  
✅ **Audit trail** - All transactions logged  
✅ **Consistent** - Works across all platforms  

## Database Schema

### credit_transactions Table
```sql
CREATE TABLE credit_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    amount INTEGER NOT NULL,              -- Negative for consumption
    transaction_type TEXT NOT NULL,       -- 'consumption', 'purchase', 'refund', etc.
    description TEXT,
    balance_after INTEGER,                -- Balance after transaction
    metadata JSONB,                       -- Additional context
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Example Transaction:**
```json
{
  "user_id": "123",
  "amount": -6,
  "transaction_type": "consumption",
  "description": "Used 6 credits for deep_research",
  "balance_after": 44,
  "metadata": {
    "model": "gemini-2.0-flash",
    "provider": "gemini",
    "useDeepSearch": true,
    "hasImage": false,
    "messageCount": 3
  }
}
```

## API Endpoints

### POST /api/ai/chat/stream
**Request:**
```json
{
  "messages": [...],
  "provider": "gemini",
  "model": "gemini-2.0-flash",
  "useDeepSearch": true,
  "hasImage": false
}
```

**Success Response (200):**
```
data: {"text": "chunk1"}
data: {"text": "chunk2"}
data: [DONE]
```

**Insufficient Credits (402):**
```json
{
  "error": "Insufficient credits",
  "message": "You need 6 credits but only have 2 credits available.",
  "required": 6,
  "available": 2,
  "payment_required": true
}
```

**Premium Access Required (403):**
```json
{
  "error": "Premium model access required",
  "message": "This model is only available to paid subscribers.",
  "upgrade_required": true
}
```

## Testing

### Test Insufficient Credits
1. Set user balance to 1 credit
2. Try to send a message with deep search (costs 6)
3. Should receive 402 error
4. Balance should remain 1 (not deducted)

### Test Successful Deduction
1. Set user balance to 10 credits
2. Send a message (costs 1)
3. Should stream successfully
4. Balance should be 9 credits
5. Transaction should be logged

### Test Race Condition
1. Open two tabs
2. Set balance to 1 credit
3. Send message in both tabs simultaneously
4. Only one should succeed
5. Other should get 402 error

### Test Refund on Premium Denial
1. Set user to free plan
2. Try to use premium model
3. Should get 403 error
4. Credits should be refunded

## Migration Guide

### For Other Features

To add backend credit management to other features:

1. **Calculate cost:**
```typescript
const creditCost = CreditCosts.generateQuiz; // 2 credits
```

2. **Check credits:**
```typescript
const check = await checkCredits(userId, creditCost);
if (!check.hasEnough) {
  return res.status(402).json({
    error: 'Insufficient credits',
    required: creditCost,
    available: check.currentBalance
  });
}
```

3. **Consume credits:**
```typescript
const result = await consumeCredits(
  userId,
  creditCost,
  'generate_quiz',
  { notebookId, questionCount: 10 }
);

if (!result.success) {
  return res.status(402).json({ error: result.error });
}
```

4. **Process request:**
```typescript
// Your feature logic here
const quiz = await generateQuiz(...);
res.json({ quiz });
```

## Monitoring

### Check Credit Transactions
```sql
SELECT 
  user_id,
  amount,
  transaction_type,
  description,
  balance_after,
  created_at
FROM credit_transactions
WHERE user_id = 'USER_ID'
ORDER BY created_at DESC
LIMIT 50;
```

### Check User Balance
```sql
SELECT 
  current_credits,
  credits_consumed_this_month,
  plan_id
FROM user_subscriptions
WHERE user_id = 'USER_ID';
```

### Find Suspicious Activity
```sql
-- Users with negative balance (shouldn't happen)
SELECT user_id, current_credits
FROM user_subscriptions
WHERE current_credits < 0;

-- High consumption in short time
SELECT 
  user_id,
  COUNT(*) as transaction_count,
  SUM(ABS(amount)) as total_consumed
FROM credit_transactions
WHERE 
  transaction_type = 'consumption'
  AND created_at > NOW() - INTERVAL '1 hour'
GROUP BY user_id
HAVING SUM(ABS(amount)) > 100
ORDER BY total_consumed DESC;
```

## Rollback Plan

If issues arise, you can temporarily disable credit checking:

1. Comment out credit check in `backend/src/routes/ai.ts`:
```typescript
// const creditCheck = await checkCredits(userId, creditCost);
// if (!creditCheck.hasEnough) { ... }
```

2. Comment out credit consumption:
```typescript
// const consumeResult = await consumeCredits(...);
```

3. Restart backend

**Note:** This is for emergency only. Re-enable as soon as possible.

## Future Enhancements

1. **Credit Packages** - Allow users to purchase credit bundles
2. **Subscription Renewals** - Auto-renew credits monthly
3. **Credit Expiry** - Expire unused credits after X months
4. **Usage Analytics** - Dashboard showing credit usage patterns
5. **Rate Limiting** - Prevent abuse with per-minute limits
6. **Webhooks** - Notify users when credits are low
7. **Rollover Credits** - Allow unused credits to roll over

## Summary

✅ Credits checked and deducted on backend  
✅ Atomic transactions prevent race conditions  
✅ Impossible to bypass security  
✅ User-friendly error messages  
✅ Full audit trail  
✅ Consistent across all platforms  
✅ Ready for production  
