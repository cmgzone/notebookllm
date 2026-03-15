import pkg from 'pg';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const { Pool } = pkg;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function loadEnv() {
  const envPaths = [
    path.join(__dirname, '../../.env'),
    path.join(__dirname, '../.env'),
    path.join(process.cwd(), '.env'),
  ];

  for (const envPath of envPaths) {
    if (fs.existsSync(envPath)) {
      dotenv.config({ path: envPath });
      return envPath;
    }
  }
  dotenv.config();
  return null;
}

function buildConnectionStringFromNeonEnv() {
  const host = process.env.NEON_HOST;
  const database = process.env.NEON_DATABASE;
  const username = process.env.NEON_USERNAME;
  const password = process.env.NEON_PASSWORD;
  const port = process.env.NEON_PORT || '5432';

  if (!host || !database || !username || !password) return null;

  const userEnc = encodeURIComponent(username);
  const passEnc = encodeURIComponent(password);
  return `postgresql://${userEnc}:${passEnc}@${host}:${port}/${database}?sslmode=require`;
}

function parseArgs(argv) {
  const out = { file: null, help: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') out.help = true;
    else if (a === '--file' && argv[i + 1]) {
      out.file = argv[i + 1];
      i++;
    } else if (!a.startsWith('-') && !out.file) {
      out.file = a;
    }
  }
  return out;
}

function printHelp() {
  const defaultFile = path.join(__dirname, 'add_plan_quota_limits.sql');
  console.log('Run a SQL migration against the configured Postgres database.\n');
  console.log('Usage:');
  console.log('  node backend/migrations/run-sql.js [--file path/to/migration.sql]');
  console.log('  node backend/migrations/run-sql.js path/to/migration.sql\n');
  console.log('Default file:');
  console.log(`  ${defaultFile}\n`);
  console.log('Database config (choose one):');
  console.log('  1) Set DATABASE_URL in your environment or .env');
  console.log('  2) Set NEON_HOST, NEON_DATABASE, NEON_USERNAME, NEON_PASSWORD (NEON_PORT optional)\n');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printHelp();
    process.exit(0);
  }

  const envPath = loadEnv();
  if (envPath) console.log(`[env] loaded from ${envPath}`);

  const migrationPath = path.resolve(
    process.cwd(),
    args.file || path.join(__dirname, 'add_plan_quota_limits.sql')
  );

  if (!fs.existsSync(migrationPath)) {
    console.error(`[error] migration file not found: ${migrationPath}`);
    process.exit(1);
  }

  const connectionString =
    process.env.DATABASE_URL || buildConnectionStringFromNeonEnv();

  if (!connectionString) {
    console.error('[error] Missing DATABASE_URL (or NEON_* variables).');
    console.error('Run with --help for setup details.');
    process.exit(1);
  }

  const shouldUseSsl =
    /sslmode=require/i.test(connectionString) ||
    /neon\.tech/i.test(connectionString) ||
    Boolean(process.env.NEON_HOST);

  const pool = new Pool({
    connectionString,
    ...(shouldUseSsl ? { ssl: { rejectUnauthorized: false } } : {}),
  });

  try {
    const sql = fs.readFileSync(migrationPath, 'utf8');
    console.log(`[db] applying ${migrationPath}`);
    await pool.query({ text: sql, query_mode: 'simple' });

    // Lightweight verification for this project's most common migrations.
    if (path.basename(migrationPath) === 'add_plan_quota_limits.sql') {
      const verify = await pool.query(
        `
          SELECT column_name
          FROM information_schema.columns
          WHERE table_name = 'subscription_plans'
            AND column_name IN ('notes_limit','mcp_sources_limit','mcp_tokens_limit','mcp_api_calls_per_day')
          ORDER BY column_name;
        `
      );
      console.log(
        `[verify] subscription_plans columns present: ${verify.rows
          .map(r => r.column_name)
          .join(', ')}`
      );
    }

    console.log('[ok] migration applied');
  } catch (err) {
    const msg = err && typeof err === 'object' && 'message' in err ? err.message : String(err);
    console.error('[error] migration failed:', msg);
    process.exitCode = 1;
  } finally {
    await pool.end().catch(() => {});
  }
}

main().catch((err) => {
  console.error('[error] unexpected failure:', err?.message || err);
  process.exit(1);
});

