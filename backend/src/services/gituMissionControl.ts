import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { gituMessageGateway } from './gituMessageGateway.js';

export type MissionStatus = 'planning' | 'active' | 'completed' | 'failed' | 'paused';

export interface Mission {
    id: string;
    userId: string;
    name: string;
    objective: string;
    status: MissionStatus;
    context: Record<string, any>; // Shared "Truth"
    artifacts: Record<string, any>; // Outputs
    agentCount: number;
    createdAt: Date;
    updatedAt: Date;
    completedAt?: Date;
}

export interface MissionUpdate {
    status?: MissionStatus;
    contextUpdates?: Record<string, any>;
    artifacts?: Record<string, any>;
    logEntry?: string;
    completedAt?: Date;
}

class GituMissionControl {
    /**
     * Create a new mission (Swarm Operation)
     */
    async createMission(userId: string, name: string, objective: string): Promise<Mission> {
        const id = uuidv4();
        const initialContext = {
            objective,
            status: 'initialized',
            startedAt: new Date().toISOString(),
            globalKnowledge: {}, // Shared facts
        };

        const result = await pool.query(
            `INSERT INTO gitu_missions (id, user_id, name, objective, status, context, artifacts, agent_count)
       VALUES ($1, $2, $3, $4, 'planning', $5, '{}', 0)
       RETURNING *`,
            [id, userId, name, objective, JSON.stringify(initialContext)]
        );

        return this.mapRowToMission(result.rows[0]);
    }

    /**
     * Get mission by ID
     */
    async getMission(missionId: string): Promise<Mission | null> {
        const result = await pool.query(`SELECT * FROM gitu_missions WHERE id = $1`, [missionId]);
        if (result.rows.length === 0) return null;
        return this.mapRowToMission(result.rows[0]);
    }

    /**
     * List active missions for a user
     */
    async listActiveMissions(userId: string): Promise<Mission[]> {
        const result = await pool.query(
            `SELECT * FROM gitu_missions 
       WHERE user_id = $1 AND status NOT IN ('completed', 'failed')
       ORDER BY updated_at DESC`,
            [userId]
        );
        return result.rows.map(this.mapRowToMission);
    }

    /**
     * Update mission state (Single Point of Truth update)
     * This is called by agents to share their findings.
     */
    async updateMissionState(missionId: string, update: MissionUpdate): Promise<Mission> {
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // 1. Get current state (lock row)
            const currentRes = await client.query(
                `SELECT * FROM gitu_missions WHERE id = $1 FOR UPDATE`,
                [missionId]
            );

            if (currentRes.rows.length === 0) throw new Error('Mission not found');
            const current = currentRes.rows[0];

            // 2. Merge updates
            let newStatus = update.status || current.status;

            const currentContext = current.context || {};
            const newContext = update.contextUpdates
                ? { ...currentContext, ...update.contextUpdates }
                : currentContext;

            const currentArtifacts = current.artifacts || {};
            const newArtifacts = update.artifacts
                ? { ...currentArtifacts, ...update.artifacts }
                : currentArtifacts;

            // 3. Update DB
            // We construct the query dynamically or just always update completed_at if provided
            let completedAtClause = '';
            const params: any[] = [newStatus, JSON.stringify(newContext), JSON.stringify(newArtifacts), missionId];

            if (update.completedAt) {
                completedAtClause = ', completed_at = $5';
                params.push(update.completedAt);
            }

            const result = await client.query(
                `UPDATE gitu_missions 
                 SET status = $1, context = $2, artifacts = $3, updated_at = NOW() ${completedAtClause}
                 WHERE id = $4
                 RETURNING *`,
                params
            );

            // 4. Log significant events
            if (update.logEntry) {
                await client.query(
                    `INSERT INTO gitu_mission_logs (mission_id, message, created_at) VALUES ($1, $2, NOW())`,
                    [missionId, update.logEntry]
                );
            }

            await client.query('COMMIT');

            const mission = this.mapRowToMission(result.rows[0]);

            // 5. Notify frontend via socket (if we had one, for now push notification)
            // Only for status changes to avoid spam
            if (update.status && update.status !== current.status) {
                // Notify logic here
            }

            return mission;

        } catch (e) {
            await client.query('ROLLBACK');
            throw e;
        } finally {
            client.release();
        }
    }

    /**
     * Register a new agent to the swarm
     */
    async registerAgent(missionId: string): Promise<void> {
        await pool.query(
            `UPDATE gitu_missions SET agent_count = agent_count + 1 WHERE id = $1`,
            [missionId]
        );
    }

    /**
     * Stop a mission and all its associated agents
     */
    async stopMission(missionId: string, userId: string): Promise<void> {
        const mission = await this.getMission(missionId);
        if (!mission || mission.userId !== userId) throw new Error('Mission not found or unauthorized');

        await this.updateMissionState(missionId, {
            status: 'failed',
            logEntry: 'Mission stopped by user.'
        });

        // Fail all pending/active agents for this mission
        await pool.query(
            `UPDATE gitu_agents 
             SET status = 'failed', result = '{"error": "Mission cancelled by user"}'::jsonb, updated_at = NOW()
             WHERE user_id = $1 AND (memory->>'missionId') = $2 AND status IN ('pending', 'active')`,
            [userId, missionId]
        );
    }

    private mapRowToMission(row: any): Mission {
        return {
            id: row.id,
            userId: row.user_id,
            name: row.name,
            objective: row.objective,
            status: row.status,
            context: row.context || {},
            artifacts: row.artifacts || {},
            agentCount: row.agent_count || 0,
            createdAt: row.created_at,
            updatedAt: row.updated_at,
            completedAt: row.completed_at,
        };
    }
}

export const gituMissionControl = new GituMissionControl();
