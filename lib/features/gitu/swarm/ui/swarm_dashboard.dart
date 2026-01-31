import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mission.dart';
import '../providers/mission_control_provider.dart';

class SwarmDashboard extends ConsumerStatefulWidget {
  const SwarmDashboard({super.key});

  @override
  ConsumerState<SwarmDashboard> createState() => _SwarmDashboardState();
}

class _SwarmDashboardState extends ConsumerState<SwarmDashboard> {
  final TextEditingController _objectiveController = TextEditingController();
  bool _isStarting = false;

  @override
  void dispose() {
    _objectiveController.dispose();
    super.dispose();
  }

  Future<void> _startMission() async {
    final objective = _objectiveController.text.trim();
    if (objective.isEmpty) return;

    setState(() => _isStarting = true);

    // Clear field
    _objectiveController.clear();

    // Start mission via provider
    await ref.read(missionControlProvider.notifier).startMission(objective);

    setState(() => _isStarting = false);
  }

  @override
  Widget build(BuildContext context) {
    final activeMission = ref.watch(activeMissionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gitu Swarm Intelligence'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(missionControlProvider.notifier).fetchActiveMissions(),
          ),
        ],
      ),
      body: Container(
        color: AppColors.background,
        child: Column(
          children: [
            // 1. Mission Control Header / Input
            _buildMissionControl(context, activeMission),

            const Divider(color: AppColors.divider),

            // 2. Active Mission Visualization
            Expanded(
              child: activeMission != null
                  ? _buildActiveMissionDetail(context, activeMission)
                  : _buildEmptyState(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionControl(
      BuildContext context, SwarmMission? activeMission) {
    if (activeMission != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border(
              bottom: BorderSide(color: AppColors.primary.withOpacity(0.3))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub, color: AppColors.accent),
                const SizedBox(width: 8),
                const Text(
                  'ACTIVE MISSION',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    activeMission.status.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              activeMission.objective,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.smart_toy, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  '${activeMission.agentCount} Active Agents',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  'Started ${timeAgo(activeMission.createdAt)}',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEPLOY NEW SWARM',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _objectiveController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Describe mission objective...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  onSubmitted: (_) => _startMission(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isStarting ? null : _startMission,
                icon: _isStarting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.rocket_launch),
                label: const Text('DEPLOY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMissionDetail(BuildContext context, SwarmMission mission) {
    // This would visualize the tree. For now, we list agents/tasks.
    // Since we don't have individual agent data in the mission object yet (need to fetch),
    // we'll show a placeholder visualization that pulses.

    return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Progress Bar simulation
            LinearProgressIndicator(
              value: mission.status == 'completed' ? 1.0 : null,
              backgroundColor: AppColors.cardBackground,
              color: AppColors.accent,
            ),
            const SizedBox(height: 24),

            // Visualization
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hub, size: 64, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Swarm Orchestrator Active',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Decomposing tasks and coordinating ${mission.agentCount} agents...',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // Artifacts / Outputs
            if (mission.artifacts.isNotEmpty)
              Container(
                height: 200,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MISSION ARTIFACTS',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          mission.artifacts.toString(),
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ));
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.diversity_3, size: 80, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(
            'No Active Missions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Deploy a swarm to handle complex tasks',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class AppColors {
  static const background = Color(0xFF1E1E1E);
  static const cardBackground = Color(0xFF2C2C2C);
  static const primary = Colors.deepPurple;
  static const accent = Colors.cyanAccent;
  static const divider = Colors.white24;
}
