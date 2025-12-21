// Stub file for ElevenLabs agents package on web platform
// This provides empty implementations to allow compilation on web

// Stub classes for web compilation
enum ConversationStatus { disconnected, connecting, connected }

class ConversationCallbacks {
  final void Function({required String conversationId})? onConnect;
  final void Function(DisconnectDetails details)? onDisconnect;
  final void Function({required String message, required MessageSource source})?
      onMessage;
  final void Function({required ConversationMode mode})? onModeChange;
  final void Function(String message, [dynamic context])? onError;

  ConversationCallbacks({
    this.onConnect,
    this.onDisconnect,
    this.onMessage,
    this.onModeChange,
    this.onError,
  });
}

class DisconnectDetails {
  final String reason;
  DisconnectDetails({this.reason = ''});
}

enum MessageSource { user, agent }

enum ConversationMode { listening, speaking }

class ConversationClient {
  final ConversationCallbacks? callbacks;
  ConversationStatus status = ConversationStatus.disconnected;
  bool isSpeaking = false;
  bool isMuted = false;

  ConversationClient({this.callbacks});

  void addListener(void Function() listener) {}
  void removeListener(void Function() listener) {}

  Future<void> startSession({
    required String agentId,
    String? userId,
  }) async {
    throw UnsupportedError('ElevenLabs agents not supported on web');
  }

  Future<void> endSession() async {}

  void toggleMute() {}

  void dispose() {}
}
