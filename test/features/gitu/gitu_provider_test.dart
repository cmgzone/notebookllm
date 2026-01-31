import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';

import 'package:notebook_llm/features/gitu/gitu_provider.dart';
import 'package:notebook_llm/core/api/api_service.dart';
import 'package:notebook_llm/features/gitu/models/gitu_exceptions.dart';

// Manual Fakes
class FakeApiService implements ApiService {
  @override
  String get baseUrl => 'https://api.example.com';

  @override
  Future<String?> getToken() async => 'fake_token';

  // Implement other members with throw UnimplementedError() or meaningful defaults if needed
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWebSocketChannel implements WebSocketChannel {
  final FakeWebSocketSink _sink = FakeWebSocketSink();
  final StreamController _controller = StreamController();

  StreamController get controller => _controller;

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream get stream => _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWebSocketSink implements WebSocketSink {
  final List<dynamic> sentMessages = [];
  bool closed = false;

  @override
  void add(data) {
    sentMessages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {}

  @override
  Future close([int? closeCode, String? closeReason]) async {
    closed = true;
  }

  @override
  Future get done => Future.value();
}

void main() {
  late ProviderContainer container;
  late FakeApiService fakeApiService;
  late FakeWebSocketChannel fakeChannel;

  setUp(() {
    fakeApiService = FakeApiService();
    fakeChannel = FakeWebSocketChannel();

    container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(fakeApiService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('GituChatNotifier Tests', () {
    test('Initial state is disconnected', () {
      final state = container.read(gituChatProvider);
      expect(state.isConnected, false);
      expect(state.isConnecting, false);
      expect(state.messages, isEmpty);
    });

    test('GituException parsing logic', () {
      final socketError =
          GituException.from(Exception('SocketException: Failed host lookup'));
      expect(socketError.code, 'CONNECTION_ERROR');
      expect(socketError.message, contains('Unable to connect'));

      final authError = GituException.from(Exception('401 Unauthorized'));
      expect(authError.code, 'AUTH_ERROR');
      expect(authError.message, contains('Authentication failed'));
    });
  });
}
