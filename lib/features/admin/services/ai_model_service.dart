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
  });

  factory AIModel.fromMap(Map<String, dynamic> map) {
    return AIModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      modelId: map['model_id'] ?? '',
      provider: map['provider'] ?? '',
      description: map['description'],
      costInput: (map['cost_input'] as num?)?.toDouble() ?? 0.0,
      costOutput: (map['cost_output'] as num?)?.toDouble() ?? 0.0,
      contextWindow: (map['context_window'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] ?? true,
      isPremium: map['is_premium'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'modelId': modelId,
      'provider': provider,
      'description': description,
      'costInput': costInput,
      'costOutput': costOutput,
      'contextWindow': contextWindow,
      'isActive': isActive,
      'isPremium': isPremium,
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
