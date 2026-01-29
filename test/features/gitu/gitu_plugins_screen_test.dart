import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notebook_llm/features/gitu/models/gitu_plugin.dart';
import 'package:notebook_llm/features/gitu/models/plugin_execution.dart';
import 'package:notebook_llm/features/gitu/plugins_screen.dart';
import 'package:notebook_llm/features/gitu/services/gitu_plugins_service.dart';

class FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestGituPluginsService extends GituPluginsService {
  List<GituPlugin> plugins;
  final Map<String, List<PluginExecution>> history;
  int _counter = 1;

  TestGituPluginsService({
    required this.plugins,
    required this.history,
  }) : super(FakeRef());

  @override
  Future<List<GituPlugin>> listPlugins({bool? enabled}) async {
    if (enabled == null) return plugins;
    return plugins.where((p) => p.enabled == enabled).toList();
  }

  @override
  Future<Map<String, dynamic>> validatePlugin(Map<String, dynamic> payload) async {
    final errors = <String>[];
    final name = payload['name'];
    final code = payload['code'];
    if (name is! String || name.trim().length < 2) errors.add('NAME_REQUIRED');
    if (code is! String || code.trim().length < 10) errors.add('CODE_REQUIRED');
    return {'valid': errors.isEmpty, 'errors': errors};
  }

  @override
  Future<GituPlugin> createPlugin(Map<String, dynamic> payload) async {
    final id = 'p${_counter++}';
    final plugin = GituPlugin(
      id: id,
      userId: 'u1',
      name: (payload['name'] as String?) ?? '',
      description: payload['description'] as String?,
      code: (payload['code'] as String?) ?? '',
      entrypoint: (payload['entrypoint'] as String?) ?? 'run',
      config: Map<String, dynamic>.from(payload['config'] ?? const {}),
      sourceCatalogId: null,
      sourceCatalogVersion: null,
      enabled: payload['enabled'] == true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    plugins = [plugin, ...plugins];
    return plugin;
  }

  @override
  Future<GituPlugin> updatePlugin(String id, Map<String, dynamic> payload) async {
    final idx = plugins.indexWhere((p) => p.id == id);
    final current = plugins[idx];
    final updated = GituPlugin(
      id: current.id,
      userId: current.userId,
      name: (payload['name'] as String?) ?? current.name,
      description: payload['description'] as String? ?? current.description,
      code: (payload['code'] as String?) ?? current.code,
      entrypoint: (payload['entrypoint'] as String?) ?? current.entrypoint,
      config: Map<String, dynamic>.from(payload['config'] ?? current.config),
      sourceCatalogId: current.sourceCatalogId,
      sourceCatalogVersion: current.sourceCatalogVersion,
      enabled: payload['enabled'] == true,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    plugins = [
      for (final p in plugins)
        if (p.id == id) updated else p,
    ];
    return updated;
  }

  @override
  Future<void> deletePlugin(String id) async {
    plugins = plugins.where((p) => p.id != id).toList();
  }

  @override
  Future<Map<String, dynamic>> executePlugin(
    String id, {
    required Map<String, dynamic> input,
    required Map<String, dynamic> context,
    int? timeoutMs,
  }) async {
    final result = {
      'success': true,
      'result': {'ok': true},
      'logs': const [],
      'durationMs': 1,
    };
    final exec = PluginExecution(
      id: 'e${DateTime.now().millisecondsSinceEpoch}',
      success: true,
      durationMs: 1,
      result: result,
      error: null,
      logs: const [],
      executedAt: DateTime.now(),
    );
    history[id] = [exec, ...(history[id] ?? const [])];
    return result;
  }

  @override
  Future<List<PluginExecution>> listExecutions(String id, {int limit = 50, int offset = 0}) async {
    final items = history[id] ?? const [];
    final start = offset.clamp(0, items.length);
    final end = (start + limit).clamp(start, items.length);
    return items.sublist(start, end);
  }
}

void main() {
  testWidgets('Plugins screen lists plugins and allows creating a plugin', (tester) async {
    final svc = TestGituPluginsService(
      plugins: [
        GituPlugin(
          id: 'p0',
          userId: 'u1',
          name: 'Existing Plugin',
          description: 'desc',
          code: 'module.exports = async () => ({ ok: true });',
          entrypoint: 'run',
          config: const {},
          sourceCatalogId: null,
          sourceCatalogVersion: null,
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
      history: {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gituPluginsServiceProvider.overrideWithValue(svc),
        ],
        child: const MaterialApp(home: GituPluginsScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Plugins'), findsOneWidget);
    expect(find.text('Existing Plugin'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'My Plugin');
    await tester.enterText(fields.at(4), 'module.exports = async () => ({ ok: true });');

    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('My Plugin'), findsOneWidget);
  });
}
