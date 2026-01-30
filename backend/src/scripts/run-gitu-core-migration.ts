/**
 * Run Gitu Core migration
 * Creates all necessary tables for the Gitu Universal AI Assistant
 * Requirements: Task 1.1.1
 */

import pool from '../config/database.js';

async function runMigration() {
  const client = await pool.connect();
  
  try {
    console.log('🚀 Starting Gitu Core migration...\n');
    
    await client.query('BEGIN');
    
    // ============================================================================
    // USERS TABLE EXTENSIONS
    // ============================================================================
    console.log('📝 Extending users table...');
    await client.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS gitu_enabled BOOLEAN DEFAULT false;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS gitu_settings JSONB DEFAULT '{}';
    `);
    console.log('✅ Extended users table with gitu_enabled and gitu_settings');
    
    // ============================================================================
    // GITU SESSIONS
    // ============================================================================
    console.log('📝 Creating gitu_sessions table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_sessions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        platform TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        context JSONB DEFAULT '{}',
        started_at TIMESTAMPTZ DEFAULT NOW(),
        last_activity_at TIMESTAMPTZ DEFAULT NOW(),
        ended_at TIMESTAMPTZ,
        CONSTRAINT valid_session_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal')),
        CONSTRAINT valid_session_status CHECK (status IN ('active', 'paused', 'ended'))
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_sessions_user ON gitu_sessions(user_id, status);
      CREATE INDEX IF NOT EXISTS idx_gitu_sessions_activity ON gitu_sessions(last_activity_at DESC);
    `);
    console.log('✅ Created gitu_sessions table');
    
    // ============================================================================
    // GITU MEMORIES
    // ============================================================================
    console.log('📝 Creating gitu_memories table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_memories (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        category TEXT NOT NULL,
        content TEXT NOT NULL,
        source TEXT NOT NULL,
        confidence NUMERIC(3,2) DEFAULT 0.5,
        verified BOOLEAN DEFAULT false,
        last_confirmed_by_user TIMESTAMPTZ,
        verification_required BOOLEAN DEFAULT false,
        tags TEXT[] DEFAULT '{}',
        created_at TIMESTAMPTZ DEFAULT NOW(),
        last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
        access_count INTEGER DEFAULT 0,
        CONSTRAINT valid_memory_category CHECK (category IN ('personal', 'work', 'preference', 'fact', 'context')),
        CONSTRAINT valid_memory_confidence CHECK (confidence >= 0 AND confidence <= 1)
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_memories_user ON gitu_memories(user_id, category);
      CREATE INDEX IF NOT EXISTS idx_gitu_memories_verified ON gitu_memories(user_id, verified);
      CREATE INDEX IF NOT EXISTS idx_gitu_memories_tags ON gitu_memories USING GIN(tags);
    `);
    console.log('✅ Created gitu_memories table');
    
    // ============================================================================
    // MEMORY CONTRADICTIONS
    // ============================================================================
    console.log('📝 Creating gitu_memory_contradictions table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_memory_contradictions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        memory_id UUID NOT NULL REFERENCES gitu_memories(id) ON DELETE CASCADE,
        contradicts_memory_id UUID NOT NULL REFERENCES gitu_memories(id) ON DELETE CASCADE,
        detected_at TIMESTAMPTZ DEFAULT NOW(),
        resolved BOOLEAN DEFAULT false,
        resolution TEXT
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_memory_contradictions_memory ON gitu_memory_contradictions(memory_id);
      CREATE INDEX IF NOT EXISTS idx_gitu_memory_contradictions_unresolved ON gitu_memory_contradictions(resolved) WHERE resolved = false;
    `);
    console.log('✅ Created gitu_memory_contradictions table');
    
    // ============================================================================
    // SCHEDULED TASKS
    // ============================================================================
    console.log('📝 Creating gitu_scheduled_tasks and gitu_task_executions tables...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_scheduled_tasks (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        action TEXT NOT NULL,
        cron TEXT NOT NULL,
        enabled BOOLEAN DEFAULT true,
        max_retries INTEGER DEFAULT 3,
        retry_count INTEGER DEFAULT 0,
        last_run_at TIMESTAMPTZ,
        last_run_status TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_scheduled_tasks_user ON gitu_scheduled_tasks(user_id, enabled);
      CREATE TABLE IF NOT EXISTS gitu_task_executions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        task_id UUID NOT NULL REFERENCES gitu_scheduled_tasks(id) ON DELETE CASCADE,
        started_at TIMESTAMPTZ DEFAULT NOW(),
        finished_at TIMESTAMPTZ,
        status TEXT NOT NULL,
        error TEXT
      );
      
    `);
    console.log('✅ Created scheduler tables');
    
    // Ensure columns exist (handle previous versions)
    await client.query(`
      ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS action TEXT NOT NULL DEFAULT 'memories.detectContradictions';
      ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS cron TEXT NOT NULL DEFAULT '* * * * *';
      ALTER TABLE gitu_scheduled_tasks ALTER COLUMN action TYPE TEXT USING action::text;
      ALTER TABLE gitu_scheduled_tasks ALTER COLUMN cron TYPE TEXT USING cron::text;
      ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS enabled BOOLEAN DEFAULT true;
      ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS trigger TEXT NOT NULL DEFAULT 'cron';
      ALTER TABLE gitu_scheduled_tasks ALTER COLUMN trigger TYPE TEXT USING trigger::text;
      ALTER TABLE gitu_scheduled_tasks ALTER COLUMN trigger SET DEFAULT 'cron';
      ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS max_retries INTEGER DEFAULT 3;
      ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS retry_count INTEGER DEFAULT 0;
      ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS last_run_at TIMESTAMPTZ;
      ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS last_run_status TEXT;
      ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
      
      ALTER TABLE gitu_task_executions ADD COLUMN IF NOT EXISTS finished_at TIMESTAMPTZ;
      ALTER TABLE gitu_task_executions ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ DEFAULT NOW();
      ALTER TABLE gitu_task_executions ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'success';
      ALTER TABLE gitu_task_executions ADD COLUMN IF NOT EXISTS error TEXT;
      
      CREATE INDEX IF NOT EXISTS idx_gitu_scheduled_tasks_cron ON gitu_scheduled_tasks(cron);
      CREATE INDEX IF NOT EXISTS idx_gitu_task_exec_task ON gitu_task_executions(task_id, started_at);
    `);
    console.log('🔧 Ensured scheduler columns exist');
    
    // ============================================================================
    // LINKED ACCOUNTS (Identity Unification)
    // ============================================================================
    console.log('📝 Creating gitu_linked_accounts table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_linked_accounts (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        platform TEXT NOT NULL,
        platform_user_id TEXT NOT NULL,
        display_name TEXT,
        linked_at TIMESTAMPTZ DEFAULT NOW(),
        last_used_at TIMESTAMPTZ DEFAULT NOW(),
        verified BOOLEAN DEFAULT false,
        is_primary BOOLEAN DEFAULT false,
        status TEXT DEFAULT 'active',
        UNIQUE(platform, platform_user_id),
        CONSTRAINT valid_linked_account_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal'))
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_linked_accounts_user ON gitu_linked_accounts(user_id);
      CREATE INDEX IF NOT EXISTS idx_gitu_linked_accounts_platform ON gitu_linked_accounts(platform, platform_user_id);
    `);
    console.log('✅ Created gitu_linked_accounts table');

    await client.query(`
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS display_name TEXT;
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS linked_at TIMESTAMPTZ DEFAULT NOW();
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ DEFAULT NOW();
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT false;
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT false;
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
      UPDATE gitu_linked_accounts SET status = 'active' WHERE status IS NULL;
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'valid_linked_account_status'
        ) THEN
          ALTER TABLE gitu_linked_accounts
            ADD CONSTRAINT valid_linked_account_status
            CHECK (status IN ('active','inactive','suspended'));
        END IF;
      END $$;
    `);
    
    // ============================================================================
    // PERMISSIONS
    // ============================================================================
    console.log('📝 Creating gitu_permissions table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_permissions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        resource TEXT NOT NULL,
        actions TEXT[] NOT NULL,
        scope JSONB DEFAULT '{}',
        granted_at TIMESTAMPTZ DEFAULT NOW(),
        expires_at TIMESTAMPTZ,
        revoked_at TIMESTAMPTZ
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_permissions_user ON gitu_permissions(user_id, resource);
      CREATE INDEX IF NOT EXISTS idx_gitu_permissions_active ON gitu_permissions(user_id, resource) WHERE revoked_at IS NULL;
    `);
    console.log('✅ Created gitu_permissions table');
    
    // ============================================================================
    // VPS CONFIGURATIONS
    // ============================================================================
    console.log('📝 Creating gitu_vps_configs table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_vps_configs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        host TEXT NOT NULL,
        port INTEGER DEFAULT 22,
        auth_method TEXT NOT NULL,
        username TEXT NOT NULL,
        encrypted_password TEXT,
        encrypted_private_key TEXT,
        allowed_commands TEXT[] DEFAULT '{}',
        allowed_paths TEXT[] DEFAULT '{}',
        provider TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        last_used_at TIMESTAMPTZ,
        CONSTRAINT valid_vps_auth_method CHECK (auth_method IN ('password', 'ssh-key', 'ssh-agent'))
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_vps_user ON gitu_vps_configs(user_id);
    `);
    console.log('✅ Created gitu_vps_configs table');
    
    // ============================================================================
    // VPS AUDIT LOGS (Append-Only)
    // ============================================================================
    console.log('📝 Creating gitu_vps_audit_logs table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_vps_audit_logs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        vps_config_id UUID REFERENCES gitu_vps_configs(id) ON DELETE SET NULL,
        action TEXT NOT NULL,
        command TEXT,
        path TEXT,
        success BOOLEAN DEFAULT true,
        error TEXT,
        timestamp TIMESTAMPTZ DEFAULT NOW()
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_vps_audit_user ON gitu_vps_audit_logs(user_id, timestamp DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_vps_audit_config ON gitu_vps_audit_logs(vps_config_id, timestamp DESC);
    `);
    console.log('✅ Created gitu_vps_audit_logs table');

    // ============================================================================
    // SHELL AUDIT LOGS (Append-Only)
    // ============================================================================
    console.log('📝 Creating gitu_shell_audit_logs table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_shell_audit_logs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        mode TEXT NOT NULL CHECK (mode IN ('sandboxed', 'unsandboxed', 'dry_run')),
        command TEXT NOT NULL,
        args JSONB DEFAULT '[]',
        cwd TEXT,
        success BOOLEAN DEFAULT true,
        exit_code INTEGER,
        error_message TEXT,
        duration_ms INTEGER,
        stdout_bytes INTEGER DEFAULT 0,
        stderr_bytes INTEGER DEFAULT 0,
        stdout_truncated BOOLEAN DEFAULT false,
        stderr_truncated BOOLEAN DEFAULT false,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_shell_audit_user ON gitu_shell_audit_logs(user_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_shell_audit_mode ON gitu_shell_audit_logs(mode);
    `);
    console.log('✅ Created gitu_shell_audit_logs table');
    
    // ============================================================================
    // GMAIL CONNECTIONS
    // ============================================================================
    console.log('📝 Creating gitu_gmail_connections table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_gmail_connections (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        email TEXT NOT NULL,
        encrypted_access_token TEXT NOT NULL,
        encrypted_refresh_token TEXT NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        scopes TEXT[] NOT NULL,
        connected_at TIMESTAMPTZ DEFAULT NOW(),
        last_sync_at TIMESTAMPTZ,
        UNIQUE(user_id)
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_gmail_user ON gitu_gmail_connections(user_id);
    `);
    console.log('✅ Created gitu_gmail_connections table');
    
    // ============================================================================
    // SCHEDULED TASKS
    // ============================================================================
    console.log('📝 Creating gitu_scheduled_tasks table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_scheduled_tasks (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        description TEXT,
        trigger JSONB NOT NULL,
        action JSONB NOT NULL,
        enabled BOOLEAN DEFAULT true,
        last_run_at TIMESTAMPTZ,
        next_run_at TIMESTAMPTZ,
        run_count INTEGER DEFAULT 0,
        failure_count INTEGER DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_scheduled_tasks_user ON gitu_scheduled_tasks(user_id, enabled);
      CREATE INDEX IF NOT EXISTS idx_gitu_scheduled_tasks_next_run ON gitu_scheduled_tasks(next_run_at) WHERE enabled = true;
    `);
    console.log('✅ Created gitu_scheduled_tasks table');
    
    // ============================================================================
    // TASK EXECUTION HISTORY
    // ============================================================================
    console.log('📝 Creating gitu_task_executions table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_task_executions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        task_id UUID NOT NULL REFERENCES gitu_scheduled_tasks(id) ON DELETE CASCADE,
        success BOOLEAN NOT NULL,
        output JSONB,
        error TEXT,
        duration INTEGER,
        executed_at TIMESTAMPTZ DEFAULT NOW()
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_task_executions_task ON gitu_task_executions(task_id, executed_at DESC);
    `);
    console.log('✅ Created gitu_task_executions table');
    
    // ============================================================================
    // USAGE TRACKING
    // ============================================================================
    console.log('📝 Creating gitu_usage_records table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_usage_records (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        operation TEXT NOT NULL,
        model TEXT,
        tokens_used INTEGER DEFAULT 0,
        cost_usd NUMERIC(10,6) DEFAULT 0,
        platform TEXT NOT NULL,
        timestamp TIMESTAMPTZ DEFAULT NOW()
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_usage_user_time ON gitu_usage_records(user_id, timestamp DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_usage_user_cost ON gitu_usage_records(user_id, cost_usd DESC);
    `);
    console.log('✅ Created gitu_usage_records table');
    
    // ============================================================================
    // USAGE LIMITS
    // ============================================================================
    console.log('📝 Creating gitu_usage_limits table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_usage_limits (
        user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        daily_limit_usd NUMERIC(10,2) DEFAULT 10.00,
        per_task_limit_usd NUMERIC(10,2) DEFAULT 1.00,
        monthly_limit_usd NUMERIC(10,2) DEFAULT 100.00,
        hard_stop BOOLEAN DEFAULT true,
        alert_thresholds NUMERIC[] DEFAULT '{0.5, 0.75, 0.9}',
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('✅ Created gitu_usage_limits table');
    
    // ============================================================================
    // AUTOMATION RULES
    // ============================================================================
    console.log('📝 Creating gitu_automation_rules table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_automation_rules (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        description TEXT,
        trigger JSONB NOT NULL,
        conditions JSONB DEFAULT '[]',
        actions JSONB NOT NULL,
        enabled BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_automation_user ON gitu_automation_rules(user_id, enabled);
    `);
    console.log('✅ Created gitu_automation_rules table');

    // ============================================================================
    // RULE EXECUTION HISTORY
    // ============================================================================
    console.log('📝 Creating gitu_rule_executions table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_rule_executions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        rule_id UUID NOT NULL REFERENCES gitu_automation_rules(id) ON DELETE CASCADE,
        matched BOOLEAN NOT NULL,
        success BOOLEAN NOT NULL,
        result JSONB,
        error TEXT,
        executed_at TIMESTAMPTZ DEFAULT NOW()
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_rule_exec_user_time ON gitu_rule_executions(user_id, executed_at DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_rule_exec_rule_time ON gitu_rule_executions(rule_id, executed_at DESC);
    `);
    console.log('✅ Created gitu_rule_executions table');

    // ============================================================================
    // PLUGINS
    // ============================================================================
    console.log('📝 Creating gitu_plugins table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_plugins (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        description TEXT,
        code TEXT NOT NULL,
        entrypoint TEXT DEFAULT 'run',
        config JSONB DEFAULT '{}',
        source_catalog_id UUID,
        source_catalog_version TEXT,
        enabled BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_plugins_user ON gitu_plugins(user_id, updated_at DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_plugins_enabled ON gitu_plugins(user_id, enabled);
    `);
    console.log('✅ Created gitu_plugins table');

    console.log('📝 Creating gitu_plugin_catalog table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_plugin_catalog (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        slug TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        description TEXT,
        code TEXT NOT NULL,
        entrypoint TEXT DEFAULT 'run',
        version TEXT DEFAULT '1.0.0',
        author TEXT,
        tags JSONB DEFAULT '[]',
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_gitu_plugin_catalog_active ON gitu_plugin_catalog(is_active, updated_at DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_plugin_catalog_updated ON gitu_plugin_catalog(updated_at DESC);
    `);
    console.log('✅ Created gitu_plugin_catalog table');

    console.log('📝 Creating gitu_plugin_executions table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_plugin_executions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        plugin_id UUID NOT NULL REFERENCES gitu_plugins(id) ON DELETE CASCADE,
        success BOOLEAN NOT NULL,
        duration_ms INTEGER DEFAULT 0,
        result JSONB,
        error TEXT,
        logs JSONB DEFAULT '[]',
        executed_at TIMESTAMPTZ DEFAULT NOW()
      );
      
      CREATE INDEX IF NOT EXISTS idx_gitu_plugin_exec_user_time ON gitu_plugin_executions(user_id, executed_at DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_plugin_exec_plugin_time ON gitu_plugin_executions(plugin_id, executed_at DESC);
    `);
    console.log('✅ Created gitu_plugin_executions table');
    
    await client.query('COMMIT');
    
    console.log('\n✅ Gitu Core migration completed successfully!\n');
    
    // Verify tables were created
    console.log('🔍 Verifying tables...');
    const result = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name LIKE 'gitu_%'
      ORDER BY table_name;
    `);

    console.log(`\n✓ Found ${result.rows.length} Gitu tables:`);
    result.rows.forEach((row: any) => {
      console.log(`   ✓ ${row.table_name}`);
    });

    // Check users table extensions
    console.log('\n🔍 Verifying users table extensions...');
    const columnsResult = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = 'users'
      AND column_name IN ('gitu_enabled', 'gitu_settings')
      ORDER BY column_name;
    `);

    if (columnsResult.rows.length === 2) {
      console.log('✓ Users table extended successfully:');
      columnsResult.rows.forEach((row: any) => {
        console.log(`   ✓ ${row.column_name} (${row.data_type})`);
      });
    } else {
      console.warn('⚠️  Warning: Users table extensions may not be complete');
    }

    console.log('\n🎉 Migration verification complete!');
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n❌ Migration failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch(console.error);
