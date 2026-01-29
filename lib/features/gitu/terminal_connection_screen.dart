import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'gitu_provider.dart';
import 'terminal_qr_scanner_screen.dart';

/// Terminal Connection Management Screen
///
/// Allows users to:
/// - Link new terminals via QR code or pairing token
/// - View all linked terminals
/// - Unlink terminals
/// - See last used timestamps
class TerminalConnectionScreen extends ConsumerStatefulWidget {
  const TerminalConnectionScreen({super.key});

  @override
  ConsumerState<TerminalConnectionScreen> createState() =>
      _TerminalConnectionScreenState();
}

class _TerminalConnectionScreenState
    extends ConsumerState<TerminalConnectionScreen> {
  int _linkMethodIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load linked terminals on screen load
    Future.microtask(() {
      ref.read(gituTerminalAuthProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(gituTerminalAuthProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal Connections'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () {
              ref.read(gituTerminalAuthProvider.notifier).refresh();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: authState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(gituTerminalAuthProvider.notifier).refresh();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header card with instructions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.terminal,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Link Your Terminal',
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Connect your terminal to use Gitu from the command line. '
                            'Run "gitu auth --qr" in your terminal and scan the QR code, '
                            'or generate a pairing token here and enter it in the terminal.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Link buttons
                  Column(
                    children: [
                      ToggleButtons(
                        isSelected: [_linkMethodIndex == 0, _linkMethodIndex == 1],
                        onPressed: (index) {
                          setState(() {
                            _linkMethodIndex = index;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        constraints: const BoxConstraints(minHeight: 44),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Icon(LucideIcons.qrCode, size: 18),
                                SizedBox(width: 8),
                                Text('QR'),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Icon(LucideIcons.key, size: 18),
                                SizedBox(width: 8),
                                Text('Token'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_linkMethodIndex == 0)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showQRScanner,
                            icon: const Icon(LucideIcons.qrCode),
                            label: const Text('Scan QR Code'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _generatePairingToken,
                            icon: const Icon(LucideIcons.key),
                            label: const Text('Generate Token'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Error message
                  if (authState.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.alertCircle,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              authState.error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x),
                            onPressed: () {
                              ref
                                  .read(gituTerminalAuthProvider.notifier)
                                  .clearError();
                            },
                          ),
                        ],
                      ),
                    ),

                  // Linked terminals section
                  Text(
                    'Linked Terminals (${authState.linkedTerminals.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Terminals list
                  if (authState.linkedTerminals.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.terminal,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No terminals linked yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Link a terminal to start using Gitu from the command line',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...authState.linkedTerminals.map((terminal) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              LucideIcons.terminal,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(terminal.deviceName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Device ID: ${terminal.deviceId.substring(0, 8)}...',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                terminal.lastUsedAt != null
                                    ? 'Last used ${timeago.format(terminal.lastUsedAt!)}'
                                    : 'Linked ${timeago.format(terminal.linkedAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.trash2),
                            color: Colors.red,
                            onPressed: () => _confirmUnlink(terminal),
                            tooltip: 'Unlink',
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  void _showQRScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TerminalQRScannerScreen(),
      ),
    );
  }

  Future<void> _generatePairingToken() async {
    final token = await ref.read(gituTerminalAuthProvider.notifier).generatePairingToken();
    if (!mounted) return;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to generate pairing token'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => _PairingTokenDialog(token: token),
    );
  }

  Future<void> _confirmUnlink(LinkedTerminal terminal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Terminal?'),
        content: Text(
          'Are you sure you want to unlink "${terminal.deviceName}"? '
          'You will need to link it again to use Gitu from this terminal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(gituTerminalAuthProvider.notifier)
          .unlinkTerminal(terminal.deviceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Terminal unlinked successfully'
                  : 'Failed to unlink terminal',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}

class _PairingTokenDialog extends StatefulWidget {
  final PairingToken token;

  const _PairingTokenDialog({required this.token});

  @override
  State<_PairingTokenDialog> createState() => _PairingTokenDialogState();
}

class _PairingTokenDialogState extends State<_PairingTokenDialog> {
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
      if (_now.isBefore(widget.token.expiresAt)) {
        _tick();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.token.expiresAt.difference(_now);
    final remainingSeconds = remaining.inSeconds.clamp(0, 999999);
    final mins = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (remainingSeconds % 60).toString().padLeft(2, '0');
    final expired = remainingSeconds == 0;

    return AlertDialog(
      title: const Text('Pairing Token'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Run this in your terminal:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'gitu auth ${widget.token.token}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.copy),
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: widget.token.token),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Token copied')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                expired ? LucideIcons.xCircle : LucideIcons.clock,
                size: 16,
                color: expired ? Colors.red : Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                expired ? 'Token expired' : 'Expires in $mins:$secs',
                style: TextStyle(
                  fontSize: 12,
                  color: expired ? Colors.red : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
