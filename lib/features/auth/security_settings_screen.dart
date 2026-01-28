import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/custom_auth_service.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  List<AuthSession>? _sessions;
  List<AuditLogEntry>? _auditLogs;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = ref.read(legacyUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(customAuthServiceProvider);
      final sessions = await authService.getActiveSessions(user.uid);
      final logs = await authService.getAuditLogs(user.uid, limit: 20);

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _auditLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(legacyUserProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAccountSection(theme, user),
                  const SizedBox(height: 24),
                  _buildTwoFactorSection(theme, user),
                  const SizedBox(height: 24),
                  _buildSessionsSection(theme),
                  const SizedBox(height: 24),
                  _buildPasswordSection(theme),
                  const SizedBox(height: 24),
                  _buildAuditLogSection(theme),
                  const SizedBox(height: 24),
                  _buildDangerZone(theme, user),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor ?? theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(ThemeData theme, AppUser user) {
    return _buildSectionCard(
      title: 'Account',
      icon: Icons.person_outline,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              (user.displayName ?? user.email)[0].toUpperCase(),
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
          title: Text(user.displayName ?? 'No name set'),
          subtitle: Text(user.email),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatusChip(
              label:
                  user.emailVerified ? 'Email Verified' : 'Email Not Verified',
              icon: user.emailVerified ? Icons.verified : Icons.warning_amber,
              color: user.emailVerified ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              label: user.twoFactorEnabled ? '2FA Enabled' : '2FA Disabled',
              icon: user.twoFactorEnabled
                  ? Icons.security
                  : Icons.shield_outlined,
              color: user.twoFactorEnabled ? Colors.green : Colors.grey,
            ),
          ],
        ),
        if (!user.emailVerified) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _resendVerificationEmail(user.uid),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Resend Verification Email'),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip(
      {required String label, required IconData icon, required Color color}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildTwoFactorSection(ThemeData theme, AppUser user) {
    return _buildSectionCard(
      title: 'Two-Factor Authentication',
      icon: Icons.security,
      children: [
        Text(
          user.twoFactorEnabled
              ? 'Two-factor authentication adds an extra layer of security to your account.'
              : 'Enable two-factor authentication for enhanced security.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable 2FA'),
          subtitle: Text(user.twoFactorEnabled
              ? 'Currently enabled'
              : 'Currently disabled'),
          value: user.twoFactorEnabled,
          onChanged: (value) =>
              value ? _enableTwoFactor(user.uid) : _disableTwoFactor(user.uid),
        ),
      ],
    );
  }

  Widget _buildSessionsSection(ThemeData theme) {
    return _buildSectionCard(
      title: 'Active Sessions',
      icon: Icons.devices,
      children: [
        if (_sessions == null || _sessions!.isEmpty)
          const Text('No active sessions')
        else ...[
          ..._sessions!.map((session) => _buildSessionTile(theme, session)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _revokeAllOtherSessions,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out All Other Devices'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          ),
        ],
      ],
    );
  }

  Widget _buildSessionTile(ThemeData theme, AuthSession session) {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        _getDeviceIcon(session.deviceInfo),
        color: session.isCurrent ? theme.colorScheme.primary : Colors.grey,
      ),
      title: Row(
        children: [
          Expanded(
              child: Text(session.deviceInfo, overflow: TextOverflow.ellipsis)),
          if (session.isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Current',
                style:
                    TextStyle(fontSize: 10, color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
      subtitle: Text('Last active: ${dateFormat.format(session.lastActiveAt)}'),
      trailing: session.isCurrent
          ? null
          : IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _revokeSession(session.sessionId),
            ),
    );
  }

  IconData _getDeviceIcon(String deviceInfo) {
    final lower = deviceInfo.toLowerCase();
    if (lower.contains('iphone') || lower.contains('ios')) {
      return Icons.phone_iphone;
    }
    if (lower.contains('android')) {
      return Icons.phone_android;
    }
    if (lower.contains('mac') ||
        lower.contains('windows') ||
        lower.contains('linux')) {
      return Icons.computer;
    }
    if (lower.contains('web')) {
      return Icons.web;
    }
    return Icons.devices;
  }

  Widget _buildPasswordSection(ThemeData theme) {
    return _buildSectionCard(
      title: 'Password',
      icon: Icons.lock_outline,
      children: [
        Text(
          'Change your password regularly to keep your account secure.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _showChangePasswordDialog,
          icon: const Icon(Icons.key),
          label: const Text('Change Password'),
        ),
      ],
    );
  }

  Widget _buildAuditLogSection(ThemeData theme) {
    return _buildSectionCard(
      title: 'Recent Activity',
      icon: Icons.history,
      children: [
        if (_auditLogs == null || _auditLogs!.isEmpty)
          const Text('No recent activity')
        else
          ..._auditLogs!.take(5).map((log) => _buildAuditLogTile(theme, log)),
        if (_auditLogs != null && _auditLogs!.length > 5) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _showFullAuditLog,
            child: const Text('View All Activity'),
          ),
        ],
      ],
    );
  }

  Widget _buildAuditLogTile(ThemeData theme, AuditLogEntry log) {
    final dateFormat = DateFormat('MMM d, HH:mm');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_getAuditIcon(log.action),
              size: 20, color: _getAuditColor(log.action)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatAuditAction(log.action),
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (log.details != null)
                  Text(log.details!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(dateFormat.format(log.timestamp),
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  IconData _getAuditIcon(String action) {
    switch (action) {
      case 'SIGN_IN':
        return Icons.login;
      case 'SIGN_OUT':
        return Icons.logout;
      case 'SIGN_UP':
        return Icons.person_add;
      case 'PASSWORD_CHANGED':
        return Icons.key;
      case 'PASSWORD_RESET':
        return Icons.lock_reset;
      case 'TWO_FACTOR_ENABLED':
        return Icons.security;
      case 'TWO_FACTOR_DISABLED':
        return Icons.shield_outlined;
      case 'EMAIL_VERIFIED':
        return Icons.verified;
      default:
        return Icons.info_outline;
    }
  }

  Color _getAuditColor(String action) {
    switch (action) {
      case 'SIGN_IN':
        return Colors.green;
      case 'SIGN_OUT':
        return Colors.orange;
      case 'PASSWORD_CHANGED':
      case 'PASSWORD_RESET':
        return Colors.blue;
      case 'TWO_FACTOR_ENABLED':
        return Colors.green;
      case 'TWO_FACTOR_DISABLED':
        return Colors.orange;
      case 'ACCOUNT_DELETED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatAuditAction(String action) {
    return action
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
        .join(' ');
  }

  Widget _buildDangerZone(ThemeData theme, AppUser user) {
    return _buildSectionCard(
      title: 'Danger Zone',
      icon: Icons.warning_amber,
      iconColor: Colors.red,
      children: [
        Text(
          'Permanently delete your account and all associated data. This action cannot be undone.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _showDeleteAccountDialog(user.uid),
          icon: const Icon(Icons.delete_forever),
          label: const Text('Delete Account'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        ),
      ],
    );
  }

  // Action methods
  Future<void> _resendVerificationEmail(String userId) async {
    try {
      await ref.read(customAuthServiceProvider).sendEmailVerification(userId);
      _showSnackBar('Verification email sent', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to send email', Colors.red);
    }
  }

  Future<void> _enableTwoFactor(String userId) async {
    try {
      await ref.read(customAuthServiceProvider).enableTwoFactor(userId);
      ref.invalidate(customAuthStateProvider);
      _showSnackBar('Two-factor authentication enabled', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to enable 2FA', Colors.red);
    }
  }

  Future<void> _disableTwoFactor(String userId) async {
    final password = await _showPasswordDialog('Disable 2FA');
    if (password == null) return;

    try {
      await ref
          .read(customAuthServiceProvider)
          .disableTwoFactor(userId, password);
      ref.invalidate(customAuthStateProvider);
      _showSnackBar('Two-factor authentication disabled', Colors.orange);
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.red);
    }
  }

  Future<void> _revokeSession(String sessionId) async {
    try {
      await ref.read(customAuthServiceProvider).revokeSession(sessionId);
      await _loadData();
      _showSnackBar('Session revoked', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to revoke session', Colors.red);
    }
  }

  Future<void> _revokeAllOtherSessions() async {
    final user = ref.read(legacyUserProvider);
    if (user == null) return;

    try {
      await ref
          .read(customAuthServiceProvider)
          .revokeAllOtherSessions(user.uid);
      await _loadData();
      _showSnackBar('All other sessions revoked', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to revoke sessions', Colors.red);
    }
  }

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (newController.text != confirmController.text) {
                _showSnackBar('Passwords do not match', Colors.red);
                return;
              }
              try {
                final user = ref.read(legacyUserProvider);
                await ref.read(customAuthServiceProvider).changePassword(
                      userId: user!.uid,
                      currentPassword: currentController.text,
                      newPassword: newController.text,
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar('Password changed successfully', Colors.green);
                }
              } on AuthException catch (e) {
                if (context.mounted) _showSnackBar(e.message, Colors.red);
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordDialog(String action) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm $action'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Enter your password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(String userId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This action is permanent and cannot be undone. Enter your password to confirm.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(customAuthServiceProvider)
                    .deleteAccount(userId, controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  context.go('/login');
                }
              } on AuthException catch (e) {
                if (context.mounted) _showSnackBar(e.message, Colors.red);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFullAuditLog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Activity Log',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _auditLogs?.length ?? 0,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildAuditLogTile(
                        Theme.of(context), _auditLogs![index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
