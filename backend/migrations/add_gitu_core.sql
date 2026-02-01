-- Gitu Core Database Schema Migration
-- This migration creates all necessary tables for the Gitu Universal AI Assistant

-- ============================================================================
-- USERS TABLE EXTENSIONS
-- ============================================================================

-- Add Gitu-specific columns to existing users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS gitu_enabled BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS gitu_settings JSONB DEFAULT '{}';

-- ============================================================================
-- GITU SESSIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  status TEXT DEFAULT 'active',
  context JSONB DEFAULT '{}',
  started_at TIMESTAMPTZ DEFAULT NOW(),
  last_activity_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  CONSTRAINT valid_session_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web')),
  CONSTRAINT valid_session_status CHECK (status IN ('active', 'paused', 'ended'))
);

CREATE INDEX IF NOT EXISTS idx_gitu_sessions_user ON gitu_sessions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_gitu_sessions_activity ON gitu_sessions(last_activity_at DESC);

-- ============================================================================
-- GITU MESSAGES (Message Gateway)
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  platform_user_id TEXT,
  content JSONB NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}',
  CONSTRAINT valid_message_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web'))
);

CREATE INDEX IF NOT EXISTS idx_gitu_messages_user ON gitu_messages(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_gitu_messages_platform ON gitu_messages(user_id, platform, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_gitu_messages_timestamp ON gitu_messages(timestamp DESC);

-- ============================================================================
-- GITU MEMORIES
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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

-- ============================================================================
-- MEMORY CONTRADICTIONS
-- ============================================================================

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

-- ============================================================================
-- LINKED ACCOUNTS (Identity Unification)
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_linked_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  platform_user_id TEXT NOT NULL,
  display_name TEXT,
  linked_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ DEFAULT NOW(),
  verified BOOLEAN DEFAULT false,
  is_primary BOOLEAN DEFAULT false,
  UNIQUE(platform, platform_user_id),
  status TEXT DEFAULT 'active',
  CONSTRAINT valid_linked_account_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web')),
  CONSTRAINT valid_linked_account_status CHECK (status IN ('active', 'inactive', 'suspended'))
);

CREATE INDEX IF NOT EXISTS idx_gitu_linked_accounts_user ON gitu_linked_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_gitu_linked_accounts_platform ON gitu_linked_accounts(platform, platform_user_id);

-- ============================================================================
-- PERMISSIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  resource TEXT NOT NULL,
  actions TEXT[] NOT NULL,
  scope JSONB DEFAULT '{}',
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_gitu_permissions_user ON gitu_permissions(user_id, resource);
CREATE INDEX IF NOT EXISTS idx_gitu_permissions_active ON gitu_permissions(user_id, resource) WHERE revoked_at IS NULL;

-- ============================================================================
-- VPS CONFIGURATIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_vps_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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

-- ============================================================================
-- VPS AUDIT LOGS (Append-Only)
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_vps_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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

-- ============================================================================
-- SHELL AUDIT LOGS (Append-Only)
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_shell_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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

-- ============================================================================
-- GMAIL CONNECTIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_gmail_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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

-- ============================================================================
-- SCHEDULED TASKS
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_scheduled_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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

-- ============================================================================
-- TASK EXECUTION HISTORY
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_task_executions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES gitu_scheduled_tasks(id) ON DELETE CASCADE,
  success BOOLEAN NOT NULL,
  output JSONB,
  error TEXT,
  duration INTEGER,  -- milliseconds
  executed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gitu_task_executions_task ON gitu_task_executions(task_id, executed_at DESC);

-- ============================================================================
-- USAGE TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_usage_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  operation TEXT NOT NULL,
  model TEXT,
  tokens_used INTEGER DEFAULT 0,
  cost_usd NUMERIC(10,6) DEFAULT 0,
  platform TEXT NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gitu_usage_user_time ON gitu_usage_records(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_gitu_usage_user_cost ON gitu_usage_records(user_id, cost_usd DESC);

-- ============================================================================
-- USAGE LIMITS
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_usage_limits (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  daily_limit_usd NUMERIC(10,2) DEFAULT 10.00,
  per_task_limit_usd NUMERIC(10,2) DEFAULT 1.00,
  monthly_limit_usd NUMERIC(10,2) DEFAULT 100.00,
  hard_stop BOOLEAN DEFAULT true,
  alert_thresholds NUMERIC[] DEFAULT '{0.5, 0.75, 0.9}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- AUTOMATION RULES
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_automation_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  trigger JSONB NOT NULL,
  conditions JSONB DEFAULT '[]',
  actions JSONB NOT NULL,
  enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gitu_automation_user ON gitu_automation_rules(user_id, enabled);

-- ============================================================================
-- RULE EXECUTION HISTORY
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_rule_executions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rule_id UUID NOT NULL REFERENCES gitu_automation_rules(id) ON DELETE CASCADE,
  matched BOOLEAN NOT NULL,
  success BOOLEAN NOT NULL,
  result JSONB,
  error TEXT,
  executed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gitu_rule_exec_user_time ON gitu_rule_executions(user_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_gitu_rule_exec_rule_time ON gitu_rule_executions(rule_id, executed_at DESC);

-- ============================================================================
-- PLUGINS
-- ============================================================================

CREATE TABLE IF NOT EXISTS gitu_plugins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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

CREATE TABLE IF NOT EXISTS gitu_plugin_executions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE gitu_sessions IS 'Persistent sessions across platforms and conversations';
COMMENT ON TABLE gitu_messages IS 'Message history and audit trail for all platforms';
COMMENT ON TABLE gitu_memories IS 'User-specific information for personalization with confidence tracking';
COMMENT ON TABLE gitu_memory_contradictions IS 'Tracks contradicting memories for resolution';
COMMENT ON TABLE gitu_linked_accounts IS 'Identity unification across multiple platforms';
COMMENT ON TABLE gitu_permissions IS 'Granular access control for integrations and resources';
COMMENT ON TABLE gitu_vps_configs IS 'VPS server configurations with encrypted credentials';
COMMENT ON TABLE gitu_vps_audit_logs IS 'Immutable audit trail for all VPS operations';
COMMENT ON TABLE gitu_gmail_connections IS 'Gmail OAuth connections with encrypted tokens';
COMMENT ON TABLE gitu_scheduled_tasks IS 'Background tasks with cron-like scheduling';
COMMENT ON TABLE gitu_task_executions IS 'Execution history for scheduled tasks';
COMMENT ON TABLE gitu_usage_records IS 'AI model usage and cost tracking';
COMMENT ON TABLE gitu_usage_limits IS 'Budget limits and alert thresholds per user';
COMMENT ON TABLE gitu_automation_rules IS 'User-defined automation rules (IF-THEN logic)';
COMMENT ON TABLE gitu_rule_executions IS 'Execution history for automation rules';
COMMENT ON TABLE gitu_plugins IS 'User-defined sandboxed plugins';
COMMENT ON TABLE gitu_plugin_catalog IS 'Marketplace catalog of plugins';
COMMENT ON TABLE gitu_plugin_executions IS 'Execution history for plugins';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Log migration completion
DO $$
BEGIN
  RAISE NOTICE 'Gitu Core migration completed successfully';
  RAISE NOTICE 'Created tables: gitu_sessions, gitu_messages, gitu_memories, gitu_memory_contradictions, gitu_linked_accounts';
  RAISE NOTICE 'Created tables: gitu_permissions, gitu_vps_configs, gitu_vps_audit_logs, gitu_gmail_connections';
  RAISE NOTICE 'Created tables: gitu_scheduled_tasks, gitu_task_executions, gitu_usage_records, gitu_usage_limits';
  RAISE NOTICE 'Created tables: gitu_automation_rules, gitu_rule_executions';
  RAISE NOTICE 'Created tables: gitu_plugins, gitu_plugin_executions';
  RAISE NOTICE 'Extended users table with gitu_enabled and gitu_settings columns';
END $$;
