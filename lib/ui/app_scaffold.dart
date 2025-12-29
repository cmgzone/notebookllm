import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/studio/mini_audio_player.dart';
import 'quick_ai_model_selector.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home'),
    NavigationDestination(
        icon: Icon(Icons.search_outlined),
        selectedIcon: Icon(Icons.search),
        label: 'Search'),
    NavigationDestination(
        icon: Icon(Icons.description_outlined),
        selectedIcon: Icon(Icons.description),
        label: 'Sources'),
    NavigationDestination(
        icon: Icon(Icons.chat_outlined),
        selectedIcon: Icon(Icons.chat),
        label: 'Chat'),
    NavigationDestination(
        icon: Icon(Icons.mic_none),
        selectedIcon: Icon(Icons.mic),
        label: 'Studio'),
  ];

  int _indexForLocation(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/sources')) return 2;
    if (location.startsWith('/chat')) return 3;
    if (location.startsWith('/studio')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(location);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          child,
          // Quick AI Model Selector (bottom-left, above nav bar)
          const Positioned(
            left: 8,
            bottom: 80, // Above the NavigationBar
            child: SafeArea(
              child: QuickAIModelSelector(),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniAudioPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: scheme.surfaceContainer,
        selectedIndex: index,
        destinations: _destinations,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/search');
              break;
            case 2:
              context.go('/sources');
              break;
            case 3:
              context.go('/chat');
              break;
            case 4:
              context.go('/studio');
              break;
          }
        },
      ),
    );
  }
}
