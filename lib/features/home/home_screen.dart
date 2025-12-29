import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../ui/widgets/notebook_card.dart';
import '../../core/auth/custom_auth_service.dart';
import 'create_notebook_dialog.dart';
import '../notebook/notebook_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../core/extensions/color_compat.dart';
import '../subscription/providers/subscription_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(customAuthStateProvider);
    final isLoggedIn = authState.isAuthenticated;

    return Scaffold(
      drawer: _AppDrawer(isLoggedIn: isLoggedIn),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 180,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.premiumGradient,
                ),
                child: Stack(
                  children: [
                    // Decorative bubbles
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome Back',
                              style: text.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ).animate().fadeIn().slideX(),
                            const SizedBox(height: 4),
                            Text(
                              'Your Notebooks',
                              style: text.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ).animate().fadeIn(delay: 200.ms).slideX(),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: 'Menu',
              ),
            ),
            actions: [
              // Credit Balance Display
              Consumer(builder: (context, ref, _) {
                final credits = ref.watch(creditBalanceProvider);
                return GestureDetector(
                  onTap: () => context.push('/subscription'),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.coins,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          '$credits',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Consumer(builder: (context, ref, _) {
                final mode = ref.watch(themeModeProvider);
                return IconButton(
                  onPressed: () =>
                      ref.read(themeModeProvider.notifier).toggle(),
                  icon: Icon(
                    mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                    color: Colors.white,
                  ),
                  tooltip: mode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
                );
              }),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const CreateNotebookDialog(),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: 'New Notebook',
                ),
              ),
            ],
          ),
          const SliverPadding(
            padding: EdgeInsets.all(20),
            sliver: _NotebookGrid(),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80), // Bottom padding
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/voice-mode'),
        icon: const Icon(Icons.mic),
        label: const Text('Voice Mode'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ).animate().scale(delay: 500.ms),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  final bool isLoggedIn;

  const _AppDrawer({required this.isLoggedIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: Colors.transparent, // For glass effect
      width: 320,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.85),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppTheme.premiumGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          height: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Notebook LLM',
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI-Powered Learning',
                        style: text.bodySmall?.copyWith(
                          color: scheme.secondaryText,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Features
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    children: [
                      const _DrawerSection(title: 'Create'),
                      _DrawerItem(
                        icon: LucideIcons.filePlus,
                        label: 'New Notebook',
                        isActive: true, // Highlight primary action
                        onTap: () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (_) => const CreateNotebookDialog(),
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.bookOpen,
                        label: 'Create Ebook',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/ebook-creator');
                        },
                      ),
                      const Divider(height: 32),
                      const _DrawerSection(title: 'Library'),
                      _DrawerItem(
                        icon: LucideIcons.library,
                        label: 'My Ebooks',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/ebooks');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.fileText,
                        label: 'Sources',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/sources');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.palette,
                        label: 'Studio',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/studio');
                        },
                      ),
                      const Divider(height: 32),
                      const _DrawerSection(title: 'Tools'),
                      _DrawerItem(
                        icon: LucideIcons.mic,
                        label: 'Voice Mode',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/voice-mode');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.users,
                        label: 'Meeting Mode',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/meeting-mode');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.search,
                        label: 'Web Search',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/search');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.microscope,
                        label: 'Deep Research',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/research');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.trophy,
                        label: 'Sports Hub',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/sports-hub');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.messageSquare,
                        label: 'Chat',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/chat');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.utensils,
                        label: 'Meal Planner',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/meal-planner');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.languages,
                        label: 'Language Learning',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/language-learning');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.bookOpen,
                        label: 'Story Generator',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/story-generator');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.megaphone,
                        label: 'Ads Generator',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/ads-generator');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.heartHandshake,
                        label: 'Wellness AI',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/wellness');
                        },
                      ),
                      const Divider(height: 32),
                      const _DrawerSection(title: 'Progress'),
                      _DrawerItem(
                        icon: LucideIcons.trophy,
                        label: 'Progress Hub',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/progress');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.award,
                        label: 'Achievements',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/achievements');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.flame,
                        label: 'Daily Challenges',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/daily-challenges');
                        },
                      ),
                      const Divider(height: 32),
                      const _DrawerSection(title: 'Settings'),
                      _DrawerItem(
                        icon: LucideIcons.brain,
                        label: 'Context Profile',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/context-profile');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.bot,
                        label: 'AI Model Settings',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/settings');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.shield,
                        label: 'Security',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/security');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.cpu,
                        label: 'Background Queue',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/background-settings');
                        },
                      ),
                      _DrawerItem(
                        icon: LucideIcons.helpCircle,
                        label: 'Feature Tour',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/feature-tour');
                        },
                      ),
                    ],
                  ),
                ),

                // Footer - Auth
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: scheme.outline.withValues(alpha: 0.1))),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: _DrawerItem(
                    icon: isLoggedIn ? LucideIcons.logOut : LucideIcons.logIn,
                    label: isLoggedIn ? 'Sign Out' : 'Sign In',
                    color: isLoggedIn ? scheme.error : scheme.primary,
                    onTap: () async {
                      Navigator.pop(context);
                      if (isLoggedIn) {
                        await ref
                            .read(customAuthStateProvider.notifier)
                            .signOut();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Signed out')),
                        );
                        context.go('/login');
                      } else {
                        context.go('/login');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;

  const _DrawerSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final itemColor =
        color ?? (isActive ? scheme.primary : scheme.secondaryText);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: isActive
                ? BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Row(
              children: [
                Icon(icon, size: 20, color: itemColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: text.bodyMedium?.copyWith(
                      color: itemColor,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isActive)
                  Icon(LucideIcons.chevronRight, size: 16, color: itemColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookGrid extends ConsumerWidget {
  const _NotebookGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebooks = ref.watch(notebookProvider);

    if (notebooks.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/empty_notebooks.png',
                height: 200,
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text(
                'No notebooks yet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),
              Text(
                'Create your first notebook to start organizing your AI-powered learning journey.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.secondaryText,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const CreateNotebookDialog(),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create Notebook'),
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220, // Responsive sizing
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final n = notebooks[index];
          return NotebookCard(
            title: n.title,
            sourceCount: n.sourceCount,
            notebookId: n.id,
            coverImage: n.coverImage,
          ).animate().fadeIn(delay: Duration(milliseconds: index * 50));
        },
        childCount: notebooks.length,
      ),
    );
  }
}
