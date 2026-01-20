import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import 'agent_skill.dart';

class AgentSkillsNotifier extends StateNotifier<AsyncValue<List<AgentSkill>>> {
  final Ref ref;

  AgentSkillsNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadSkills();
  }

  Future<void> loadSkills() async {
    try {
      state = const AsyncValue.loading();
      final api = ref.read(apiServiceProvider);
      final data = await api.getAgentSkills();
      final skills = data.map((json) => AgentSkill.fromJson(json)).toList();
      state = AsyncValue.data(skills);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createSkill({
    required String name,
    required String content,
    String? description,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.createAgentSkill(
        name: name,
        content: content,
        description: description,
        parameters: parameters,
      );
      // Reload list
      await loadSkills();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateSkill({
    required String id,
    String? name,
    String? content,
    String? description,
    Map<String, dynamic>? parameters,
    bool? isActive,
  }) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateAgentSkill(
        id: id,
        name: name,
        content: content,
        description: description,
        parameters: parameters,
        isActive: isActive,
      );
      await loadSkills();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSkill(String id) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteAgentSkill(id);

      // Optimistic update
      state.whenData((skills) {
        state = AsyncValue.data(skills.where((s) => s.id != id).toList());
      });
      // Or reload to be safe
      // await loadSkills();
    } catch (e) {
      rethrow;
    }
  }
}

final agentSkillsProvider =
    StateNotifierProvider<AgentSkillsNotifier, AsyncValue<List<AgentSkill>>>(
        (ref) {
  return AgentSkillsNotifier(ref);
});
