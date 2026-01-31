import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notebook_llm/features/gitu/gitu_chat_screen.dart';
import 'package:notebook_llm/features/gitu/gitu_provider.dart';

// Fake Notifier to avoid real timers in widget tests
class FakeGituChatNotifier extends GituChatNotifier {
  FakeGituChatNotifier(Ref ref) : super(ref);

  @override
  Future<void> connect() async {
    // Simulate connection start without side effects (timers/sockets)
    state = state.copyWith(isConnecting: true);
  }
}

void main() {
  testWidgets('GituChatScreen shows connecting state initially',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gituChatProvider.overrideWith((ref) => FakeGituChatNotifier(ref)),
        ],
        child: const MaterialApp(
          home: GituChatScreen(),
        ),
      ),
    );

    // Initial build triggers connection, so checking for "Connecting..." or similar UI
    expect(find.text('Gitu Assistant'), findsOneWidget);

    // We expect the empty state input hint "Connecting..." or the badge
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Connecting...'), findsAtLeastNWidgets(1));
  });

  testWidgets('GituChatScreen renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gituChatProvider.overrideWith((ref) => FakeGituChatNotifier(ref)),
        ],
        child: const MaterialApp(
          home: GituChatScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GituChatScreen), findsOneWidget);
  });
}
