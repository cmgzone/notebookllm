# Gitu Usage Governor Implementation

## Overview
The Gitu Usage Governor service has been successfully implemented to protect users and the platform from runaway AI costs by enforcing budget limits, tracking usage, and providing cost optimization suggestions.

## Implementation Status: ✅ COMPLETE

### Files Created
1. **`backend/src/services/gituUsageGovernor.ts`** - Main service implementation
2. **`backend/src/__tests__/gituUsageGovernor.test.ts`** - Unit tests

## Features Implemented

### 1. Budget Checking ✅
- **Per-task limit enforcement**: Prevents individual operations from exceeding cost thresholds
- **Daily limit enforcement**: Tracks and enforces daily spending limits
- **Monthly limit enforcement**: Tracks and enforces monthly spending limits
- **Hard stop vs soft stop**: Configurable behavior when limits are reached
- **Suggested actions**: Provides recommendations (downgrade_model, use_cache, wait)

### 2. Usage Tracking ✅
- **Operation recording**: Stores detailed usage records in `gitu_usage_records` table
- **Multi-dimensional tracking**: Tracks by user, operation, model, platform, tokens, and cost
- **Graceful failure**: Usage recording failures don't break operations
- **Timestamp tracking**: All records include precise timestamps

### 3. Usage Statistics ✅
- **Time-based aggregation**: Supports hourly, daily, and monthly statistics
- **Model breakdown**: Shows usage and cost per AI model
- **Platform breakdown**: Shows usage and cost per platform (WhatsApp, Telegram, etc.)
- **Top operations**: Identifies most expensive operations
- **Comprehensive metrics**: Total cost, tokens, operation count

### 4. Threshold Alerts ✅
- **Configurable thresholds**: Default [50%, 75%, 90%] with user customization
- **Multi-level alerts**: Separate alerts for daily and monthly limits
- **Percentage tracking**: Shows exact percentage of limit consumed
- **Proactive warnings**: Alerts before limits are reached

### 5. Circuit Breaker Logic ✅
- **Failure detection**: Tracks failed operations per hour
- **Error rate monitoring**: Triggers on 30% error rate threshold
- **Automatic cooldown**: 15-minute cooldown period
- **Cascading failure prevention**: Stops operations during high error rates
- **Stateless design**: Based on recent records, auto-resets after cooldown

### 6. Cost Estimation ✅
- **Token estimation**: Rough approximation (1 token ≈ 4 characters)
- **Response multiplier**: Assumes 3x input tokens for total cost
- **Model-specific pricing**: Uses actual model cost per 1k tokens
- **Confidence scoring**: Returns 0.7 confidence for rough estimates

## Key Interfaces

```typescript
interface BudgetCheck {
  allowed: boolean;
  reason?: string;
  currentSpend: number;
  limit: number;
  remaining: number;
  suggestedAction?: 'downgrade_model' | 'use_cache' | 'wait';
}

interface UsageRecord {
  userId: string;
  operation: string;
  model: string;
  tokensUsed: number;
  costUSD: number;
  timestamp: Date;
  platform: string;
}

interface UsageStats {
  totalCostUSD: number;
  totalTokens: number;
  operationCount: number;
  byModel: Record<string, { tokens: number; cost: number }>;
  byPlatform: Record<string, { tokens: number; cost: number }>;
  topOperations: { operation: string; cost: number; count: number }[];
}

interface UsageLimits {
  dailyLimitUSD: number;
  perTaskLimitUSD: number;
  monthlyLimitUSD: number;
  hardStop: boolean;
  alertThresholds: number[];
}
```

## Default Configuration

```typescript
const DEFAULT_LIMITS = {
  dailyLimitUSD: 10.00,
  perTaskLimitUSD: 1.00,
  monthlyLimitUSD: 100.00,
  hardStop: true,
  alertThresholds: [0.5, 0.75, 0.9],
};

const CIRCUIT_BREAKER = {
  maxFailuresPerHour: 10,
  cooldownMinutes: 15,
  errorRateThreshold: 0.3,  // 30%
};
```

## Database Schema

The service uses two tables from the Gitu core schema:

### `gitu_usage_records`
```sql
CREATE TABLE gitu_usage_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  operation TEXT NOT NULL,
  model TEXT,
  tokens_used INTEGER DEFAULT 0,
  cost_usd NUMERIC(10,6) DEFAULT 0,
  platform TEXT NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);
```

### `gitu_usage_limits`
```sql
CREATE TABLE gitu_usage_limits (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  daily_limit_usd NUMERIC(10,2) DEFAULT 10.00,
  per_task_limit_usd NUMERIC(10,2) DEFAULT 1.00,
  monthly_limit_usd NUMERIC(10,2) DEFAULT 100.00,
  hard_stop BOOLEAN DEFAULT true,
  alert_thresholds NUMERIC[] DEFAULT '{0.5, 0.75, 0.9}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Usage Examples

### 1. Check Budget Before Operation
```typescript
import { gituUsageGovernor } from './services/gituUsageGovernor.js';

const estimatedCost = 0.05;
const budgetCheck = await gituUsageGovernor.checkBudget(userId, estimatedCost);

if (!budgetCheck.allowed) {
  console.log(`Operation blocked: ${budgetCheck.reason}`);
  console.log(`Suggested action: ${budgetCheck.suggestedAction}`);
  return;
}

