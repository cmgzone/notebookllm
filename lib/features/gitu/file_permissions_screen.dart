import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_theme.dart';
import 'models/file_audit_log.dart';
import 'models/file_permissions_status.dart';
import 'services/file_permissions_service.dart';

class GituFilePermissionsScreen extends ConsumerStatefulWidget {
  const GituFilePermissionsScreen({super.key});

  @override
  ConsumerState<GituFilePermissionsScreen> createState() => _GituFilePermissionsScreenState();
}

class _GituFilePermissionsScreenState extends ConsumerState<GituFilePermissionsScreen> {
  FilePermissionsStatus? _status;
  List<FileAuditLog> _logs = const [];

  bool _loadingStatus = false;
  bool _loadingLogs = false;

  String? _actionFilter;
  bool? _successFilter;
  final TextEditingController _pathPrefixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _pathPrefixController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadStatus(),
      _loadLogs(),
    ]);
  }

  Future<void> _loadStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final status = await ref.read(filePermissionsServiceProvider).getStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to load file permissions: $e');
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _loadingLogs = true);
    try {
      final logs = await ref.read(filePermissionsServiceProvider).listAuditLogs(
            limit: 50,
            action: _actionFilter,
            success: _successFilter,
            pathPrefix: _pathPrefixController.text,
          );
      if (!mounted) return;
      setState(() => _logs = logs);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to load file operation logs: $e');
    } finally {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  Future<void> _saveAllowedPaths(List<String> allowedPaths) async {
    setState(() => _loadingStatus = true);
    try {
      final updated = await ref.read(filePermissionsServiceProvider).updateAllowedPaths(allowedPaths);
      if (!mounted) return;
      setState(() => _status = updated);
      await _loadLogs();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to update allowed paths: $e');
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _confirmRevoke() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke file access?'),
        content: const Text('This will revoke all file permissions and block future file operations.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Revoke')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loadingStatus = true);
    try {
      await ref.read(filePermissionsServiceProvider).revoke();
      if (!mounted) return;
      await _loadAll();
      _showInfo('File access revoked');
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to revoke file access: $e');
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _showAddPathDialog() async {
    final controller = TextEditingController();
    final added = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add allowed path'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. tmp/my-folder',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    final path = added?.trim();
    if (path == null || path.isEmpty) return;

    final current = _status?.allowedPaths ?? const [];
    final next = [...current];
    if (!next.contains(path)) next.add(path);
    await _saveAllowedPaths(next);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final allowed = status?.allowedPaths ?? const [];

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.premiumGradient)),
        title: const Text('File Permissions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loadingStatus || _loadingLogs ? null : _loadAll,
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(status),
            const SizedBox(height: 16),
            _buildAllowedPathsCard(allowed),
            const SizedBox(height: 16),
            _buildLogsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(FilePermissionsStatus? status) {
    final active = status?.active ?? false;
    final actions = status?.actions ?? const [];
    final expiresAt = status?.expiresAt;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(active ? LucideIcons.shieldCheck : LucideIcons.shieldOff, color: active ? Colors.green : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(active ? 'File access enabled' : 'File access disabled', style: textTheme.titleMedium),
                  const SizedBox(height: 6),
                  if (_loadingStatus) const LinearProgressIndicator(minHeight: 2),
                  if (!_loadingStatus)
                    Text(
                      active
                          ? 'Allowed actions: ${actions.isEmpty ? '—' : actions.join(', ')}'
                          : 'Grant access by adding allowed paths below.',
                      style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                    ),
                  if (expiresAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Expires: ${DateFormat.yMMMd().add_jm().format(expiresAt.toLocal())}',
                      style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: active && !_loadingStatus ? _confirmRevoke : null,
                      icon: const Icon(LucideIcons.ban, size: 18),
                      label: const Text('Revoke Access'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllowedPathsCard(List<String> allowed) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.folder, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Allowed Paths',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadingStatus ? null : _showAddPathDialog,
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (allowed.isEmpty)
              Text(
                'No allowed paths yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              )
            else
              Column(
                children: [
                  for (final p in allowed)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.folderOpen, size: 18),
                      title: Text(p, style: const TextStyle(fontFamily: 'monospace')),
                      trailing: IconButton(
                        onPressed: _loadingStatus
                            ? null
                            : () async {
                                final next = allowed.where((x) => x != p).toList();
                                await _saveAllowedPaths(next);
                              },
                        icon: const Icon(LucideIcons.trash2, size: 18),
                        tooltip: 'Remove',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsCard() {
    final logs = _logs;
    final loading = _loadingLogs;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.list, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Operation Logs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: loading ? null : _loadLogs,
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  tooltip: 'Refresh logs',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLogFilters(),
            const SizedBox(height: 12),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (!loading && logs.isEmpty)
              Text(
                'No logs yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              )
            else
              Column(
                children: logs.take(50).map(_buildLogRow).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogFilters() {
    final canApply = !_loadingLogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All actions'),
              selected: _actionFilter == null,
              onSelected: canApply
                  ? (_) {
                      setState(() => _actionFilter = null);
                      _loadLogs();
                    }
                  : null,
            ),
            for (final action in const ['list', 'read', 'write'])
              FilterChip(
                label: Text(action),
                selected: _actionFilter == action,
                onSelected: canApply
                    ? (_) {
                        setState(() => _actionFilter = action);
                        _loadLogs();
                      }
                    : null,
              ),
            FilterChip(
              label: const Text('All results'),
              selected: _successFilter == null,
              onSelected: canApply
                  ? (_) {
                      setState(() => _successFilter = null);
                      _loadLogs();
                    }
                  : null,
            ),
            FilterChip(
              label: const Text('Success'),
              selected: _successFilter == true,
              onSelected: canApply
                  ? (_) {
                      setState(() => _successFilter = true);
                      _loadLogs();
                    }
                  : null,
            ),
            FilterChip(
              label: const Text('Failed'),
              selected: _successFilter == false,
              onSelected: canApply
                  ? (_) {
                      setState(() => _successFilter = false);
                      _loadLogs();
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pathPrefixController,
          decoration: InputDecoration(
            labelText: 'Path prefix',
            hintText: 'e.g. tmp/',
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: canApply
                  ? () {
                      _pathPrefixController.clear();
                      _loadLogs();
                    }
                  : null,
              icon: const Icon(LucideIcons.x, size: 18),
              tooltip: 'Clear',
            ),
          ),
          onSubmitted: (_) => _loadLogs(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: canApply ? _loadLogs : null,
            icon: const Icon(LucideIcons.filter, size: 18),
            label: const Text('Apply'),
          ),
        ),
      ],
    );
  }

  Widget _buildLogRow(FileAuditLog log) {
    final created = DateFormat.yMMMd().add_jm().format(log.createdAt.toLocal());
    final icon = log.success ? LucideIcons.checkCircle2 : LucideIcons.xCircle;
    final color = log.success ? Colors.green : Colors.red;
    final subtitle = log.success ? created : '$created • ${log.errorMessage ?? 'Error'}';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 18),
      title: Text('${log.action} • ${log.path}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

