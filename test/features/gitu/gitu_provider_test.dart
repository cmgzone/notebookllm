import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notebook_llm/core/api/api_service.dart';
import 'package:notebook_llm/features/gitu/gitu_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Helper to mock Ref
class FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock ApiService by extending it
class MockApiService extends ApiService {
  MockApiService() : super(FakeRef());
  
  @override
  Future<String?> getToken() async => 'test-token';
  
  @override
  String get baseUrl => 'https://test.com/api/';
}

// Mock WebSocketChannel
class MockWebSocketChannel implements WebSocketChannel {
  final StreamController _controller = StreamController.broadcast();
  final MockWebSocketSink _sink = MockWebSocketSink();

  @override
  Stream get stream => _controller.stream;

  @override
  WebSocketSink get sink => _sink;
  
  void addMessage(String msg) => _controller.add(msg);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock WebSocketSink
class MockWebSocketSink implements WebSocketSink {
  final List<String> sentMessages = [];
  
  @override
  void add(dynamic data) {
    sentMessages.add(data.toString());
  }
  
  @override
  Future close([int? closeCode, String? closeReason]) async {}
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockApiService mockApiService;
  late MockWebSocketChannel mockWebSocketChannel;

  setUp(() {
    mockApiService = MockApiService();
    mockWebSocketChannel = MockWebSocketChannel();
  });

  test('GituChatNotifier connects and updates state', () async {
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApiService),
        gituChatProvider.overrideWith((ref) => GituChatNotifier(
          ref, 
          channelBuilder: (_) => mockWebSocketChannel,
        )),
      ],
    );

    final notifier = container.read(gituChatProvider.notifier);

    expect(container.read(gituChatProvider).isConnected, false);

    // Trigger connection
    await notifier.connect();

    // Verify connecting state (it might be fast, but we expect it to wait for 'connected' message)
    // The implementation sets isConnecting=true, then awaits getToken, then connects.
    // So if we check immediately after await connect(), it should be connecting=true (waiting for 'connected' msg).
    expect(container.read(gituChatProvider).isConnecting, true);

    // Simulate 'connected' message from backend
    mockWebSocketChannel.addMessage('{"type": "connected", "payload": {}}');
    
    // Allow stream to process
    await Future.delayed(Duration.zero);

    expect(container.read(gituChatProvider).isConnected, true);
    expect(container.read(gituChatProvider).isConnecting, false);
  });
  
  test('GituChatNotifier handles incoming assistant response', () async {
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApiService),
        gituChatProvider.overrideWith((ref) => GituChatNotifier(
          ref, 
          channelBuilder: (_) => mockWebSocketChannel,
        )),
      ],
    );

    final notifier = container.read(gituChatProvider.notifier);
    await notifier.connect();
    
    mockWebSocketChannel.addMessage('{"type": "connected", "payload": {}}');
    await Future.delayed(Duration.zero);
    
    // Simulate assistant response
    mockWebSocketChannel.addMessage(
      '{"type": "assistant_response", "payload": {"content": "Hello user", "model": "gemini"}}'
    );
    await Future.delayed(Duration.zero);
    
    final messages = container.read(gituChatProvider).messages;
    expect(messages.length, 1);
    expect(messages.first.content, "Hello user");
    expect(messages.first.isUser, false);
    expect(messages.first.model, "gemini");
  });
  
  test('GituChatNotifier sends user message', () async {
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApiService),
        gituChatProvider.overrideWith((ref) => GituChatNotifier(
          ref, 
          channelBuilder: (_) => mockWebSocketChannel,
        )),
      ],
    );

    final notifier = container.read(gituChatProvider.notifier);
    await notifier.connect();
    
    mockWebSocketChannel.addMessage('{"type": "connected", "payload": {}}');
    await Future.delayed(Duration.zero);
    
    notifier.sendMessage("Hi there");
    
    final messages = container.read(gituChatProvider).messages;
    expect(messages.length, 1);
    expect(messages.first.content, "Hi there");
    expect(messages.first.isUser, true);
    
    // Check if sent to socket
    final sink = mockWebSocketChannel.sink as MockWebSocketSink;
    expect(sink.sentMessages.length, 1);
    expect(sink.sentMessages.first, contains('"text":"Hi there"'));
  });
}
