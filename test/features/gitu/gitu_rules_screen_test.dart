import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notebook_llm/features/gitu/models/automation_rule.dart';
import 'package:notebook_llm/features/gitu/models/rule_execution.dart';
import 'package:notebook_llm/features/gitu/rules_screen.dart';
import 'package:notebook_llm/features/gitu/services/gitu_rules_service.dart';

class FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestGituRulesService extends GituRulesService {
  List<AutomationRule> rules;
  final Map<String, List<RuleExecution>> history;
  int _counter = 1;

  TestGituRulesService({
    required this.rules,
    required this.history,
  }) : super(FakeRef());

  @override
  Future<List<AutomationRule>> listRules({bool? enabled}) async {
    if (enabled == null) return rules;
    return rules.where((r) => r.enabled == enabled).toList();
  }

  @override
  Future<Map<String, dynamic>> validateRule(Map<String, dynamic> payload) async {
    final errors = <String>[];
    final name = payload['name'];
    if (name is! String || name.trim().length < 2) errors.add('NAME_REQUIRED');
    final actions = payload['actions'];
    if (actions is! List || actions.isEmpty) errors.add('ACTIONS_INVALID');
    final firstAction = actions is List && actions.isNotEmpty ? actions.first : null;
    if (firstAction is Map && (firstAction['type'] == 'files.list' || firstAction['type'] == 'files.read' || firstAction['type'] == 'files.write')) {
      final p = firstAction['path'];
      if (p is! String || p.trim().isEmpty) errors.add('ACTIONS_INVALID');
    }
    return {'valid': errors.isEmpty, 'errors': errors};
  }

  @override
  Future<AutomationRule> createRule(Map<String, dynamic> payload) async {
    final id = 'r${_counter++}';
    final rule = AutomationRule(
      id: id,
      userId: 'u1',
      name: (payload['name'] as String?) ?? '',
      description: payload['description'] as String?,
      trigger: Map<String, dynamic>.from(payload['trigger'] ?? const {'type': 'manual'}),
      conditions: (payload['conditions'] as List?)?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() ?? const [],
      actions: (payload['actions'] as List?)?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() ?? const [],
      enabled: payload['enabled'] == true,
      createdAt: DateTime.now(),
    );
    rules = [rule, ...rules];
    return rule;
  }

  @override
  Future<AutomationRule> updateRule(String id, Map<String, dynamic> payload) async {
    final idx = rules.indexWhere((r) => r.id == id);
    final current = rules[idx];
    final updated = AutomationRule(
      id: current.id,
      userId: current.userId,
      name: (payload['name'] as String?) ?? current.name,
      description: payload['description'] as String? ?? current.description,
      trigger: Map<String, dynamic>.from(payload['trigger'] ?? current.trigger),
      conditions: (payload['conditions'] as List?)?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() ?? current.conditions,
      actions: (payload['actions'] as List?)?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() ?? current.actions,
      enabled: payload['enabled'] == true,
      createdAt: current.createdAt,
    );
    rules = [
      for (final r in rules)
        if (r.id == id) updated else r,
    ];
    return updated;
  }

  @override
  Future<void> deleteRule(String id) async {
    rules = rules.where((r) => r.id != id).toList();
  }

  @override
  Future<Map<String, dynamic>> executeRule(String id, {required Map<String, dynamic> context}) async {
    final result = {
      'ruleId': id,
      'matched': true,
      'conditionResults': const [],
      'actionResults': const [],
    };
    final exec = RuleExecution(
      id: 'e${DateTime.now().millisecondsSinceEpoch}',
      matched: true,
      success: true,
      result: result,
      error: null,
      executedAt: DateTime.now(),
    );
    history[id] = [exec, ...(history[id] ?? const [])];
    return result;
  }

  @override
  Future<List<RuleExecution>> listExecutions(String id, {int limit = 50, int offset = 0}) async {
    final items = history[id] ?? const [];
    final start = offset.clamp(0, items.length);
    final end = (start + limit).clamp(start, items.length);
    return items.sublist(start, end);
  }
}

void main() {
  testWidgets('Rules screen lists rules and allows creating a rule', (tester) async {
    final svc = TestGituRulesService(
      rules: [
        AutomationRule(
          id: 'r0',
          userId: 'u1',
          name: 'Existing Rule',
          description: 'desc',
          trigger: const {'type': 'manual'},
          conditions: const [],
          actions: const [
            {'type': 'files.list', 'path': 'tmp'}
          ],
          enabled: true,
          createdAt: DateTime.now(),
        ),
      ],
      history: {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gituRulesServiceProvider.overrideWithValue(svc),
        ],
        child: const MaterialApp(home: GituRulesScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('Existing Rule'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'My New Rule');
    await tester.enterText(find.byType(TextFormField).first, 'tmp/new');

    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('My New Rule'), findsOneWidget);
  });
}
