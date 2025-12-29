import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/sports_models.dart';
import '../providers/sports_analytics_provider.dart';
import '../team_logo_service.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Teams'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _showAddTeamDialog(context, ref),
          ),
        ],
      ),
      body: state.teams.isEmpty
          ? _EmptyFavorites(onAdd: () => _showAddTeamDialog(context, ref))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.teams.length,
              itemBuilder: (context, index) {
                final team = state.teams[index];
                return _FavoriteTeamCard(
                  team: team,
                  onToggleNotifications: () => ref
                      .read(favoritesProvider.notifier)
                      .toggleNotifications(team.id),
                  onRemove: () => ref
                      .read(favoritesProvider.notifier)
                      .removeFavorite(team.id),
                ).animate().fadeIn(delay: Duration(milliseconds: index * 50));
              },
            ),
    );
  }

  void _showAddTeamDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final leagueController = TextEditingController();
    String selectedSport = 'Football';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Favorite Team'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Team Name',
                  hintText: 'e.g., Manchester United',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: leagueController,
                decoration: const InputDecoration(
                  labelText: 'League',
                  hintText: 'e.g., Premier League',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedSport,
                decoration: const InputDecoration(labelText: 'Sport'),
                items: [
                  'Football',
                  'Basketball',
                  'Tennis',
                  'Baseball',
                  'Hockey'
                ]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => selectedSport = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                // Fetch logo
                final logoUrl = await TeamLogoService.getTeamLogo(
                    nameController.text.trim(), selectedSport);

                final team = FavoriteTeam(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  sport: selectedSport,
                  league: leagueController.text.trim(),
                  logoUrl: logoUrl,
                );
                ref.read(favoritesProvider.notifier).addFavorite(team);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyFavorites({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Text('❤️', style: TextStyle(fontSize: 48)),
          ).animate().scale(curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text('No Favorite Teams',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Add your favorite teams to get quick access\nand notifications',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.outline),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus),
            label: const Text('Add Team'),
          ),
        ],
      ),
    );
  }
}

class _FavoriteTeamCard extends StatelessWidget {
  final FavoriteTeam team;
  final VoidCallback onToggleNotifications;
  final VoidCallback onRemove;

  const _FavoriteTeamCard({
    required this.team,
    required this.onToggleNotifications,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: team.logoUrl != null && team.logoUrl!.isNotEmpty
                ? Image.network(
                    team.logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildFallback(scheme, team.name),
                  )
                : _buildFallback(scheme, team.name),
          ),
        ),
        title: Text(team.name,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(team.league.isNotEmpty ? team.league : 'Unknown League'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(team.sport, style: text.labelSmall),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                team.notificationsEnabled
                    ? LucideIcons.bell
                    : LucideIcons.bellOff,
                color:
                    team.notificationsEnabled ? scheme.primary : scheme.outline,
              ),
              onPressed: onToggleNotifications,
              tooltip: team.notificationsEnabled
                  ? 'Disable notifications'
                  : 'Enable notifications',
            ),
            IconButton(
              icon: Icon(LucideIcons.trash2, color: scheme.error),
              onPressed: () => _confirmRemove(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(ColorScheme scheme, String name) {
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();
    return Container(
      color: scheme.primaryContainer,
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Team'),
        content: Text('Remove ${team.name} from favorites?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              onRemove();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
