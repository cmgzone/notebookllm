class SwarmMission {
  final String id;
  final String userId;
  final String name;
  final String objective;
  final String status;
  final Map<String, dynamic> context;
  final Map<String, dynamic> artifacts;
  final int agentCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  SwarmMission({
    required this.id,
    required this.userId,
    required this.name,
    required this.objective,
    required this.status,
    required this.context,
    required this.artifacts,
    required this.agentCount,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory SwarmMission.fromJson(Map<String, dynamic> json) {
    return SwarmMission(
      id: json['id'],
      userId: json['userId'] ?? '',
      name: json['name'] ?? 'Unknown Mission',
      objective: json['objective'] ?? '',
      status: json['status'] ?? 'planning',
      context: json['context'] ?? {},
      artifacts: json['artifacts'] ?? {},
      agentCount: json['agentCount'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
    );
  }

  bool get isActive => status == 'active' || status == 'planning';
}

class SwarmPlan {
  final String objective;
  final List<SwarmTask> tasks;
  final String strategy;

  SwarmPlan({
    required this.objective,
    required this.tasks,
    required this.strategy,
  });

  factory SwarmPlan.fromJson(Map<String, dynamic> json) {
    return SwarmPlan(
      objective: json['objective'] ?? '',
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((t) => SwarmTask.fromJson(t))
              .toList() ??
          [],
      strategy: json['strategy'] ?? 'parallel',
    );
  }
}

class SwarmTask {
  final String id;
  final String description;
  final String role;
  final List<String> dependencies;
  final String? agentId;
  final String status;

  SwarmTask({
    required this.id,
    required this.description,
    required this.role,
    required this.dependencies,
    this.agentId,
    required this.status,
  });

  factory SwarmTask.fromJson(Map<String, dynamic> json) {
    return SwarmTask(
      id: json['id'],
      description: json['description'] ?? '',
      role: json['role'] ?? 'generalist',
      dependencies: List<String>.from(json['dependencies'] ?? []),
      agentId: json['agentId'],
      status: json['status'] ?? 'pending',
    );
  }
}
