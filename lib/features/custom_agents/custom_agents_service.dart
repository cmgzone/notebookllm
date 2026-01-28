import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'custom_agent.dart';

class CustomAgentsService {
  static const _agentsKey = 'custom_agents_v1';
  static const _selectedAgentIdKey = 'custom_agents_selected_id_v1';

  Future<List<CustomAgent>> loadAgents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_agentsKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => CustomAgent.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.id.isNotEmpty && a.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAgents(List<CustomAgent> agents) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(agents.map((a) => a.toJson()).toList());
    await prefs.setString(_agentsKey, encoded);
  }

  Future<String?> getSelectedAgentId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_selectedAgentIdKey);
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<void> setSelectedAgentId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_selectedAgentIdKey);
      return;
    }
    await prefs.setString(_selectedAgentIdKey, id);
  }
}
