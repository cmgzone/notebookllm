-- Fix GitHub audit log action constraint
-- Expands allowed `github_audit_logs.action` values to match the backend code.
-- Safe to run multiple times.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'github_audit_logs'
  ) THEN
    ALTER TABLE public.github_audit_logs
      DROP CONSTRAINT IF EXISTS github_audit_logs_action_check;

    ALTER TABLE public.github_audit_logs
      ADD CONSTRAINT github_audit_logs_action_check
      CHECK (action IN (
        'list_repos',
        'get_file',
        'search',
        'create_issue',
        'add_source',
        'add_repo_sources',
        'import_repo_notebook',
        'analyze_repo',
        'get_tree',
        'github_disconnect',
        'refresh_source',
        'check_updates',
        'reanalyze_source'
      ));
  END IF;
END $$;

SELECT 'github_audit_logs action constraint updated' AS status;

