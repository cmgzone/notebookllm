import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_service.dart';
import '../models/gitu_plugin.dart';
import '../models/plugin_catalog_item.dart';
import '../models/plugin_execution.dart';

final gituPluginsServiceProvider = Provider<GituPluginsService>((ref) {
  return GituPluginsService(ref);
});

final gituPluginsProvider = FutureProvider.autoDispose<List<GituPlugin>>((ref) async {
  final service = ref.watch(gituPluginsServiceProvider);
  return service.listPlugins();
});

class GituPluginsService {
  final Ref _ref;

  GituPluginsService(this._ref);

  Future<List<GituPlugin>> listPlugins({bool? enabled}) async {
    final apiService = _ref.read(apiServiceProvider);
    final query = <String, dynamic>{};
    if (enabled != null) query['enabled'] = enabled ? 'true' : 'false';
    final response = await apiService.get<Map<String, dynamic>>(
      '/gitu/plugins',
      queryParameters: query.isEmpty ? null : query,
    );
    final List<dynamic> plugins = response['plugins'] ?? const [];
    return plugins.whereType<Map>().map((m) => GituPlugin.fromJson(Map<String, dynamic>.from(m))).toList();
  }

  Future<GituPlugin> createPlugin(Map<String, dynamic> payload) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.post<Map<String, dynamic>>('/gitu/plugins', payload);
    return GituPlugin.fromJson(Map<String, dynamic>.from(response['plugin']));
  }

  Future<List<PluginCatalogItem>> listCatalog({String? q, String? tag, int limit = 50, int offset = 0}) async {
    final apiService = _ref.read(apiServiceProvider);
    final query = <String, dynamic>{'limit': '$limit', 'offset': '$offset'};
    if (q != null && q.trim().isNotEmpty) query['q'] = q.trim();
    if (tag != null && tag.trim().isNotEmpty) query['tag'] = tag.trim();

    final response = await apiService.get<Map<String, dynamic>>(
      '/gitu/plugins/catalog',
      queryParameters: query,
    );
    final List<dynamic> items = response['catalog'] ?? const [];
    return items.whereType<Map>().map((m) => PluginCatalogItem.fromJson(Map<String, dynamic>.from(m))).toList();
  }

  Future<GituPlugin> installFromCatalog(String catalogId, {Map<String, dynamic>? config, bool enabled = true}) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.post<Map<String, dynamic>>('/gitu/plugins/catalog/$catalogId/install', {
      'enabled': enabled,
      if (config != null) 'config': config,
    });
    return GituPlugin.fromJson(Map<String, dynamic>.from(response['plugin']));
  }

  Future<GituPlugin> updatePlugin(String id, Map<String, dynamic> payload) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.put<Map<String, dynamic>>('/gitu/plugins/$id', payload);
    return GituPlugin.fromJson(Map<String, dynamic>.from(response['plugin']));
  }

  Future<void> deletePlugin(String id) async {
    final apiService = _ref.read(apiServiceProvider);
    await apiService.delete<Map<String, dynamic>>('/gitu/plugins/$id');
  }

  Future<Map<String, dynamic>> validatePlugin(Map<String, dynamic> payload) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.post<Map<String, dynamic>>('/gitu/plugins/validate', payload);
    return Map<String, dynamic>.from(response['result']);
  }

  Future<Map<String, dynamic>> executePlugin(
    String id, {
    required Map<String, dynamic> input,
    required Map<String, dynamic> context,
    int? timeoutMs,
  }) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.post<Map<String, dynamic>>('/gitu/plugins/$id/execute', {
      'input': input,
      'context': context,
      if (timeoutMs != null) 'timeoutMs': timeoutMs,
    });
    return Map<String, dynamic>.from(response['result']);
  }

  Future<List<PluginExecution>> listExecutions(String id, {int limit = 50, int offset = 0}) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.get<Map<String, dynamic>>(
      '/gitu/plugins/$id/executions',
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final List<dynamic> logs = response['executions'] ?? const [];
    return logs.whereType<Map>().map((m) => PluginExecution.fromJson(Map<String, dynamic>.from(m))).toList();
  }

  static Map<String, dynamic> tryParseJsonObject(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return {};
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('JSON must be an object');
  }
}
