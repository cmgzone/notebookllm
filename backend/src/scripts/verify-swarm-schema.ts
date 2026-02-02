import pool from '../config/database.js';

type ColumnCheck = {
  table: string;
  column: string;
  expectedDataType?: string;
};

async function getColumnType(client: any, table: string, column: string): Promise<string | null> {
  const res = await client.query(
    `SELECT data_type
     FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2`,
    [table, column]
  );
  if (res.rows.length === 0) return null;
  return String(res.rows[0].data_type || '').toLowerCase();
}

async function main() {
  const client = await pool.connect();
  try {
    const problems: string[] = [];

    const usersIdType = await getColumnType(client, 'users', 'id');
    if (!usersIdType) problems.push('users.id is missing');

    const expectedUserIdType = usersIdType || 'unknown';

    const checks: ColumnCheck[] = [
      { table: 'gitu_missions', column: 'user_id', expectedDataType: expectedUserIdType },
      { table: 'gitu_agents', column: 'user_id', expectedDataType: expectedUserIdType },
      { table: 'gitu_scheduled_tasks', column: 'user_id', expectedDataType: expectedUserIdType },
      { table: 'gitu_scheduled_tasks', column: 'cron' },
      { table: 'gitu_scheduled_tasks', column: 'max_retries' },
      { table: 'gitu_scheduled_tasks', column: 'retry_count' },
      { table: 'gitu_scheduled_tasks', column: 'updated_at' },
      { table: 'gitu_scheduled_tasks', column: 'action', expectedDataType: 'jsonb' },
      { table: 'gitu_scheduled_tasks', column: 'trigger', expectedDataType: 'jsonb' },
    ];

    for (const check of checks) {
      const actual = await getColumnType(client, check.table, check.column);
      if (!actual) {
        problems.push(`${check.table}.${check.column} is missing`);
        continue;
      }
      if (check.expectedDataType && check.expectedDataType !== 'unknown' && actual !== check.expectedDataType) {
        problems.push(`${check.table}.${check.column} expected ${check.expectedDataType}, got ${actual}`);
      }
    }

    if (problems.length > 0) {
      console.error('❌ Swarm schema check failed:');
      for (const p of problems) console.error(`- ${p}`);
      process.exitCode = 1;
      return;
    }

    const pendingAgents = await client.query(
      `SELECT COUNT(*)::int AS count
       FROM gitu_agents
       WHERE status IN ('pending','active')`
    );
    console.log('✅ Swarm schema check passed');
    console.log(`ℹ️ users.id type: ${usersIdType}`);
    console.log(`ℹ️ Pending/active agents: ${pendingAgents.rows[0]?.count ?? 0}`);
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
