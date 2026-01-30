import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';

// ================== MODEL ==================

class GituAgent {
  final String id;
  final String userId;
  final String? parentAgentId;
  final String task;
  final String status; // 'pending', 'active', 'completed', 'failed', 'paused'
  final Map<String, dynamic> memory;
  final Map<String, dynamic>? result;
  final DateTime createdAt;
  final DateTime updatedAt;

  GituAgent({
    required this.id,
    required this.userId,
    this.parentAgentId,
    required this.task,
    required this.status,
    required this.memory,
    this.result,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GituAgent.fromJson(Map<String, dynamic> json) {
    return GituAgent(
      id: json['id'],
      userId: json['userId'] ?? json['user_id'],
      parentAgentId: json['parentAgentId'] ?? json['parent_agent_id'],
      task: json['task'],
      status: json['status'],
      memory: Map<String, dynamic>.from(json['memory'] ?? {}),
      result: json['result'] != null ? Map<String, dynamic>.from(json['result']) : null,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      updatedAt: DateTime.parse(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

// ================== PROVIDERS ==================

final gituAgentsServiceProvider = Provider<GituAgentsService>((ref) {
  return GituAgentsService(ref);
});

final gituAgentsProvider = FutureProvider.autoDispose<List<GituAgent>>((ref) async {
  final service = ref.watch(gituAgentsServiceProvider);
  return service.listAgents();
});

final gituAgentDetailProvider = FutureProvider.autoDispose.family<GituAgent, String>((ref, id) async {
  final service = ref.watch(gituAgentsServiceProvider);
  return service.getAgent(id);
});

// ================== SERVICE ==================

class GituAgentsService {
  final Ref _ref;

  GituAgentsService(this._ref);

  Future<List<GituAgent>> listAgents() async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.get<Map<String, dynamic>>('/gitu/agents');
    final List<dynamic> list = response['agents'] ?? [];
    return list.map((m) => GituAgent.fromJson(m)).toList();
  }

  Future<GituAgent> spawnAgent(String task, {String? parentAgentId, Map<String, dynamic>? memory}) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.post<Map<String, dynamic>>('/gitu/agents', {
      'task': task,
      if (parentAgentId != null) 'parentAgentId': parentAgentId,
      if (memory != null) 'memory': memory,
    });
    return GituAgent.fromJson(response['agent']);
  }

  Future<GituAgent> getAgent(String id) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.get<Map<String, dynamic>>('/gitu/agents/$id');
    return GituAgent.fromJson(response['agent']);
  }
}
