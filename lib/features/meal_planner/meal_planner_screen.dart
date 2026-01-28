import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'meal.dart';
import 'meal_planner_provider.dart';
import 'add_meal_sheet.dart';

class MealPlannerScreen extends ConsumerStatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  ConsumerState<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends ConsumerState<MealPlannerScreen> {
  DateTime _selectedWeekStart = DateTime.now();
  final _dietaryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _getWeekStart(DateTime.now());
  }

  DateTime _getWeekStart(DateTime date) {
    final diff = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day - diff);
  }

  @override
  void dispose() {
    _dietaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealPlannerProvider);
    final scheme = Theme.of(context).colorScheme;

    final weekPlan = ref
        .read(mealPlannerProvider.notifier)
        .getOrCreateWeekPlan(_selectedWeekStart);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Planner'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.sparkles),
            tooltip: 'AI Generate Plan',
            onPressed: state.isLoading ? null : _showGenerateDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Week selector
          _WeekSelector(
            weekStart: _selectedWeekStart,
            onPrevious: () => setState(() {
              _selectedWeekStart =
                  _selectedWeekStart.subtract(const Duration(days: 7));
            }),
            onNext: () => setState(() {
              _selectedWeekStart =
                  _selectedWeekStart.add(const Duration(days: 7));
            }),
            onToday: () => setState(() {
              _selectedWeekStart = _getWeekStart(DateTime.now());
            }),
          ),

          // Loading indicator
          if (state.isLoading) const LinearProgressIndicator(),

          // Error message
          if (state.error != null)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(state.error!,
                          style: TextStyle(color: scheme.error))),
                ],
              ),
            ),

          // Timetable
          Expanded(
            child: _MealTimetable(
              weekPlan: weekPlan,
              onMealTap: _showMealDetails,
              onAddMeal: _showAddMealSheet,
            ),
          ),
        ],
      ),
    );
  }

  void _showGenerateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Meal Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dietaryController,
              decoration: const InputDecoration(
                labelText: 'Dietary Preferences (optional)',
                hintText: 'e.g., vegetarian, low-carb, gluten-free',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'AI will generate a complete meal plan for the selected week.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(mealPlannerProvider.notifier).generateWeeklyPlan(
                    dietaryPreferences: _dietaryController.text.isEmpty
                        ? null
                        : _dietaryController.text,
                    weekStart: _selectedWeekStart,
                  );
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  void _showMealDetails(Meal meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _MealDetailsSheet(meal: meal),
      ),
    );
  }

  void _showAddMealSheet(DateTime date, MealType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: AddMealSheet(
          date: date,
          mealType: type,
          savedMeals: ref.read(mealPlannerProvider).savedMeals,
        ),
      ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  final DateTime weekStart;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _WeekSelector({
    required this.weekStart,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weekEnd = weekStart.add(const Duration(days: 6));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onToday,
              child: Text(
                '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _MealTimetable extends StatelessWidget {
  final WeeklyMealPlan weekPlan;
  final Function(Meal) onMealTap;
  final Function(DateTime, MealType) onAddMeal;

  const _MealTimetable({
    required this.weekPlan,
    required this.onMealTap,
    required this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 8,
          headingRowHeight: 48,
          dataRowMinHeight: 80,
          dataRowMaxHeight: 100,
          columns: [
            const DataColumn(label: SizedBox(width: 70, child: Text('Time'))),
            ...List.generate(7, (i) {
              final date = weekPlan.weekStart.add(Duration(days: i));
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              return DataColumn(
                label: Container(
                  width: 90,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: isToday
                      ? BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(days[i],
                          style: TextStyle(
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? scheme.primary : null,
                          )),
                      Text('${date.day}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              );
            }),
          ],
          rows: MealType.values.map((type) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 70,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(type.icon, size: 18),
                        Text(type.displayName,
                            style: const TextStyle(fontSize: 11)),
                        Text(type.timeRange,
                            style: TextStyle(
                              fontSize: 9,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            )),
                      ],
                    ),
                  ),
                ),
                ...List.generate(7, (i) {
                  final day = weekPlan.days[i];
                  final meal = day.meals[type];
                  return DataCell(
                    _MealCell(
                      meal: meal,
                      onTap: meal != null ? () => onMealTap(meal) : null,
                      onAdd: () => onAddMeal(day.date, type),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MealCell extends StatelessWidget {
  final Meal? meal;
  final VoidCallback? onTap;
  final VoidCallback onAdd;

  const _MealCell({
    this.meal,
    this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (meal == null) {
      return InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 90,
          height: 70,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.add, color: scheme.outline),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 90,
        height: 70,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meal!.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '${meal!.calories} cal',
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealDetailsSheet extends StatelessWidget {
  final Meal meal;

  const _MealDetailsSheet({required this.meal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(meal.type.icon, size: 28, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meal.name, style: text.titleLarge),
                      Text(meal.type.displayName, style: text.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${meal.calories} cal', style: text.labelLarge),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(meal.description, style: text.bodyMedium),
            if (meal.ingredients.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Ingredients', style: text.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: meal.ingredients
                    .map((ing) => Chip(
                          label: Text(ing),
                          backgroundColor: scheme.surfaceContainerHighest,
                        ))
                    .toList(),
              ),
            ],
            if (meal.recipe != null) ...[
              const SizedBox(height: 20),
              Text('Recipe', style: text.titleMedium),
              const SizedBox(height: 8),
              Text(meal.recipe!, style: text.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
