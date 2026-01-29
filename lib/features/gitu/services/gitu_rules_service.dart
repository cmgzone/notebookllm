import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../models/automation_rule.dart';
import '../models/rule_execution.dart';

final gituRulesServiceProvider = Provider<GituRulesService>((ref) {
  return GituRulesService(ref);
});

final gituRulesProvider = FutureProvider.autoDispose<List<AutomationRule>>((ref) async {
  final service = ref.watch(gituRulesServiceProvider);
  return service.listRules();
});

class GituRulesService {
  final Ref _ref;

  GituRulesService(this._ref);

  Future<List<AutomationRule>> listRules({bool? enabled}) async {
    final apiService = _ref.read(apiServiceProvider);
    final query = <String, dynamic>{};
    if (enabled != null) query['enabled'] = enabled ? 'true' : 'false';

    final response = await apiService.get<Map<String, dynamic>>(
      '/gitu/rules',
      queryParameters: query.isEmpty ? null : query,
    );
    final List<dynamic> rules = response['rules'] ?? const [];
    return rules.whereType<Map>().map((m) => AutomationRule.fromJson(Map<String, dynamic>.from(m))).toList();
  }

  Future<AutomationRule> getRule(String id) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.get<Map<String, dynamic>>('/gitu/rules/$id');
    return AutomationRule.fromJson(Map<String, dynamic>.from(response['rule']));
  }

  Future<AutomationRule> createRule(Map<String, dynamic> payload) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.post<Map<String, dynamic>>('/gitu/rules', payload);
    return AutomationRule.fromJson(Map<String, dynamic>.from(response['rule']));
  }

  Future<AutomationRule> updateRule(String id, Map<String, dynamic> payload) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.put<Map<String, dynamic>>('/gitu/rules/$id', payload);
    return AutomationRule.fromJson(Map<String, dynamic>.from(response['rule']));
  }

  Future<void> deleteRule(String id) async {
    final apiService = _ref.read(apiServiceProvider);
    await apiService.delete<Map<String, dynamic>>('/gitu/rules/$id');
  }

  Future<Map<String, dynamic>> validateRule(Map<String, dynamic> payload) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.post<Map<String, dynamic>>('/gitu/rules/validate', payload);
    return Map<String, dynamic>.from(response['result']);
  }

  Future<Map<String, dynamic>> executeRule(String id, {required Map<String, dynamic> context}) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.post<Map<String, dynamic>>('/gitu/rules/$id/execute', {
      'context': context,
    });
    return Map<String, dynamic>.from(response['result']);
  }

  Future<List<RuleExecution>> listExecutions(String id, {int limit = 50, int offset = 0}) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.get<Map<String, dynamic>>(
      '/gitu/rules/$id/executions',
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final List<dynamic> logs = response['executions'] ?? const [];
    return logs.whereType<Map>().map((m) => RuleExecution.fromJson(Map<String, dynamic>.from(m))).toList();
  }

  static Map<String, dynamic> tryParseJsonObject(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return {};
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Context must be a JSON object');
  }
}
