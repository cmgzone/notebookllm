import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/custom_auth_service.dart';
import '../../../theme/app_theme.dart';
import '../providers/subscription_provider.dart';
import '../services/subscription_service.dart';

const String kHasSelectedPackagePref = 'has_selected_package';

class PlanSelectionScreen extends ConsumerStatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  ConsumerState<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends ConsumerState<PlanSelectionScreen> {
  String? _selectedPlanId;
  bool _submitting = false;

  Future<void> _markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHasSelectedPackagePref, true);
  }

  Future<void> _continueWithPlan(Map<String, dynamic> plan) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      // Ensure user has a subscription row (free plan auto-create if missing)
      final auth = ref.read(customAuthStateProvider);
      final user = auth.user;
      if (user == null) throw Exception('Not authenticated');

      final subSvc = ref.read(subscriptionServiceProvider);
      await subSvc.createSubscriptionForUser(user.uid);

      await _markCompleted();

      final isFree = (plan['is_free_plan'] as bool?) ?? false;
      if (!mounted) return;
      if (isFree) {
        context.go('/home');
      } else {
        context.go('/subscription');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Package'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.premiumGradient),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load plans: $err')),
        data: (plans) {
          if (plans.isEmpty) {
            return const Center(child: Text('No plans available'));
          }

          _selectedPlanId ??= _pickDefaultPlanId(plans);

          final selected =
              plans.firstWhere((p) => p['id'].toString() == _selectedPlanId);
          final isFree = (selected['is_free_plan'] as bool?) ?? false;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Pick a plan to continue. You can change it later.',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    final planId = plan['id'].toString();
                    final name = plan['name']?.toString() ?? 'Plan';
                    final desc = plan['description']?.toString() ?? '';
                    final price = _parsePrice(plan['price']);
                    final isPlanFree = (plan['is_free_plan'] as bool?) ?? false;
                    final notesLimit = _parseInt(plan['notes_limit']);
                    final mcpSources = _parseInt(plan['mcp_sources_limit']);
                    final mcpTokens = _parseInt(plan['mcp_tokens_limit']);
                    final mcpCalls = _parseInt(plan['mcp_api_calls_per_day']);

                    final selected = _selectedPlanId == planId;

                    return Card(
                      elevation: selected ? 3 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: selected
                              ? scheme.primary
                              : scheme.outline.withValues(alpha: 0.2),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _selectedPlanId = planId),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Radio<String>(
                                value: planId,
                                groupValue: _selectedPlanId,
                                onChanged: (val) =>
                                    setState(() => _selectedPlanId = val),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          isPlanFree ? 'Free' : '\$${price.toStringAsFixed(2)}/mo',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isPlanFree
                                                ? scheme.tertiary
                                                : scheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (desc.trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        desc,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.7),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                    if (notesLimit != null ||
                                        mcpSources != null ||
                                        mcpTokens != null ||
                                        mcpCalls != null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        _buildLimitsLine(
                                          notesLimit: notesLimit,
                                          mcpSources: mcpSources,
                                          mcpTokens: mcpTokens,
                                          mcpCalls: mcpCalls,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.65),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting
                          ? null
                          : () => _continueWithPlan(selected),
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isFree ? 'Continue' : 'Continue to Payment'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _pickDefaultPlanId(List<Map<String, dynamic>> plans) {
    for (final p in plans) {
      final isFree = (p['is_free_plan'] as bool?) ?? false;
      if (isFree) return p['id'].toString();
    }
    return plans.first['id'].toString();
  }

  double _parsePrice(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _buildLimitsLine({
    required int? notesLimit,
    required int? mcpSources,
    required int? mcpTokens,
    required int? mcpCalls,
  }) {
    final parts = <String>[];
    if (notesLimit != null) parts.add('Notes: $notesLimit');

    final mcpParts = <String>[];
    if (mcpSources != null) mcpParts.add('$mcpSources sources');
    if (mcpTokens != null) mcpParts.add('$mcpTokens tokens');
    if (mcpCalls != null) mcpParts.add('$mcpCalls calls/day');
    if (mcpParts.isNotEmpty) parts.add('MCP: ${mcpParts.join(', ')}');

    return parts.join('  •  ');
  }
}
