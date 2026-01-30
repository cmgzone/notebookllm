
import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import pool from '../config/database.js';
import { gituUsageGovernor } from '../services/gituUsageGovernor.js';

describe('Gitu Cost Tracking Integration Tests', () => {
  const testUserId = 'test-user-cost-' + Date.now();

  beforeEach(async () => {
    // Create test user
    await pool.query(
      `INSERT INTO users (id, email, display_name, password_hash) 
       VALUES ($1, $2, $3, $4) 
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, `test-${testUserId}@example.com`, 'Test User', 'dummy-hash']
    );

    // Set custom limits for testing
    await pool.query(
      `INSERT INTO gitu_usage_limits (user_id, daily_limit_usd, per_task_limit_usd, monthly_limit_usd, hard_stop, alert_thresholds)
       VALUES ($1, 10.0, 5.0, 100.0, true, $2)
       ON CONFLICT (user_id) DO UPDATE 
       SET daily_limit_usd = EXCLUDED.daily_limit_usd`,
      [testUserId, [0.5, 0.75, 0.9]]
    );
  });

  afterEach(async () => {
    // Clean up usage logs
    await pool.query('DELETE FROM gitu_usage_records WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM gitu_usage_limits WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
  });

  it('should track usage and accumulate costs', async () => {
    // Record multiple operations
    await gituUsageGovernor.recordUsage(testUserId, {
      userId: testUserId,
      operation: 'chat',
      model: 'gemini-2.0-flash',
      platform: 'terminal',
      tokensUsed: 100,
      costUSD: 0.05,
      timestamp: new Date(),
    });

    await gituUsageGovernor.recordUsage(testUserId, {
      userId: testUserId,
      operation: 'research',
      model: 'gemini-1.5-pro',
      platform: 'web',
      tokensUsed: 500,
      costUSD: 0.25,
      timestamp: new Date(),
    });

    // Verify usage stats
    const stats = await gituUsageGovernor.getCurrentUsage(testUserId, 'day');
    
    expect(stats.totalCostUSD).toBeCloseTo(0.30, 5);
    expect(stats.totalTokens).toBe(600);
    expect(stats.operationCount).toBe(2);
    expect(stats.byPlatform.terminal.cost).toBeCloseTo(0.05, 5);
    expect(stats.byPlatform.web.cost).toBeCloseTo(0.25, 5);
  });

  it('should enforce budget limits', async () => {
    // Check small amount - should pass
    const check1 = await gituUsageGovernor.checkBudget(testUserId, 1.0);
    expect(check1.allowed).toBe(true);

    // Record usage to near limit (9.0 used, 10.0 limit)
    await gituUsageGovernor.recordUsage(testUserId, {
      userId: testUserId,
      operation: 'heavy-task',
      model: 'gpt-4',
      platform: 'terminal',
      tokensUsed: 1000,
      costUSD: 9.0,
      timestamp: new Date(),
    });

    // Check amount that fits (0.5) - should pass
    const check2 = await gituUsageGovernor.checkBudget(testUserId, 0.5);
    expect(check2.allowed).toBe(true);

    // Check amount that exceeds (1.5) - should fail
    const check3 = await gituUsageGovernor.checkBudget(testUserId, 1.5);
    expect(check3.allowed).toBe(false);
    expect(check3.reason).toContain('daily limit');
  });

  it('should generate alerts when thresholds crossed', async () => {
    // 10.0 limit, 50% threshold = 5.0
    
    // Record usage to 6.0
    await gituUsageGovernor.recordUsage(testUserId, {
      userId: testUserId,
      operation: 'chat',
      model: 'gemini-2.0-flash',
      platform: 'terminal',
      tokensUsed: 1000,
      costUSD: 6.0,
      timestamp: new Date(),
    });

    const alerts = await gituUsageGovernor.checkThresholds(testUserId);
    
    expect(alerts.length).toBeGreaterThan(0);
    expect(alerts[0].percentage).toBeGreaterThanOrEqual(50);
    expect(alerts[0].message).toContain('Daily usage');
  });
});
