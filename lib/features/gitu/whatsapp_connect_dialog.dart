import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../../core/api/api_service.dart';
import '../../ui/components/glass_container.dart';

// Provider for WhatsApp connection state
final whatsappConnectionProvider = StateNotifierProvider.autoDispose<
    WhatsAppConnectionNotifier, WhatsAppConnectionState>((ref) {
  return WhatsAppConnectionNotifier(ref);
});

enum ConnectionStatus { disconnected, connecting, scanning, connected, error }

class WhatsAppConnectionState {
  final ConnectionStatus status;
  final String? qrData;
  final String? error;
  final String? deviceName;

  WhatsAppConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.qrData,
    this.error,
    this.deviceName,
  });

  WhatsAppConnectionState copyWith({
    ConnectionStatus? status,
    String? qrData,
    String? error,
    String? deviceName,
  }) {
    return WhatsAppConnectionState(
      status: status ?? this.status,
      qrData: qrData ?? this.qrData,
      error: error ?? this.error,
      deviceName: deviceName ?? this.deviceName,
    );
  }
}

class WhatsAppConnectionNotifier
    extends StateNotifier<WhatsAppConnectionState> {
  final Ref _ref;
  Timer? _statusTimer;
  bool _isDisposed = false;

  WhatsAppConnectionNotifier(this._ref) : super(WhatsAppConnectionState()) {
    checkStatus();
  }

  @override
  void dispose() {
    _stopPolling();
    _isDisposed = true;
    super.dispose();
  }

  void _stopPolling() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  void _startPolling() {
    _stopPolling();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      checkStatus();
    });
  }

  Future<void> checkStatus() async {
    if (_isDisposed) return;
    try {
      final api = _ref.read(apiServiceProvider);
      // This endpoint needs to be implemented on backend or use existing health endpoint
      // For now we assume a dedicated endpoint or use existing WebSocket
      final response =
          await api.get<Map<String, dynamic>>('/gitu/whatsapp/status');

      final statusStr = response['status'] as String?;
      final qr = response['qrCode'] as String?;
      final device = response['device'] as String?;

      if (_isDisposed) return;

      ConnectionStatus newStatus;
      switch (statusStr) {
        case 'connected':
          newStatus = ConnectionStatus.connected;
          _stopPolling(); // Stop polling if connected
          break;
        case 'scanning':
        case 'connecting':
          newStatus = ConnectionStatus.scanning;
          if (_statusTimer == null) {
            _startPolling(); // Ensure polling while scanning
          }
          break;
        default:
          newStatus = ConnectionStatus.disconnected;
          // Don't auto-poll if disconnected, wait for user action
          _stopPolling();
      }

      // If we have a QR code but not connected, we are scanning
      if (qr != null && newStatus != ConnectionStatus.connected) {
        newStatus = ConnectionStatus.scanning;
        if (_statusTimer == null) {
          _startPolling();
        }
      }

      state = state.copyWith(
        status: newStatus,
        qrData: qr,
        deviceName: device,
        error: null,
      );
    } catch (e) {
      if (!_isDisposed) {
        state = state.copyWith(
          status: ConnectionStatus.error,
          error: 'Could not check status: $e',
        );
      }
    }
  }

  Future<void> connect() async {
    try {
      state = state.copyWith(status: ConnectionStatus.connecting, error: null);
      final api = _ref.read(apiServiceProvider);
      await api.post('/gitu/whatsapp/connect', {});
      _startPolling();
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        error: 'Failed to start connection: $e',
      );
    }
  }

  Future<void> disconnect() async {
    try {
      final api = _ref.read(apiServiceProvider);
      await api.post('/gitu/whatsapp/disconnect', {});
      state = WhatsAppConnectionState(status: ConnectionStatus.disconnected);
      _stopPolling();
    } catch (e) {
      state = state.copyWith(error: 'Failed to disconnect: $e');
    }
  }
}

class WhatsAppConnectDialog extends ConsumerWidget {
  const WhatsAppConnectDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whatsappConnectionProvider);
    final notifier = ref.read(whatsappConnectionProvider.notifier);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Connect WhatsApp',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildContent(context, ref, state, notifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      WhatsAppConnectionState state, WhatsAppConnectionNotifier notifier) {
    switch (state.status) {
      case ConnectionStatus.connected:
        return Column(
          children: [
            const Icon(LucideIcons.checkCircle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Connected Successfully',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Linked to ${state.deviceName ?? "Device"}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => notifier.disconnect(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Disconnect'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final api = ref.read(apiServiceProvider);
                    await api.post('/gitu/whatsapp/link-current', {});
                    messenger.showSnackBar(const SnackBar(
                        content: Text('WhatsApp linked to your account')));
                  } catch (e) {
                    messenger.showSnackBar(
                        SnackBar(content: Text('Failed to link: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Link This WhatsApp Session'),
              ),
            ),
          ],
        );

      case ConnectionStatus.scanning:
        if (state.qrData == null) {
          return const Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating QR Code...'),
            ],
          );
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: state.qrData!,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scan with WhatsApp',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open WhatsApp on your phone > Menu > Linked devices > Link a device',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );

      case ConnectionStatus.connecting:
        return const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing connection...'),
          ],
        );

      case ConnectionStatus.error:
        return Column(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Connection Failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => notifier.connect(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        );

      case ConnectionStatus.disconnected:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.messageCircle,
                  size: 48, color: Colors.green),
            ),
            const SizedBox(height: 24),
            const Text(
              'Connect WhatsApp',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Link your WhatsApp account to chat with Gitu directly from WhatsApp.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => notifier.connect(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Start Connection'),
              ),
            ),
          ],
        );
    }
  }
}