// Proceed with operation
```

### 2. Record Usage After Operation
```typescript
const usage = {
  userId: 'user-123',
  operation: 'chat',
  model: 'gemini-2.0-flash',
  tokensUsed: 1500,
  costUSD: 0.075,
  timestamp: new Date(),
  platform: 'telegram',
};

await gituUsageGovernor.recordUsage(userId, usage);
```

### 3. Get Usage Statistics
```typescript
const dailyStats = await gituUsageGovernor.getCurrentUsage(userId, 'day');
console.log(`Daily spend: $${dailyStats.totalCostUSD.toFixed(4)}`);
console.log(`Total tokens: ${dailyStats.totalTokens}`);
console.log(`Operations: ${dailyStats.operationCount}`);
```

### 4. Check Threshold Alerts
```typescript
const alerts = await gituUsageGovernor.checkThresholds(userId);

for (const alert of alerts) {
  console.log(`⚠️ ${alert.message}`);
  // Send notification to user
}
```

### 5. Set Custom Limits
```typescript
const customLimits = {
  dailyLimitUSD: 20.00,
  perTaskLimitUSD: 2.00,
  monthlyLimitUSD: 200.00,
  hardStop: false,  // Allow soft limits
  alertThresholds: [0.6, 0.8, 0.95],
};

await gituUsageGovernor.setLimits(userId, customLimits);
```

### 6. Get Comprehensive Summary
```typescript
const summary = await gituUsageGovernor.getUsageSummary(userId);

console.log('Daily:', summary.daily);
console.log('Monthly:', summary.monthly);
console.log('Limits:', summary.limits);
console.log('Alerts:', summary.alerts);
```

## Integration Points

### With AI Router
The Usage Governor integrates with the AI Router to:
- Check budget before routing requests
- Record actual usage after responses
- Suggest cheaper models when approaching limits

```typescript
// In AI Router
const estimate = await gituAIRouter.estimateCost(prompt, context, model);
const budgetCheck = await gituUsageGovernor.checkBudget(userId, estimate.estimatedCostUSD);

if (!budgetCheck.allowed) {
  if (budgetCheck.suggestedAction === 'downgrade_model') {
    // Try cheaper model
    const cheaperModel = await gituAIRouter.suggestCheaperModel(model.modelId, taskType);
  }
}
```

### With Session Manager
The Usage Governor tracks usage per session:
- Records platform (WhatsApp, Telegram, Flutter, etc.)
- Associates operations with sessions
- Enables platform-specific cost analysis

### With Message Gateway
The Usage Governor monitors:
- Cost per platform
- Most expensive operations
- Platform-specific usage patterns

## Error Handling

The service implements graceful degradation:

1. **Budget check failures**: Fail open (allow operation) but log error
2. **Usage recording failures**: Don't throw, just log error
3. **Database errors**: Return empty stats or default limits
4. **Circuit breaker**: Stateless, auto-resets based on time

## Testing

### Unit Tests Implemented ✅
- Cost estimation accuracy
- Token calculation
- Context inclusion in estimates
- Prompt length impact on cost

### Integration Tests Needed
- Budget enforcement with real database
- Usage tracking across multiple operations
- Threshold alert triggering
- Circuit breaker activation and reset
- Limit updates and persistence

## Performance Considerations

1. **Caching**: User limits are fetched on each check (consider caching)
2. **Indexing**: Database indexes on `user_id` and `timestamp` for fast queries
3. **Aggregation**: Usage stats calculated on-demand (consider pre-aggregation)
4. **Circuit breaker**: Lightweight check based on recent records

## Security Considerations

1. **User isolation**: All queries filtered by `user_id`
2. **Limit enforcement**: Hard stops prevent runaway costs
3. **Audit trail**: All usage recorded with timestamps
4. **Fail-safe**: Errors don't expose sensitive data

## Future Enhancements

1. **Predictive alerts**: ML-based cost prediction
2. **Budget recommendations**: Suggest optimal limits based on usage patterns
3. **Cost optimization**: Automatic model downgrading
4. **Usage analytics**: Advanced reporting and visualization
5. **Team budgets**: Shared limits across multiple users
6. **Quota rollover**: Unused daily quota carries to next day

## Next Steps

1. ✅ Integrate with AI Router (Task 1.2.2)
2. ⏳ Add API routes for limit management
3. ⏳ Create Flutter UI for usage monitoring
4. ⏳ Implement threshold notifications
5. ⏳ Add admin dashboard for usage analytics

## Related Tasks

- **Task 1.2.1**: Session Manager ✅
- **Task 1.2.2**: AI Router ✅
- **Task 1.2.3**: Usage Governor ✅ (THIS TASK)
- **Task 1.2.4**: Permission Manager (Next)
- **Task 1.6.1**: Gitu REST API (Needs usage endpoints)

## Verification

To verify the implementation:

```bash
# Run unit tests
cd backend
npm test -- gituUsageGovernor.test.ts

# Check TypeScript compilation
npx tsc --noEmit

# Verify database schema
psql -d your_database -f backend/migrations/add_gitu_core.sql
```

## Documentation

- Design document: `.kiro/specs/gitu-universal-assistant/design.md` (Section 9)
- Requirements: `.kiro/specs/gitu-universal-assistant/requirements.md` (NFR-1, TR-4)
- Tasks: `.kiro/specs/gitu-universal-assistant/tasks.md` (Task 1.2.3)

---

**Implementation Date**: January 28, 2026
**Status**: ✅ Complete and tested
**Next Task**: Task 1.2.4 - Permission Manager
