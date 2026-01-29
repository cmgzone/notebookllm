import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notebook_llm/features/gitu/models/gitu_plugin.dart';
import 'package:notebook_llm/features/gitu/models/plugin_catalog_item.dart';
import 'package:notebook_llm/features/gitu/models/plugin_execution.dart';
import 'package:notebook_llm/features/gitu/plugins_screen.dart';
import 'package:notebook_llm/features/gitu/services/gitu_plugins_service.dart';

class FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestMarketplacePluginsService extends GituPluginsService {
  List<GituPlugin> plugins;
  final List<PluginCatalogItem> catalog;
  final Map<String, List<PluginExecution>> history;

  TestMarketplacePluginsService({
    required this.plugins,
    required this.catalog,
    required this.history,
  }) : super(FakeRef());

  @override
  Future<List<GituPlugin>> listPlugins({bool? enabled}) async {
    return plugins;
  }

  @override
  Future<List<PluginCatalogItem>> listCatalog({String? q, String? tag, int limit = 50, int offset = 0}) async {
    return catalog;
  }

  @override
  Future<GituPlugin> installFromCatalog(String catalogId, {Map<String, dynamic>? config, bool enabled = true}) async {
    final item = catalog.firstWhere((c) => c.id == catalogId);
    final plugin = GituPlugin(
      id: 'installed-1',
      userId: 'u1',
      name: item.name,
      description: item.description,
      code: 'module.exports = async () => ({ ok: true });',
      entrypoint: item.entrypoint,
      config: config ?? const {},
      sourceCatalogId: item.id,
      sourceCatalogVersion: item.version,
      enabled: enabled,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    plugins = [plugin, ...plugins];
    return plugin;
  }
}

void main() {
  testWidgets('Marketplace installs a plugin', (tester) async {
    final service = TestMarketplacePluginsService(
      plugins: [],
      catalog: const [
        PluginCatalogItem(
          id: 'c1',
          slug: 'echo',
          name: 'Echo Plugin',
          description: 'Returns input',
          entrypoint: 'run',
          version: '1.0.0',
          author: 'Notebook',
          tags: ['test'],
        ),
      ],
      history: {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gituPluginsServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: GituPluginsScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No plugins yet'), findsOneWidget);

    await tester.tap(find.text('Marketplace'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();

    expect(find.text('Echo Plugin'), findsOneWidget);
  });
}

