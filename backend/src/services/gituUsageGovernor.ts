/**
 * Gitu Usage Governor Service
 * Protects users and platform from runaway costs by enforcing budget limits,
 * tracking usage, and providing cost optimization suggestions.
 * 
 * Requirements: NFR-1 (Usability), TR-4 (Performance)
 * Design: Section 9 (Cost & Quota Governor)
 */

import pool from '../config/database.js';
import { AIModel } from './gituAIRouter.js';

// ==================== INTERFACES ====================

/**
 * Result of a budget check
 */
export interface BudgetCheck {
  allowed: boolean;
  reason?: string;
  currentSpend: number;
  limit: number;
  remaining: number;
  suggestedAction?: 'downgrade_model' | 'use_cache' | 'wait';
}

/**
 * Usage record for tracking AI operations
 */
export interface UsageRecord {
  userId: string;
  operation: string;
  model: string;
  tokensUsed: number;
  costUSD: number;
  timestamp: Date;
  platform: string;
}

/**
 * Usage statistics for a time period
 */
export interface UsageStats {
  totalCostUSD: number;
  totalTokens: number;
  operationCount: number;
  byModel: Record<string, { tokens: number; cost: number }>;
  byPlatform: Record<string, { tokens: number; cost: number }>;
  topOperations: { operation: string; cost: number; count: number }[];
}

/**
 * Usage limits configuration
 */
export interface UsageLimits {
  dailyLimitUSD: number;
  perTaskLimitUSD: number;
  monthlyLimitUSD: number;
  hardStop: boolean;  // If true, stop all operations when limit reached
  alertThresholds: number[];  // e.g., [0.5, 0.75, 0.9] for 50%, 75%, 90%
}

/**
 * Threshold alert when approaching limits
 */
export interface ThresholdAlert {
  threshold: number;
  currentUsage: number;
  limit: number;
  percentage: number;
  message: string;
}

/**
 * Cost estimate for an operation
 */
export interface CostEstimate {
  estimatedTokens: number;
  estimatedCostUSD: number;
  confidence: number;  // 0-1
  alternatives: { model: string; estimatedCost: number }[];
}

// ==================== CONSTANTS ====================

/**
 * Default usage limits for new users
 */
const DEFAULT_LIMITS: UsageLimits = {
  dailyLimitUSD: 10.00,
  perTaskLimitUSD: 1.00,
  monthlyLimitUSD: 100.00,
  hardStop: true,
  alertThresholds: [0.5, 0.75, 0.9],
};

/**
 * Circuit breaker thresholds
 */
const CIRCUIT_BREAKER = {
  maxFailuresPerHour: 10,
  cooldownMinutes: 15,
  errorRateThreshold: 0.3,  // 30% error rate triggers circuit breaker
};

// ==================== SERVICE CLASS ====================

class GituUsageGovernor {
  /**
   * Check if an operation is within the user's budget.
   * 
   * @param userId - The user's ID
   * @param estimatedCost - Estimated cost in USD
   * @returns Budget check result
   */
  async checkBudget(userId: string, estimatedCost: number): Promise<BudgetCheck> {
    try {
      // Get user's limits
      const limits = await this.getUserLimits(userId);
      
      // Check per-task limit
      if (estimatedCost > limits.perTaskLimitUSD) {
        return {
          allowed: false,
          reason: `Operation cost ($${estimatedCost.toFixed(4)}) exceeds per-task limit ($${limits.perTaskLimitUSD})`,
          currentSpend: 0,
          limit: limits.perTaskLimitUSD,
          remaining: 0,
          suggestedAction: 'downgrade_model',
        };
      }
      
      // Get current daily usage
      const dailyUsage = await this.getCurrentUsage(userId, 'day');
      const dailyRemaining = limits.dailyLimitUSD - dailyUsage.totalCostUSD;
      
      if (dailyUsage.totalCostUSD + estimatedCost > limits.dailyLimitUSD) {
        return {
          allowed: !limits.hardStop,
          reason: `Would exceed daily limit ($${limits.dailyLimitUSD}). Current: $${dailyUsage.totalCostUSD.toFixed(4)}`,
          currentSpend: dailyUsage.totalCostUSD,
          limit: limits.dailyLimitUSD,
          remaining: dailyRemaining,
          suggestedAction: limits.hardStop ? 'wait' : 'use_cache',
        };
      }
      
      // Get current monthly usage
      const monthlyUsage = await this.getCurrentUsage(userId, 'month');
      const monthlyRemaining = limits.monthlyLimitUSD - monthlyUsage.totalCostUSD;
      
      if (monthlyUsage.totalCostUSD + estimatedCost > limits.monthlyLimitUSD) {
        return {
          allowed: !limits.hardStop,
          reason: `Would exceed monthly limit ($${limits.monthlyLimitUSD}). Current: $${monthlyUsage.totalCostUSD.toFixed(4)}`,
          currentSpend: monthlyUsage.totalCostUSD,
          limit: limits.monthlyLimitUSD,
          remaining: monthlyRemaining,
          suggestedAction: limits.hardStop ? 'wait' : 'downgrade_model',
        };
      }
      
      // Check circuit breaker
      const circuitBreakerStatus = await this.checkCircuitBreaker(userId);
      if (!circuitBreakerStatus.allowed) {
        return {
          allowed: false,
          reason: circuitBreakerStatus.reason || 'Circuit breaker triggered due to high error rate',
          currentSpend: dailyUsage.totalCostUSD,
          limit: limits.dailyLimitUSD,
          remaining: dailyRemaining,
          suggestedAction: 'wait',
        };
      }
      
      // All checks passed
      return {
        allowed: true,
        currentSpend: dailyUsage.totalCostUSD,
        limit: limits.dailyLimitUSD,
        remaining: dailyRemaining,
      };
    } catch (error) {
      console.error('[Usage Governor] Error checking budget:', error);
      // Fail open - allow operation but log error
      return {
        allowed: true,
        reason: 'Budget check failed, allowing operation',
        currentSpend: 0,
        limit: DEFAULT_LIMITS.dailyLimitUSD,
        remaining: DEFAULT_LIMITS.dailyLimitUSD,
      };
    }
  }

