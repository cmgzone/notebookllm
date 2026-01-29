/**
 * Unit tests for Gitu Usage Governor Service
 */

import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { gituUsageGovernor } from '../services/gituUsageGovernor.js';
import pool from '../config/database.js';

const mockQuery: any = jest.fn();
(pool as any).query = mockQuery;

describe('GituUsageGovernor', () => {
  beforeEach(() => {
    mockQuery.mockReset();
  });

  describe('estimateCost', () => {
    it('should estimate cost for operation', () => {
      const prompt = 'Hello, how are you?';
      const context = ['Previous message 1', 'Previous message 2'];
      const model = {
        provider: 'gemini' as const,
        modelId: 'gemini-2.0-flash',
        contextWindow: 1000000,
        costPer1kTokens: 0.05,
      };

      const estimate = gituUsageGovernor.estimateCost(prompt, context, model);

      expect(estimate.estimatedTokens).toBeGreaterThan(0);
      expect(estimate.estimatedCostUSD).toBeGreaterThan(0);
      expect(estimate.confidence).toBe(0.7);
    });

    it('should estimate higher cost for longer prompts', () => {
      const shortPrompt = 'Hi';
      const longPrompt = 'This is a much longer prompt that should result in a higher cost estimate because it contains many more tokens and will require more processing power from the AI model.';
      const context: string[] = [];
      const model = {
        provider: 'gemini' as const,
        modelId: 'gemini-2.0-flash',
        contextWindow: 1000000,
        costPer1kTokens: 0.05,
      };

      const shortEstimate = gituUsageGovernor.estimateCost(shortPrompt, context, model);
      const longEstimate = gituUsageGovernor.estimateCost(longPrompt, context, model);

      expect(longEstimate.estimatedCostUSD).toBeGreaterThan(shortEstimate.estimatedCostUSD);
      expect(longEstimate.estimatedTokens).toBeGreaterThan(shortEstimate.estimatedTokens);
    });

    it('should include context in cost estimation', () => {
      const prompt = 'Hello';
      const emptyContext: string[] = [];
      const largeContext = ['Context message 1', 'Context message 2', 'Context message 3'];
      const model = {
        provider: 'gemini' as const,
        modelId: 'gemini-2.0-flash',
        contextWindow: 1000000,
        costPer1kTokens: 0.05,
      };

      const noContextEstimate = gituUsageGovernor.estimateCost(prompt, emptyContext, model);
      const withContextEstimate = gituUsageGovernor.estimateCost(prompt, largeContext, model);

      expect(withContextEstimate.estimatedCostUSD).toBeGreaterThan(noContextEstimate.estimatedCostUSD);
    });
  });

  describe('checkBudget', () => {
    it('should block when per-task limit is exceeded', async () => {
      mockQuery.mockResolvedValueOnce({
        rows: [
          {
            daily_limit_usd: '10',
            per_task_limit_usd: '0.5',
            monthly_limit_usd: '100',
            hard_stop: true,
            alert_thresholds: [0.5, 0.75, 0.9],
          },
        ],
      } as any);

      const result = await gituUsageGovernor.checkBudget('user-1', 1.0);

      expect(result.allowed).toBe(false);
      expect(result.suggestedAction).toBe('downgrade_model');
      expect(result.reason).toContain('per-task limit');
    });

    it('should block when daily limit would be exceeded (hard stop)', async () => {
      mockQuery
        .mockResolvedValueOnce({
          rows: [
            {
              daily_limit_usd: '10',
              per_task_limit_usd: '2',
              monthly_limit_usd: '100',
              hard_stop: true,
              alert_thresholds: [0.5, 0.75, 0.9],
            },
          ],
        } as any)
        .mockResolvedValueOnce({
          rows: [
            {
              operation: 'chat',
              model: 'gemini-2.0-flash',
              platform: 'terminal',
              tokens_used: '10',
              cost_usd: '9.90',
            },
          ],
        } as any)
        .mockResolvedValueOnce({ rows: [] } as any)
        .mockResolvedValueOnce({
          rows: [{ total_ops: '0', failed_ops: '0' }],
        } as any);

      const result = await gituUsageGovernor.checkBudget('user-1', 0.2);

      expect(result.allowed).toBe(false);
      expect(result.suggestedAction).toBe('wait');
      expect(result.reason).toContain('daily limit');
    });

    it('should allow when within limits', async () => {
      mockQuery
        .mockResolvedValueOnce({
          rows: [
            {
              daily_limit_usd: '10',
              per_task_limit_usd: '2',
              monthly_limit_usd: '100',
              hard_stop: true,
              alert_thresholds: [0.5, 0.75, 0.9],
            },
          ],
        } as any)
        .mockResolvedValueOnce({
          rows: [
            {
              operation: 'chat',
              model: 'gemini-2.0-flash',
              platform: 'terminal',
              tokens_used: '10',
              cost_usd: '1.25',
            },
          ],
        } as any)
        .mockResolvedValueOnce({
          rows: [
            {
              operation: 'chat',
              model: 'gemini-2.0-flash',
              platform: 'terminal',
              tokens_used: '10',
              cost_usd: '10.00',
            },
          ],
        } as any)
        .mockResolvedValueOnce({
          rows: [{ total_ops: '10', failed_ops: '0' }],
        } as any);

      const result = await gituUsageGovernor.checkBudget('user-1', 0.1);

      expect(result.allowed).toBe(true);
      expect(result.remaining).toBeGreaterThan(0);
    });
  });

  describe('recordUsage', () => {
    it('should not throw if database insert fails', async () => {
      mockQuery.mockRejectedValueOnce(new Error('db down'));

      await expect(
        gituUsageGovernor.recordUsage('user-1', {
          userId: 'user-1',
          operation: 'chat',
          model: 'gemini-2.0-flash',
          tokensUsed: 10,
          costUSD: 0.01,
          timestamp: new Date(),
          platform: 'terminal',
        })
      ).resolves.toBeUndefined();
    });
  });

  describe('getCurrentUsage', () => {
    it('should aggregate stats from usage records', async () => {
      mockQuery.mockResolvedValueOnce({
        rows: [
          {
            operation: 'chat',
            model: 'm1',
            platform: 'terminal',
            tokens_used: '100',
            cost_usd: '0.50',
          },
          {
            operation: 'chat',
            model: 'm1',
            platform: 'terminal',
            tokens_used: '50',
            cost_usd: '0.25',
          },
          {
            operation: 'search',
            model: 'm2',
            platform: 'flutter',
            tokens_used: '200',
            cost_usd: '1.00',
          },
        ],
      } as any);

      const stats = await gituUsageGovernor.getCurrentUsage('user-1', 'day');

      expect(stats.totalCostUSD).toBeCloseTo(1.75, 5);
      expect(stats.totalTokens).toBe(350);
      expect(stats.byModel.m1.cost).toBeCloseTo(0.75, 5);
      expect(stats.byPlatform.terminal.tokens).toBe(150);
      expect(stats.topOperations[0].operation).toBe('search');
    });
  });

  describe('checkThresholds', () => {
    it('should emit alerts when approaching thresholds', async () => {
      mockQuery
        .mockResolvedValueOnce({
          rows: [
            {
              daily_limit_usd: '10',
              per_task_limit_usd: '2',
              monthly_limit_usd: '100',
              hard_stop: true,
              alert_thresholds: [0.5, 0.75, 0.9],
            },
          ],
        } as any)
        .mockResolvedValueOnce({
          rows: [
            {
              operation: 'chat',
              model: 'm1',
              platform: 'terminal',
              tokens_used: '10',
              cost_usd: '6.00',
            },
          ],
        } as any)
        .mockResolvedValueOnce({
          rows: [
            {
              operation: 'chat',
              model: 'm1',
              platform: 'terminal',
              tokens_used: '10',
              cost_usd: '80.00',
            },
          ],
        } as any);

      const alerts = await gituUsageGovernor.checkThresholds('user-1');

      expect(alerts.length).toBeGreaterThan(0);
      expect(alerts.some(a => a.message.startsWith('Daily usage'))).toBe(true);
      expect(alerts.some(a => a.message.startsWith('Monthly usage'))).toBe(true);
    });
  });
});
