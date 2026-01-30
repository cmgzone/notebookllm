-- Update plugins table for MCP support

ALTER TABLE gitu_plugin_catalog 
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'script'; -- 'script' (JS/TS) or 'mcp' (Model Context Protocol)

ALTER TABLE gitu_plugins 
ADD COLUMN IF NOT EXISTS mcp_config JSONB DEFAULT '{}'; -- Specific config for MCP (e.g. env vars, command args)
