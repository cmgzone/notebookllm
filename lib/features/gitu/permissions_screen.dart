import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';
import 'models/gitu_permission.dart';
import 'models/gitu_permission_request.dart';
import 'services/gitu_permissions_service.dart';

class GituPermissionsScreen extends ConsumerStatefulWidget {
  const GituPermissionsScreen({super.key});

  @override
  ConsumerState<GituPermissionsScreen> createState() => _GituPermissionsScreenState();
}

class _GituPermissionsScreenState extends ConsumerState<GituPermissionsScreen> {
  bool _loading = false;

  List<GituPermission> _permissions = const [];
  List<GituPermissionRequest> _requests = const [];

  String? _resourceFilter;
  bool _includeRevoked = false;
  String? _requestStatusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(gituPermissionsServiceProvider);
      final results = await Future.wait([
        svc.listPermissions(),
        svc.listRequests(status: _requestStatusFilter),
      ]);
      if (!mounted) return;
      setState(() {
        _permissions = results[0] as List<GituPermission>;
        _requests = results[1] as List<GituPermissionRequest>;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to load permissions: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadPermissions() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(gituPermissionsServiceProvider);
      final permissions = await svc.listPermissions(resource: _resourceFilter);
      if (!mounted) return;
      setState(() => _permissions = permissions);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to load permissions: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadRequests() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(gituPermissionsServiceProvider);
      final requests = await svc.listRequests(status: _requestStatusFilter);
      if (!mounted) return;
      setState(() => _requests = requests);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to load requests: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmRevoke(GituPermission permission) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke permission?'),
        content: Text('This will revoke access to "${permission.resource}" for the selected scope.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Revoke')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await ref.read(gituPermissionsServiceProvider).revokePermission(permission.id);
      if (!mounted) return;
      await _reloadPermissions();
      _showInfo('Permission revoked');
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to revoke permission: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveRequest(GituPermissionRequest request) async {
    final expiresInDays = await _pickExpiryDays();
    if (expiresInDays == null) return;
    setState(() => _loading = true);
    try {
      final granted = await ref.read(gituPermissionsServiceProvider).approveRequest(request.id, expiresInDays: expiresInDays);
      if (!mounted) return;
      await Future.wait([_reloadRequests(), _reloadPermissions()]);
      _showInfo('Approved ${granted.resource} permission');
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to approve request: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _denyRequest(GituPermissionRequest request) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny request?'),
        content: Text('This will deny the request for "${request.permission.resource}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deny')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await ref.read(gituPermissionsServiceProvider).denyRequest(request.id);
      if (!mounted) return;
      await _reloadRequests();
      _showInfo('Request denied');
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to deny request: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<int?> _pickExpiryDays() async {
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('7 days'),
              onTap: () => Navigator.pop(context, 7),
            ),
            ListTile(
              title: const Text('30 days'),
              onTap: () => Navigator.pop(context, 30),
            ),
            ListTile(
              title: const Text('90 days'),
              onTap: () => Navigator.pop(context, 90),
            ),
            ListTile(
              title: const Text('365 days'),
              onTap: () => Navigator.pop(context, 365),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  List<String> _parseList(String raw) {
    return raw
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _openManualGrant() async {
    final resources = const ['gmail', 'shopify', 'files', 'notebooks', 'vps', 'shell', 'github', 'calendar', 'slack', 'custom'];
    String resource = 'shell';
    final actions = <String>{'execute'};
    int expiresInDays = 30;

    final allowedPathsCtrl = TextEditingController();
    final allowedCommandsCtrl = TextEditingController();
    final notebookIdsCtrl = TextEditingController();
    final emailLabelsCtrl = TextEditingController();
    final vpsConfigIdsCtrl = TextEditingController();
    final customScopeCtrl = TextEditingController();

    Future<void> submit(StateSetter setSheetState) async {
      if (_loading) return;
      if (actions.isEmpty) {
        _showError('Select at least one action');
        return;
      }
      setState(() => _loading = true);
      setSheetState(() {});
      try {
        final scope = <String, dynamic>{};
        final allowedPaths = _parseList(allowedPathsCtrl.text);
        final allowedCommands = _parseList(allowedCommandsCtrl.text);
        final notebookIds = _parseList(notebookIdsCtrl.text);
        final emailLabels = _parseList(emailLabelsCtrl.text);
        final vpsConfigIds = _parseList(vpsConfigIdsCtrl.text);
        final customScopeRaw = customScopeCtrl.text.trim();

        if (allowedPaths.isNotEmpty) scope['allowedPaths'] = allowedPaths;
        if (allowedCommands.isNotEmpty) scope['allowedCommands'] = allowedCommands;
        if (notebookIds.isNotEmpty) scope['notebookIds'] = notebookIds;
        if (emailLabels.isNotEmpty) scope['emailLabels'] = emailLabels;
        if (vpsConfigIds.isNotEmpty) scope['vpsConfigIds'] = vpsConfigIds;

        if (customScopeRaw.isNotEmpty) {
          final parsed = jsonDecode(customScopeRaw);
          if (parsed is! Map) throw Exception('customScope must be a JSON object');
          scope['customScope'] = parsed;
        }

        final granted = await ref.read(gituPermissionsServiceProvider).grantPermission(
              resource: resource,
              actions: actions.toList()..sort(),
              scope: scope.isEmpty ? null : scope,
              expiresInDays: expiresInDays,
            );

        if (!mounted) return;
        await _reloadPermissions();
        _showInfo('Granted ${granted.resource} permission');
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        _showError('Failed to grant permission: $e');
      } finally {
        if (mounted) setState(() => _loading = false);
        setSheetState(() {});
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Grant Permission', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: resource,
                      decoration: const InputDecoration(labelText: 'Resource', border: OutlineInputBorder(), isDense: true),
                      items: resources.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: _loading
                          ? null
                          : (val) {
                              if (val == null) return;
                              setSheetState(() => resource = val);
                            },
                    ),
                    const SizedBox(height: 12),
                    _buildActionsPicker(actions, setSheetState),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: expiresInDays,
                      decoration: const InputDecoration(labelText: 'Expires in', border: OutlineInputBorder(), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('7 days')),
                        DropdownMenuItem(value: 30, child: Text('30 days')),
                        DropdownMenuItem(value: 90, child: Text('90 days')),
                        DropdownMenuItem(value: 365, child: Text('365 days')),
                      ],
                      onChanged: _loading ? null : (val) => setSheetState(() => expiresInDays = val ?? 30),
                    ),
                    const SizedBox(height: 16),
                    Text('Scope (optional)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: allowedPathsCtrl,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'Allowed paths (comma or newline)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: allowedCommandsCtrl,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'Allowed commands (comma or newline)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notebookIdsCtrl,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'Notebook IDs (comma or newline)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailLabelsCtrl,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'Email labels (comma or newline)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: vpsConfigIdsCtrl,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'VPS config IDs (comma or newline)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: customScopeCtrl,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'Custom scope JSON (object)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    if (_loading) const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : () => submit(setSheetState),
                      child: const Text('Grant'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionsPicker(Set<String> actions, StateSetter setSheetState) {
    Widget checkbox(String action) {
      return CheckboxListTile(
        value: actions.contains(action),
        onChanged: _loading
            ? null
            : (val) {
                setSheetState(() {
                  if (val == true) {
                    actions.add(action);
                  } else {
                    actions.remove(action);
                  }
                });
              },
        title: Text(action),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: Theme.of(context).textTheme.titleMedium),
            checkbox('read'),
            checkbox('write'),
            checkbox('execute'),
            checkbox('delete'),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final resources = _permissions.map((p) => p.resource).where((r) => r.trim().isNotEmpty).toSet().toList()..sort();
    final visiblePermissions = _permissions.where((p) {
      if (!_includeRevoked && p.revokedAt != null) return false;
      if (_resourceFilter != null && _resourceFilter!.isNotEmpty && p.resource != _resourceFilter) return false;
      return true;
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.premiumGradient)),
          title: const Text('Permissions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              onPressed: _loading ? null : _openManualGrant,
              icon: const Icon(LucideIcons.plus, color: Colors.white),
              tooltip: 'Grant permission',
            ),
            IconButton(
              onPressed: _loading ? null : _loadAll,
              icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
              tooltip: 'Refresh',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Granted'),
              Tab(text: 'Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _reloadPermissions,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildGrantedFilters(resources),
                  const SizedBox(height: 12),
                  if (_loading) const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  if (visiblePermissions.isEmpty && !_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No permissions found')))
                  else
                    ...visiblePermissions.map(_buildPermissionCard),
                ],
              ),
            ),
            RefreshIndicator(
              onRefresh: _reloadRequests,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildRequestFilters(),
                  const SizedBox(height: 12),
                  if (_loading) const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  if (_requests.isEmpty && !_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No requests found')))
                  else
                    ..._requests.map(_buildRequestCard),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrantedFilters(List<String> resources) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(_resourceFilter),
                    initialValue: _resourceFilter,
                    decoration: const InputDecoration(
                      labelText: 'Resource',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All')),
                      ...resources.map((r) => DropdownMenuItem<String?>(value: r, child: Text(r))),
                    ],
                    onChanged: _loading
                        ? null
                        : (val) async {
                            setState(() => _resourceFilter = val);
                            await _reloadPermissions();
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include revoked'),
                    value: _includeRevoked,
                    onChanged: _loading ? null : (val) => setState(() => _includeRevoked = val),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String?>(
          key: ValueKey(_requestStatusFilter),
          initialValue: _requestStatusFilter,
          decoration: const InputDecoration(
            labelText: 'Status',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
            DropdownMenuItem(value: 'approved', child: Text('Approved')),
            DropdownMenuItem(value: 'denied', child: Text('Denied')),
            DropdownMenuItem(value: null, child: Text('All')),
          ],
          onChanged: _loading
              ? null
              : (val) async {
                  setState(() => _requestStatusFilter = val);
                  await _reloadRequests();
                },
        ),
      ),
    );
  }

  Widget _buildPermissionCard(GituPermission permission) {
    final df = DateFormat('y-MM-dd HH:mm');
    final expiresLabel = permission.expiresAt != null ? df.format(permission.expiresAt!.toLocal()) : 'Never';
    final grantedLabel = permission.grantedAt != null ? df.format(permission.grantedAt!.toLocal()) : '-';
    final scopeSummary = _formatScope(permission.scope);
    final active = permission.isActive;

    return Card(
      child: ListTile(
        leading: Icon(active ? LucideIcons.shieldCheck : LucideIcons.shieldOff, color: active ? Colors.green : Colors.grey),
        title: Text(permission.resource),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Actions: ${permission.actions.join(', ')}'),
            if (scopeSummary.isNotEmpty) Text('Scope: $scopeSummary'),
            Text('Granted: $grantedLabel'),
            Text('Expires: $expiresLabel'),
            if (permission.revokedAt != null) Text('Revoked: ${df.format(permission.revokedAt!.toLocal())}'),
          ],
        ),
        trailing: permission.revokedAt == null
            ? IconButton(
                icon: const Icon(LucideIcons.ban),
                tooltip: 'Revoke',
                onPressed: _loading ? null : () => _confirmRevoke(permission),
              )
            : null,
        isThreeLine: true,
      ),
    );
  }

  Widget _buildRequestCard(GituPermissionRequest req) {
    final df = DateFormat('y-MM-dd HH:mm');
    final scopeSummary = _formatScope(req.permission.scope);
    final requestedLabel = req.requestedAt != null ? df.format(req.requestedAt!.toLocal()) : '-';
    final expiresLabel = req.permission.expiresAt != null ? df.format(req.permission.expiresAt!.toLocal()) : 'Never';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(req.isPending ? LucideIcons.clock : LucideIcons.badgeCheck, color: req.isPending ? Colors.orange : Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${req.permission.resource} (${req.status})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Actions: ${req.permission.actions.join(', ')}'),
            if (scopeSummary.isNotEmpty) Text('Scope: $scopeSummary'),
            Text('Reason: ${req.reason}'),
            Text('Requested: $requestedLabel'),
            Text('Expires: $expiresLabel'),
            if (req.respondedAt != null) Text('Responded: ${df.format(req.respondedAt!.toLocal())}'),
            const SizedBox(height: 12),
            if (req.isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _denyRequest(req),
                      child: const Text('Deny'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : () => _approveRequest(req),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatScope(Map<String, dynamic>? scope) {
    if (scope == null || scope.isEmpty) return '';
    final parts = <String>[];
    final allowedPaths = scope['allowedPaths'];
    final emailLabels = scope['emailLabels'];
    final notebookIds = scope['notebookIds'];
    final vpsConfigIds = scope['vpsConfigIds'];
    final allowedCommands = scope['allowedCommands'];
    final customScope = scope['customScope'];

    if (allowedPaths is List) parts.add('paths=${allowedPaths.length}');
    if (emailLabels is List) parts.add('labels=${emailLabels.length}');
    if (notebookIds is List) parts.add('notebooks=${notebookIds.length}');
    if (vpsConfigIds is List) parts.add('vps=${vpsConfigIds.length}');
    if (allowedCommands is List) parts.add('commands=${allowedCommands.length}');
    if (customScope is Map) parts.add('custom=${customScope.length}');
    return parts.join(', ');
  }
}
