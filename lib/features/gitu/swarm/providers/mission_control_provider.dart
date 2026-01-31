import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';
import '../../../../core/api/api_service.dart';

import '../models/mission.dart';

final missionControlProvider = StateNotifierProvider<MissionControlNotifier,
    AsyncValue<List<SwarmMission>>>((ref) {
  return MissionControlNotifier(ref);
});

final activeMissionProvider = Provider<SwarmMission?>((ref) {
  final missions = ref.watch(missionControlProvider).value;
  if (missions == null || missions.isEmpty) return null;
  // Return the most recently updated active mission
  return missions.first; // Already sorted by backend
});

class MissionControlNotifier
    extends StateNotifier<AsyncValue<List<SwarmMission>>> {
  final Ref ref;
  Timer? _pollingTimer;

  MissionControlNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchActiveMissions();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Only poll if there's no error and we are mounted (StateNotifier doesn't have mounted check but we can check if disposed by keeping track or just try-catch)
      // Actually, StateNotifier is disposed when provider is disposed.
      fetchActiveMissions(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchActiveMissions({bool silent = false}) async {
    if (!silent) state = const AsyncValue.loading();

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/gitu/mission/active');

      if (response['success'] == true) {
        final List<dynamic> list = response['missions'];
        final missions =
            list.map((json) => SwarmMission.fromJson(json)).toList();
        state = AsyncValue.data(missions);
      }
    } catch (e, stack) {
      if (!silent) state = AsyncValue.error(e, stack);
    }
  }

  Future<SwarmMission?> startMission(String objective) async {
    try {
      final api = ref.read(apiServiceProvider);
      final response =
          await api.post('/gitu/mission', {'objective': objective});

      if (response['success'] == true) {
        await fetchActiveMissions();
        return SwarmMission.fromJson(response['mission']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
