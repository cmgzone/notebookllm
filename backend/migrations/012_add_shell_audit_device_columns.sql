ALTER TABLE gitu_shell_audit_logs
  ADD COLUMN IF NOT EXISTS device_id TEXT;

ALTER TABLE gitu_shell_audit_logs
  ADD COLUMN IF NOT EXISTS device_name TEXT;

CREATE INDEX IF NOT EXISTS idx_gitu_shell_audit_device_id ON gitu_shell_audit_logs(device_id);
