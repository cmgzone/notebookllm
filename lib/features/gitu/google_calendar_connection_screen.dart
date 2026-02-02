import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import 'services/google_calendar_service.dart';

class GoogleCalendarConnectionScreen extends ConsumerStatefulWidget {
  const GoogleCalendarConnectionScreen({super.key});

  @override
  ConsumerState<GoogleCalendarConnectionScreen> createState() =>
      _GoogleCalendarConnectionScreenState();
}

class _GoogleCalendarConnectionScreenState
    extends ConsumerState<GoogleCalendarConnectionScreen> {
  bool _busy = false;
  bool _polling = false;

  Future<void> _refresh() async {
    ref.invalidate(googleCalendarStatusProvider);
    await ref.read(googleCalendarStatusProvider.future);
  }

  void _startPolling() {
    if (_polling) return;
    _polling = true;
    _pollForConnection();
  }

  void _stopPolling() {
    _polling = false;
  }

  Future<void> _pollForConnection() async {
    while (_polling && mounted) {
      await Future.delayed(const Duration(seconds: 5));
      if (!_polling || !mounted) break;
      try {
        ref.invalidate(googleCalendarStatusProvider);
        final status = await ref.read(googleCalendarStatusProvider.future);
        if (status.connected) {
          _stopPolling();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google Calendar connected!')),
            );
          }
          break;
        }
      } catch (_) {
      }
    }
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final authUrl = await ref.read(googleCalendarServiceProvider).getAuthUrl();
      final ok = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        throw Exception('Unable to open browser');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Complete sign-in in your browser. We'll detect it automatically.",
          ),
        ),
      );
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calendar connect failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disconnect Google Calendar'),
        content: const Text('Remove Google Calendar access for this account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(googleCalendarServiceProvider).disconnect();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Calendar disconnected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(googleCalendarStatusProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace:
            Container(decoration: const BoxDecoration(gradient: AppTheme.premiumGradient)),
        title: const Text(
          'Google Calendar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
            onPressed: _busy ? null : _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertCircle, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error: $err'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (status) {
          final info = status.connection;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.calendar, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Connect Google Calendar to let Gitu view and manage your events. '
                            'After completing sign-in in your browser, return here and tap Refresh.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              status.connected
                                  ? LucideIcons.checkCircle2
                                  : LucideIcons.xCircle,
                              color: status.connected ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                status.connected ? 'Connected' : 'Not Connected',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (_busy)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (status.connected) ...[
                          if (info?.email != null) Text('Account: ${info!.email}'),
                          if (info?.createdAt != null)
                            Text('Connected: ${timeago.format(info!.createdAt!)}'),
                          if (info?.lastUsedAt != null)
                            Text('Last used: ${timeago.format(info!.lastUsedAt!)}'),
                          if (info?.scopes != null && info!.scopes!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('Scopes', style: theme.textTheme.labelLarge),
                            const SizedBox(height: 6),
                            Text(info.scopes!),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _disconnect,
                              icon: const Icon(LucideIcons.unlink),
                              label: const Text('Disconnect'),
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : _connect,
                              icon: const Icon(LucideIcons.link),
                              label: const Text('Connect Google Calendar'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

