import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../core/api/api_service.dart';

// ============================================================================
// GITU CHAT PROVIDER
// ============================================================================

final gituChatProvider =
    StateNotifierProvider<GituChatNotifier, GituChatState>((ref) {
  return GituChatNotifier(ref);
});

class GituMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? model;
  final Map<String, dynamic>? metadata;

  const GituMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.model,
    this.metadata,
  });

  factory GituMessage.fromJson(Map<String, dynamic> json) {
    return GituMessage(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      model: json['model'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class GituChatState {
  final List<GituMessage> messages;
  final bool isConnected;
  final bool isConnecting;
  final String? error;

  const GituChatState({
    this.messages = const [],
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
  });

  GituChatState copyWith({
    List<GituMessage>? messages,
    bool? isConnected,
    bool? isConnecting,
    String? error,
  }) {
    return GituChatState(
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error,
    );
  }
}

class GituChatNotifier extends StateNotifier<GituChatState> {
  final Ref _ref;
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  final WebSocketChannel Function(Uri)? _channelBuilder;

  GituChatNotifier(this._ref, {WebSocketChannel Function(Uri)? channelBuilder})
      : _channelBuilder = channelBuilder,
        super(const GituChatState());

  Future<void> connect() async {
    if (state.isConnected || state.isConnecting) return;

    state = state.copyWith(isConnecting: true, error: null);

    try {
      final apiService = _ref.read(apiServiceProvider);
      final token = await apiService.getToken();

      if (token == null) {
        state = state.copyWith(
          isConnecting: false,
          error: 'Authentication token not found',
        );
        return;
      }

      // Determine WS URL (replace http/https with ws/wss)
      final apiBase = apiService.baseUrl;
      final uri = Uri.parse(apiBase);
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final host = uri.host;
      final port = uri.hasPort ? ':${uri.port}' : '';
      
      // WebSocket is mounted at /ws/gitu, not under /api
      final wsUrlStr = '$scheme://$host$port/ws/gitu?token=$token';
      final wsUrl = Uri.parse(wsUrlStr);

      _channel = _channelBuilder?.call(wsUrl) ?? WebSocketChannel.connect(wsUrl);

      // Connection timeout safety
      Future.delayed(const Duration(seconds: 15), () {
        if (state.isConnecting && mounted) {
          _disconnect(error: 'Connection timed out. Please check your internet connection.');
        }
      });

      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) {
          _disconnect(error: 'Connection error: $error');
        },
        onDone: () {
          _disconnect(error: 'Connection closed');
        },
      );

      _startPing();
    } catch (e) {
      _disconnect(error: 'Failed to connect: $e');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final type = data['type'] as String?;

      switch (type) {
        case 'connected':
          state = state.copyWith(isConnected: true, isConnecting: false);
          break;
        case 'pong':
          // Pong received, connection alive
          break;
        case 'assistant_response':
          final payload = data['payload'] as Map<String, dynamic>;
          _addMessage(GituMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: payload['content'] as String,
            isUser: false,
            timestamp: DateTime.now(),
            model: payload['model'] as String?,
          ));
          break;
        case 'incoming_message':
           // Handle messages from other platforms if needed
           // For now, we might not display them or handle them differently
           break;
        case 'error':
          final payload = data['payload'] as Map<String, dynamic>;
          state = state.copyWith(error: payload['error'] as String?);
          break;
      }
    } catch (e) {
      developer.log('Error parsing Gitu WS message: $e', name: 'GituChatNotifier');
    }
  }

  void sendMessage(String text) {
    if (_channel == null || !state.isConnected) {
      connect(); // Try to reconnect
      // For now, maybe queue or fail. Let's fail gracefully.
      return;
    }

    // Optimistic add
    _addMessage(GituMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    final message = {
      'type': 'user_message',
      'payload': {'text': text}
    };

    _channel!.sink.add(jsonEncode(message));
  }

  void _addMessage(GituMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
    );
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (state.isConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({'type': 'ping'}));
      }
    });
  }

  void _disconnect({String? error}) {
    _pingTimer?.cancel();
    _channel = null;
    state = state.copyWith(
      isConnected: false,
      isConnecting: false,
      error: error,
    );
  }

  void disconnect() {
    _channel?.sink.close(status.goingAway);
    _disconnect();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

// ============================================================================
// TERMINAL AUTH PROVIDER (Existing)
// ============================================================================

/// Provider for Gitu terminal authentication state
final gituTerminalAuthProvider =
    StateNotifierProvider<GituTerminalAuthNotifier, GituTerminalAuthState>(
  (ref) => GituTerminalAuthNotifier(ref),
);

/// State for Gitu terminal authentication
class GituTerminalAuthState {
  final bool isLinked;
  final List<LinkedTerminal> linkedTerminals;
  final bool isLoading;
  final String? error;

  const GituTerminalAuthState({
    this.isLinked = false,
    this.linkedTerminals = const [],
    this.isLoading = false,
    this.error,
  });

  GituTerminalAuthState copyWith({
    bool? isLinked,
    List<LinkedTerminal>? linkedTerminals,
    bool? isLoading,
    String? error,
  }) {
    return GituTerminalAuthState(
      isLinked: isLinked ?? this.isLinked,
      linkedTerminals: linkedTerminals ?? this.linkedTerminals,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PairingToken {
  final String token;
  final DateTime expiresAt;
  final int expiresInSeconds;

  const PairingToken({
    required this.token,
    required this.expiresAt,
    required this.expiresInSeconds,
  });

  factory PairingToken.fromJson(Map<String, dynamic> json) {
    return PairingToken(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      expiresInSeconds: json['expiresInSeconds'] as int,
    );
  }
}

/// Model for a linked terminal device
class LinkedTerminal {
  final String deviceId;
  final String deviceName;
  final DateTime linkedAt;
  final DateTime? lastUsedAt;
  final String status;

  const LinkedTerminal({
    required this.deviceId,
    required this.deviceName,
    required this.linkedAt,
    this.lastUsedAt,
    required this.status,
  });

  factory LinkedTerminal.fromJson(Map<String, dynamic> json) {
    return LinkedTerminal(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      linkedAt: DateTime.parse(json['linkedAt'] as String),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'linkedAt': linkedAt.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'status': status,
    };
  }
}

/// Notifier for managing Gitu terminal authentication
class GituTerminalAuthNotifier extends StateNotifier<GituTerminalAuthState> {
  final Ref _ref;

  GituTerminalAuthNotifier(this._ref) : super(const GituTerminalAuthState()) {
    _loadLinkedTerminals();
  }

  /// Load linked terminals from backend
  Future<void> _loadLinkedTerminals() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final apiService = _ref.read(apiServiceProvider);
      final data = await apiService.get<Map<String, dynamic>>(
        '/gitu/terminal/devices',
      );

      final terminals = (data['devices'] as List)
          .map((json) => LinkedTerminal.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        linkedTerminals: terminals,
        isLinked: terminals.isNotEmpty,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error loading terminals: ${e.toString()}',
      );
    }
  }

  Future<PairingToken?> generatePairingToken() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final apiService = _ref.read(apiServiceProvider);
      final data = await apiService.post<Map<String, dynamic>>(
        '/gitu/terminal/generate-token',
        {},
      );

      state = state.copyWith(isLoading: false);
      return PairingToken.fromJson(data);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error generating pairing token: ${e.toString()}',
      );
      return null;
    }
  }

  Future<bool> qrScan(String sessionId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final apiService = _ref.read(apiServiceProvider);
      await apiService.post<Map<String, dynamic>>(
        '/gitu/terminal/qr-scan',
        {'sessionId': sessionId},
      );

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error scanning QR code: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> qrConfirm(String sessionId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final apiService = _ref.read(apiServiceProvider);
      await apiService.post<Map<String, dynamic>>(
        '/gitu/terminal/qr-confirm',
        {'sessionId': sessionId},
      );

      // Reload linked terminals
      await _loadLinkedTerminals();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error confirming QR authentication: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> qrReject(String sessionId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final apiService = _ref.read(apiServiceProvider);
      await apiService.post<Map<String, dynamic>>(
        '/gitu/terminal/qr-reject',
        {'sessionId': sessionId},
      );

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error rejecting QR authentication: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> unlinkTerminal(String deviceId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final apiService = _ref.read(apiServiceProvider);
      await apiService.post<Map<String, dynamic>>(
        '/gitu/terminal/unlink',
        {'deviceId': deviceId},
      );

      await _loadLinkedTerminals();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error unlinking terminal: ${e.toString()}',
      );
      return false;
    }
  }

  /// Refresh the list of linked terminals
  Future<void> refresh() async {
    await _loadLinkedTerminals();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }
}
