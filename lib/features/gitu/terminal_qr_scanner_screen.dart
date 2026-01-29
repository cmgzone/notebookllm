import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'gitu_provider.dart';

/// QR Code Scanner Screen for Gitu Terminal Authentication
///
/// This screen allows users to scan QR codes displayed in the terminal
/// to authenticate and link their terminal with the Gitu assistant.
class TerminalQRScannerScreen extends ConsumerStatefulWidget {
  const TerminalQRScannerScreen({super.key});

  @override
  ConsumerState<TerminalQRScannerScreen> createState() =>
      _TerminalQRScannerScreenState();
}

class _TerminalQRScannerScreenState
    extends ConsumerState<TerminalQRScannerScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _scannerActive = true;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  void _initializeScanner() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleQRCodeDetected(BarcodeCapture capture) async {
    if (_isProcessing || !_scannerActive) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _scannerActive = false;
      _errorMessage = null;
    });

    try {
      final parsed = _parseQrData(code);
      if (parsed == null) {
        throw Exception('Invalid QR code format');
      }

      final scanOk =
          await ref.read(gituTerminalAuthProvider.notifier).qrScan(parsed.sessionId);

      if (mounted) {
        if (scanOk) {
          final confirmed = await _showConfirmDialog(parsed);
          if (confirmed == true) {
            final ok = await ref
                .read(gituTerminalAuthProvider.notifier)
                .qrConfirm(parsed.sessionId);
            if (ok && mounted) {
              await _showSuccessDialog(parsed.sessionId);
            } else if (mounted) {
              setState(() {
                _errorMessage = 'Failed to confirm authentication';
                _scannerActive = true;
              });
            }
          } else {
            await ref
                .read(gituTerminalAuthProvider.notifier)
                .qrReject(parsed.sessionId);
            if (mounted) {
              setState(() {
                _scannerActive = true;
              });
            }
          }
        } else {
          setState(() {
            _errorMessage = 'QR session expired or invalid';
            _scannerActive = true;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to link terminal: ${e.toString()}';
        _scannerActive = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  _ParsedQrAuthData? _parseQrData(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme != 'notebookllm') return null;
    if (uri.host != 'gitu') return null;
    if (uri.path != '/qr-auth') return null;

    final session = uri.queryParameters['session'];
    if (session == null || session.isEmpty) return null;

    return _ParsedQrAuthData(
      sessionId: session,
      deviceId: uri.queryParameters['device'],
      deviceName: uri.queryParameters['name'],
    );
  }

  Future<bool?> _showConfirmDialog(_ParsedQrAuthData data) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(LucideIcons.shieldCheck, size: 48),
        title: const Text('Confirm Terminal Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Approve linking this terminal to your account?',
            ),
            const SizedBox(height: 12),
            if (data.deviceName != null)
              Text('Device: ${data.deviceName}'),
            if (data.deviceId != null) Text('Device ID: ${data.deviceId}'),
            const SizedBox(height: 12),
            Text(
              'Session: ${data.sessionId.substring(0, data.sessionId.length.clamp(0, 18))}...',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog(String code) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          LucideIcons.checkCircle,
          color: Colors.green,
          size: 48,
        ),
        title: const Text('Terminal Linked Successfully'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your terminal has been successfully linked to Gitu.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Session ID: ${code.substring(0, 8)}...',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to previous screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _toggleTorch() {
    _controller?.toggleTorch();
  }

  void _switchCamera() {
    _controller?.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Terminal QR Code'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.flashlight),
            onPressed: _toggleTorch,
            tooltip: 'Toggle Flashlight',
          ),
          IconButton(
            icon: const Icon(LucideIcons.switchCamera),
            onPressed: _switchCamera,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          // QR Scanner
          if (_controller != null)
            MobileScanner(
              controller: _controller,
              onDetect: _handleQRCodeDetected,
            ),

          // Scanning overlay
          CustomPaint(
            painter: ScannerOverlayPainter(),
            child: Container(),
          ),

          // Instructions
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.qrCode,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Scan QR Code from Terminal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Run "gitu auth --qr" in your terminal\nand scan the displayed QR code',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.x,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _scannerActive = true;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Linking terminal...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Manual entry option
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _showManualEntryDialog,
              icon: const Icon(LucideIcons.keyboard),
              label: const Text('Enter Code Manually'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualEntryDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Session Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the session ID shown in your terminal:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Session code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(LucideIcons.key),
              ),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.of(context).pop();
                _handleManualCode(code);
              }
            },
            child: const Text('Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManualCode(String code) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final scanOk =
          await ref.read(gituTerminalAuthProvider.notifier).qrScan(code);

      if (!scanOk) {
        setState(() {
          _errorMessage = 'Invalid or expired session';
          _scannerActive = true;
        });
        return;
      }

      final confirmed =
          await _showConfirmDialog(_ParsedQrAuthData(sessionId: code));
      if (confirmed != true) {
        await ref.read(gituTerminalAuthProvider.notifier).qrReject(code);
        if (mounted) {
          setState(() {
            _scannerActive = true;
          });
        }
        return;
      }

      final ok = await ref.read(gituTerminalAuthProvider.notifier).qrConfirm(code);
      if (ok) {
        await _showSuccessDialog(code);
      } else {
        setState(() {
          _errorMessage = 'Failed to confirm authentication';
          _scannerActive = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to link terminal: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}

class _ParsedQrAuthData {
  final String sessionId;
  final String? deviceId;
  final String? deviceName;

  const _ParsedQrAuthData({
    required this.sessionId,
    this.deviceId,
    this.deviceName,
  });
}

/// Custom painter for the scanner overlay with a cutout frame
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final framePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Calculate frame dimensions
    final frameSize = size.width * 0.7;
    final left = (size.width - frameSize) / 2;
    final top = (size.height - frameSize) / 2;
    final right = left + frameSize;
    final bottom = top + frameSize;

    // Draw semi-transparent overlay
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom),
          const Radius.circular(12),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw frame border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom),
        const Radius.circular(12),
      ),
      framePaint,
    );

    // Draw corner indicators
    const cornerLength = 30.0;

    // Top-left corner
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(right - cornerLength, top),
      Offset(right, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(left, bottom - cornerLength),
      Offset(left, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + cornerLength, bottom),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(right - cornerLength, bottom),
      Offset(right, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
