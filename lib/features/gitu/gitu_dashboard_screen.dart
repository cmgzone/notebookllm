import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'gitu_proactive_dashboard.dart';

/// Gitu Dashboard Screen
/// Wrapper screen for the Gitu Proactive Dashboard widget
class GituDashboardScreen extends ConsumerWidget {
  const GituDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.sparkles, size: 20),
            SizedBox(width: 8),
            Text('Gitu AI Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Gitu Settings',
            onPressed: () => context.push('/gitu-settings'),
          ),
        ],
        elevation: 0,
      ),
      body: const GituProactiveDashboard(),
    );
  }
}
