import pool from '../config/database.js';

export type EvaluationTargetType = 'mission' | 'agent';
export type EvaluationEvaluator = 'system' | 'user' | 'auto';

export interface CreateEvaluationInput {
  userId: string;
  targetType: EvaluationTargetType;
  missionId: string;
  agentId?: string;
  evaluator: EvaluationEvaluator;
  score?: number;
  passed: boolean;
  criteria?: Record<string, any>;
  notes?: string;
}

export interface GituEvaluation {
  id: string;
  userId: string;
  targetType: EvaluationTargetType;
  missionId: string;
  agentId?: string;
  evaluator: EvaluationEvaluator;
  score?: number;
  passed: boolean;
  criteria: Record<string, any>;
  notes?: string;
  createdAt: Date;
}

class GituEvaluationService {
  async createEvaluation(input: CreateEvaluationInput): Promise<GituEvaluation> {
    const criteria = input.criteria ?? {};

    const res = await pool.query(
      `INSERT INTO gitu_evaluations (user_id, target_type, mission_id, agent_id, evaluator, score, passed, criteria, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        input.userId,
        input.targetType,
        input.missionId,
        input.agentId ?? null,
        input.evaluator,
        input.score ?? null,
        input.passed,
        JSON.stringify(criteria),
        input.notes ?? null
      ]
    );

    return this.mapRowToEvaluation(res.rows[0]);
  }

  async createAgentCompletionEvaluation(params: {
    userId: string;
    missionId: string;
    agentId: string;
    status: 'completed' | 'failed';
    toolCallsAttempted?: number;
  }): Promise<GituEvaluation> {
    const passed = params.status === 'completed';

    return this.createEvaluation({
      userId: params.userId,
      targetType: 'agent',
      missionId: params.missionId,
      agentId: params.agentId,
      evaluator: 'system',
      score: passed ? 1 : 0,
      passed,
      criteria: {
        kind: 'agent_completion',
        expectedStatus: 'completed',
        observedStatus: params.status,
        toolCallsAttempted: params.toolCallsAttempted ?? null
      }
    });
  }

  async createMissionCompletionEvaluation(params: {
    userId: string;
    missionId: string;
    agentCount: number;
    allTasksCompleted: boolean;
    finalReportPresent: boolean;
  }): Promise<GituEvaluation> {
    const passed = params.allTasksCompleted && params.finalReportPresent;
    const score = passed ? 1 : 0;

    return this.createEvaluation({
      userId: params.userId,
      targetType: 'mission',
      missionId: params.missionId,
      evaluator: 'system',
      score,
      passed,
      criteria: {
        kind: 'mission_completion',
        allTasksCompleted: params.allTasksCompleted,
        finalReportPresent: params.finalReportPresent,
        agentCount: params.agentCount
      }
    });
  }

  private mapRowToEvaluation(row: any): GituEvaluation {
    return {
      id: row.id,
      userId: row.user_id,
      targetType: row.target_type,
      missionId: row.mission_id,
      agentId: row.agent_id ?? undefined,
      evaluator: row.evaluator,
      score: row.score !== null && row.score !== undefined ? Number(row.score) : undefined,
      passed: row.passed,
      criteria: row.criteria || {},
      notes: row.notes ?? undefined,
      createdAt: row.created_at
    };
  }
}

export const gituEvaluationService = new GituEvaluationService();