  /**
   * Record usage after an operation completes.
   * 
   * @param usage - Usage record to store
   */
  async recordUsage(userId: string, usage: UsageRecord): Promise<void> {
    try {
      await pool.query(
        `INSERT INTO gitu_usage_records 
         (user_id, operation, model, tokens_used, cost_usd, platform, timestamp)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          userId,
          usage.operation,
          usage.model,
          usage.tokensUsed,
          usage.costUSD,
          usage.platform,
          usage.timestamp,
        ]
      );
      
      console.log(`[Usage Governor] Recorded usage for user ${userId}: $${usage.costUSD.toFixed(4)}`);
    } catch (error) {
      console.error('[Usage Governor] Error recording usage:', error);
      // Don't throw - usage recording failure shouldn't break the operation
    }
  }

  /**
   * Get current usage statistics for a time period.
   * 
   * @param userId - The user's ID
   * @param period - Time period ('hour', 'day', 'month')
   * @returns Usage statistics
   */
  async getCurrentUsage(userId: string, period: 'hour' | 'day' | 'month'): Promise<UsageStats> {
    try {
      // Calculate time range
      const now = new Date();
      let startTime: Date;
      
      switch (period) {
        case 'hour':
          startTime = new Date(now.getTime() - 60 * 60 * 1000);
          break;
        case 'day':
          startTime = new Date(now.getTime() - 24 * 60 * 60 * 1000);
          break;
        case 'month':
          startTime = new Date(now.getFullYear(), now.getMonth(), 1);
          break;
      }
      
      // Get usage records
      const result = await pool.query(
        `SELECT operation, model, platform, tokens_used, cost_usd
         FROM gitu_usage_records
         WHERE user_id = $1 AND timestamp >= $2
         ORDER BY timestamp DESC`,
        [userId, startTime]
      );
      
      // Aggregate statistics
      const stats: UsageStats = {
        totalCostUSD: 0,
        totalTokens: 0,
        operationCount: result.rows.length,
        byModel: {},
        byPlatform: {},
        topOperations: [],
      };
      
      const operationCosts: Record<string, { cost: number; count: number }> = {};
      
      for (const row of result.rows) {
        stats.totalCostUSD += parseFloat(row.cost_usd);
        stats.totalTokens += parseInt(row.tokens_used);
        
        // By model
        if (!stats.byModel[row.model]) {
          stats.byModel[row.model] = { tokens: 0, cost: 0 };
        }
        stats.byModel[row.model].tokens += parseInt(row.tokens_used);
        stats.byModel[row.model].cost += parseFloat(row.cost_usd);
        
        // By platform
        if (!stats.byPlatform[row.platform]) {
          stats.byPlatform[row.platform] = { tokens: 0, cost: 0 };
        }
        stats.byPlatform[row.platform].tokens += parseInt(row.tokens_used);
        stats.byPlatform[row.platform].cost += parseFloat(row.cost_usd);
        
        // By operation
        if (!operationCosts[row.operation]) {
          operationCosts[row.operation] = { cost: 0, count: 0 };
        }
        operationCosts[row.operation].cost += parseFloat(row.cost_usd);
        operationCosts[row.operation].count += 1;
      }
      
      // Sort top operations by cost
      stats.topOperations = Object.entries(operationCosts)
        .map(([operation, data]) => ({
          operation,
          cost: data.cost,
          count: data.count,
        }))
        .sort((a, b) => b.cost - a.cost)
        .slice(0, 10);
      
      return stats;
    } catch (error) {
      console.error('[Usage Governor] Error getting current usage:', error);
      // Return empty stats on error
      return {
        totalCostUSD: 0,
        totalTokens: 0,
        operationCount: 0,
        byModel: {},
        byPlatform: {},
        topOperations: [],
      };
    }
  }

  /**
   * Set usage limits for a user.
   * 
   * @param userId - The user's ID
   * @param limits - New usage limits
   */
  async setLimits(userId: string, limits: UsageLimits): Promise<void> {
    try {
      await pool.query(
        `INSERT INTO gitu_usage_limits 
         (user_id, daily_limit_usd, per_task_limit_usd, monthly_limit_usd, hard_stop, alert_thresholds, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW())
         ON CONFLICT (user_id) 
         DO UPDATE SET
           daily_limit_usd = $2,
           per_task_limit_usd = $3,
           monthly_limit_usd = $4,
           hard_stop = $5,
           alert_thresholds = $6,
           updated_at = NOW()`,
        [
          userId,
          limits.dailyLimitUSD,
          limits.perTaskLimitUSD,
          limits.monthlyLimitUSD,
          limits.hardStop,
          limits.alertThresholds,
        ]
      );
      
      console.log(`[Usage Governor] Updated limits for user ${userId}`);
    } catch (error) {
      console.error('[Usage Governor] Error setting limits:', error);
      throw error;
    }
  }

  /**
   * Check if user is approaching any usage thresholds.
   * 
   * @param userId - The user's ID
   * @returns Array of threshold alerts
   */
  async checkThresholds(userId: string): Promise<ThresholdAlert[]> {
    try {
      const limits = await this.getUserLimits(userId);
      const dailyUsage = await this.getCurrentUsage(userId, 'day');
      const monthlyUsage = await this.getCurrentUsage(userId, 'month');
      
      const alerts: ThresholdAlert[] = [];
      
      // Check daily thresholds
      for (const threshold of limits.alertThresholds) {
        const thresholdAmount = limits.dailyLimitUSD * threshold;
        if (dailyUsage.totalCostUSD >= thresholdAmount) {
          const percentage = (dailyUsage.totalCostUSD / limits.dailyLimitUSD) * 100;
          alerts.push({
            threshold,
            currentUsage: dailyUsage.totalCostUSD,
            limit: limits.dailyLimitUSD,
            percentage,
            message: `Daily usage at ${percentage.toFixed(1)}% ($${dailyUsage.totalCostUSD.toFixed(2)} of $${limits.dailyLimitUSD})`,
          });
        }
      }
      
      // Check monthly thresholds
      for (const threshold of limits.alertThresholds) {
        const thresholdAmount = limits.monthlyLimitUSD * threshold;
        if (monthlyUsage.totalCostUSD >= thresholdAmount) {
          const percentage = (monthlyUsage.totalCostUSD / limits.monthlyLimitUSD) * 100;
          alerts.push({
            threshold,
            currentUsage: monthlyUsage.totalCostUSD,
            limit: limits.monthlyLimitUSD,
            percentage,
            message: `Monthly usage at ${percentage.toFixed(1)}% ($${monthlyUsage.totalCostUSD.toFixed(2)} of $${limits.monthlyLimitUSD})`,
          });
        }
      }
      
      return alerts;
    } catch (error) {
      console.error('[Usage Governor] Error checking thresholds:', error);
      return [];
    }
  }

  /**
   * Get user's usage limits from database.
   * 
   * @param userId - The user's ID
   * @returns User's usage limits
   */
  private async getUserLimits(userId: string): Promise<UsageLimits> {
    try {
      const result = await pool.query(
        `SELECT daily_limit_usd, per_task_limit_usd, monthly_limit_usd, hard_stop, alert_thresholds
         FROM gitu_usage_limits
         WHERE user_id = $1`,
        [userId]
      );
      
      if (result.rows.length === 0) {
        // No limits set, return defaults
        return DEFAULT_LIMITS;
      }
      
      const row = result.rows[0];
      return {
        dailyLimitUSD: parseFloat(row.daily_limit_usd),
        perTaskLimitUSD: parseFloat(row.per_task_limit_usd),
        monthlyLimitUSD: parseFloat(row.monthly_limit_usd),
        hardStop: row.hard_stop,
        alertThresholds: row.alert_thresholds,
      };
    } catch (error) {
      console.error('[Usage Governor] Error getting user limits:', error);
      return DEFAULT_LIMITS;
    }
  }

  /**
   * Check circuit breaker status to prevent cascading failures.
   * 
   * @param userId - The user's ID
   * @returns Circuit breaker check result
   */
  private async checkCircuitBreaker(userId: string): Promise<{ allowed: boolean; reason?: string }> {
    try {
      // Get recent operations (last hour)
      const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
      
      const result = await pool.query(
        `SELECT COUNT(*) as total_ops,
                SUM(CASE WHEN cost_usd = 0 THEN 1 ELSE 0 END) as failed_ops
         FROM gitu_usage_records
         WHERE user_id = $1 AND timestamp >= $2`,
        [userId, oneHourAgo]
      );
      
      if (result.rows.length === 0) {
        return { allowed: true };
      }
      
      const totalOps = parseInt(result.rows[0].total_ops);
      const failedOps = parseInt(result.rows[0].failed_ops);
      
      // Check failure count
      if (failedOps >= CIRCUIT_BREAKER.maxFailuresPerHour) {
        return {
          allowed: false,
          reason: `Circuit breaker triggered: ${failedOps} failures in the last hour`,
        };
      }
      
      // Check error rate
      if (totalOps > 0) {
        const errorRate = failedOps / totalOps;
        if (errorRate >= CIRCUIT_BREAKER.errorRateThreshold) {
          return {
            allowed: false,
            reason: `Circuit breaker triggered: ${(errorRate * 100).toFixed(1)}% error rate`,
          };
        }
      }
      
      return { allowed: true };
    } catch (error) {
      console.error('[Usage Governor] Error checking circuit breaker:', error);
      // Fail open - allow operation
      return { allowed: true };
    }
  }

  /**
   * Estimate cost for an operation before execution.
   * 
   * @param prompt - The user's prompt
   * @param context - Context strings
   * @param model - The model to use
   * @returns Cost estimate
   */
  estimateCost(prompt: string, context: string[], model: AIModel): CostEstimate {
    // Estimate tokens (rough: 1 token ≈ 4 characters)
    const totalLength = prompt.length + context.reduce((sum, ctx) => sum + ctx.length, 0);
    const estimatedTokens = Math.ceil(totalLength / 4);
    
    // Estimate response tokens (assume 2x input for safety)
    const totalEstimatedTokens = estimatedTokens * 3;
    
    const estimatedCostUSD = (totalEstimatedTokens / 1000) * model.costPer1kTokens;
    
    return {
      estimatedTokens: totalEstimatedTokens,
      estimatedCostUSD,
      confidence: 0.7,  // Rough estimate
      alternatives: [],  // Populated by AI Router
    };
  }

  /**
   * Suggest a cheaper model for cost optimization.
   * 
   * @param currentModel - Current model ID
   * @param taskType - Task type
   * @returns Suggested cheaper model or null
   */
  async suggestCheaperModel(currentModel: string, taskType: string): Promise<string | null> {
    // This would integrate with AI Router to find cheaper alternatives
    // For now, return null (to be implemented with AI Router integration)
    return null;
  }

  /**
   * Reset circuit breaker for a user (admin function).
   * 
   * @param userId - The user's ID
   */
  async resetCircuitBreaker(userId: string): Promise<void> {
    console.log(`[Usage Governor] Circuit breaker reset for user ${userId}`);
    // Circuit breaker is stateless based on recent records
    // No action needed - it will automatically reset after cooldown period
  }

  /**
   * Get usage summary for admin dashboard.
   * 
   * @param userId - The user's ID
   * @returns Comprehensive usage summary
   */
  async getUsageSummary(userId: string): Promise<{
    daily: UsageStats;
    monthly: UsageStats;
    limits: UsageLimits;
    alerts: ThresholdAlert[];
  }> {
    const [daily, monthly, limits, alerts] = await Promise.all([
      this.getCurrentUsage(userId, 'day'),
      this.getCurrentUsage(userId, 'month'),
      this.getUserLimits(userId),
      this.checkThresholds(userId),
    ]);
    
    return { daily, monthly, limits, alerts };
  }
}

// Export singleton instance
export const gituUsageGovernor = new GituUsageGovernor();
export default gituUsageGovernor;
