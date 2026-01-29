import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import pool from '../config/database.js';
import gituScheduler from '../services/gituScheduler.js';

describe('GituScheduler', () => {
  const testUserId = 'test-user-scheduler-' + Date.now();
  let createdTaskIds: string[] = [];

  beforeEach(async () => {
    await pool.query(
      `INSERT INTO users (id, email, display_name, password_hash) 
       VALUES ($1, $2, $3, $4) 
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, `test-${testUserId}@example.com`, 'Test User', 'dummy-hash']
    );
  });

  afterEach(async () => {
    for (const id of createdTaskIds) {
      await pool.query(`DELETE FROM gitu_scheduled_tasks WHERE id = $1`, [id]).catch(() => {});
    }
    createdTaskIds = [];
    await pool.query(`DELETE FROM users WHERE id = $1`, [testUserId]).catch(() => {});
  });

  it('should execute a due task with wildcard cron', async () => {
    const res = await pool.query(
      `INSERT INTO gitu_scheduled_tasks (user_id, name, action, cron, enabled) 
       VALUES ($1, $2, $3, $4, true) RETURNING id`,
      [testUserId, 'Detect Contradictions', 'memories.detectContradictions', '* * * * *']
    );
    const taskId = res.rows[0].id as string;
    createdTaskIds.push(taskId);

    const now = new Date();
    await gituScheduler.tick(now);

    const execs = await pool.query(
      `SELECT * FROM gitu_task_executions WHERE task_id = $1`,
      [taskId]
    );
    expect(execs.rowCount).toBeGreaterThanOrEqual(1);
  });
});

