import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';

final aiModelServiceProvider = Provider<AIModelService>((ref) {
  return AIModelService(ref);
});

class AIModel {
  final String id;
  final String name;
  final String modelId;
  final String provider;
  final String? description;
  final double costInput;
  final double costOutput;
  final int contextWindow;
  final bool isActive;
  final bool isPremium;
  final bool canAccess; // Whether current user can use this model

  AIModel({
    required this.id,
    required this.name,
    required this.modelId,
    required this.provider,
    this.description,
    this.costInput = 0,
    this.costOutput = 0,
    this.contextWindow = 0,
    this.isActive = true,
    this.isPremium = false,
    this.canAccess = true, // Default to true for backward compatibility
  });

  factory AIModel.fromMap(Map<String, dynamic> map) {
    return AIModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      modelId: map['model_id'] ?? map['modelId'] ?? '',
      provider: map['provider'] ?? '',
      description: map['description'],
      costInput:
          (map['cost_input'] ?? map['costInput'] as num?)?.toDouble() ?? 0.0,
      costOutput:
          (map['cost_output'] ?? map['costOutput'] as num?)?.toDouble() ?? 0.0,
      contextWindow:
          (map['context_window'] ?? map['contextWindow'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] ?? map['isActive'] ?? true,
      isPremium: map['is_premium'] ?? map['isPremium'] ?? false,
      canAccess: map['can_access'] ?? map['canAccess'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'model_id': modelId,
      'provider': provider,
      'description': description,
      'cost_input': costInput,
      'cost_output': costOutput,
      'context_window': contextWindow,
      'is_active': isActive,
      'is_premium': isPremium,
    };
  }
}

class AIModelService {
  final Ref ref;

  AIModelService(this.ref);

  ApiService get _api => ref.read(apiServiceProvider);

  Future<List<AIModel>> listModels() async {
    final results = await _api.getAIModels();
    return results.map((m) => AIModel.fromMap(m)).toList();
  }

  Future<void> addModel(AIModel model) async {
    await _api.addAIModel(model.toMap());
  }

  Future<void> updateModel(AIModel model) async {
    await _api.updateAIModel(model.id, model.toMap());
  }

  Future<void> deleteModel(String id) async {
    await _api.deleteAIModel(id);
  }

  // Table is managed by backend, no need to create it from Flutter
  Future<void> ensureTableExists() async {
    // No-op - backend manages tables
  }
}
