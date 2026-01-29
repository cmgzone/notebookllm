import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';
import 'services/identity_service.dart';
import 'models/linked_account.dart';

class GituLinkedAccountsScreen extends ConsumerWidget {
  const GituLinkedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(linkedAccountsProvider);
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.premiumGradient),
        ),
        title: const Text('Linked Accounts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.alertCircle, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Error: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(linkedAccountsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.link, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No linked accounts'),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(linkedAccountsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _AccountTile(account: accounts[i]),
            ),
          );
        },
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  final LinkedAccount account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = _iconForPlatform(account.platform);
    final verifiedColor = account.verified ? Colors.green : Colors.grey;
    final primaryColor = account.isPrimary ? Colors.amber : Colors.grey;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account.platform.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(LucideIcons.badgeCheck, color: verifiedColor, size: 20),
                const SizedBox(width: 8),
                Icon(LucideIcons.star, color: primaryColor, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(account.displayName ?? account.platformUserId, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(identityServiceProvider).setPrimary(account.platform, account.platformUserId);
                      ref.invalidate(linkedAccountsProvider);
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  },
                  icon: const Icon(LucideIcons.star),
                  label: const Text('Set Primary'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(identityServiceProvider).verify(account.platform, account.platformUserId);
                      ref.invalidate(linkedAccountsProvider);
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  },
                  icon: const Icon(LucideIcons.badgeCheck),
                  label: const Text('Verify'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _confirmUnlink(context, ref),
                  icon: const Icon(LucideIcons.unlink),
                  label: const Text('Unlink'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUnlink(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unlink Account'),
        content: Text('Unlink ${account.platform.toUpperCase()} account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(identityServiceProvider).unlink(account.platform, account.platformUserId);
                ref.invalidate(linkedAccountsProvider);
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }

  IconData _iconForPlatform(String p) {
    switch (p) {
      case 'whatsapp':
        return LucideIcons.messageCircle;
      case 'telegram':
        return LucideIcons.send;
      case 'email':
        return LucideIcons.mail;
      case 'terminal':
        return LucideIcons.terminal;
      case 'flutter':
        return LucideIcons.smartphone;
      default:
        return LucideIcons.link;
    }
  }
}
