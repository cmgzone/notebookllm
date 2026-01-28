import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'custom_agent.dart';
import 'custom_agents_service.dart';

class CustomAgentsState {
  final bool isLoading;
  final List<CustomAgent> agents;
  final String? selectedAgentId;
  final String? error;

  const CustomAgentsState({
    required this.isLoading,
    required this.agents,
    required this.selectedAgentId,
    required this.error,
  });

  factory CustomAgentsState.initial() => const CustomAgentsState(
        isLoading: true,
        agents: [],
        selectedAgentId: null,
        error: null,
      );

  CustomAgentsState copyWith({
    bool? isLoading,
    List<CustomAgent>? agents,
    String? selectedAgentId,
    bool clearSelectedAgentId = false,
    String? error,
    bool clearError = false,
  }) {
    return CustomAgentsState(
      isLoading: isLoading ?? this.isLoading,
      agents: agents ?? this.agents,
      selectedAgentId: clearSelectedAgentId ? null : (selectedAgentId ?? this.selectedAgentId),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CustomAgentsNotifier extends StateNotifier<CustomAgentsState> {
  CustomAgentsNotifier(this.ref) : super(CustomAgentsState.initial()) {
    load();
  }

  final Ref ref;
  final _service = CustomAgentsService();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final agents = await _service.loadAgents();
      final selectedId = await _service.getSelectedAgentId();
      final normalizedSelectedId = agents.any((a) => a.id == selectedId)
          ? selectedId
          : null;
      if (normalizedSelectedId != selectedId) {
        await _service.setSelectedAgentId(normalizedSelectedId);
      }
      state = state.copyWith(
        isLoading: false,
        agents: agents,
        selectedAgentId: normalizedSelectedId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSelectedAgent(String? id) async {
    await _service.setSelectedAgentId(id);
    state = state.copyWith(selectedAgentId: id);
  }

  Future<void> upsert(CustomAgent agent) async {
    final updated = [...state.agents];
    final index = updated.indexWhere((a) => a.id == agent.id);
    if (index >= 0) {
      updated[index] = agent;
    } else {
      updated.add(agent);
    }
    await _service.saveAgents(updated);
    state = state.copyWith(agents: updated);
  }

  Future<void> delete(String id) async {
    final updated = state.agents.where((a) => a.id != id).toList();
    await _service.saveAgents(updated);
    if (state.selectedAgentId == id) {
      await _service.setSelectedAgentId(null);
      state = state.copyWith(agents: updated, clearSelectedAgentId: true);
      return;
    }
    state = state.copyWith(agents: updated);
  }

  String generateId() {
    final rand = Random.secure();
    final value = List<int>.generate(10, (_) => rand.nextInt(16));
    return value.map((b) => b.toRadixString(16)).join();
  }
}

final customAgentsProvider =
    StateNotifierProvider<CustomAgentsNotifier, CustomAgentsState>((ref) {
  return CustomAgentsNotifier(ref);
});
