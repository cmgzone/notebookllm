import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'meal.dart';
import 'meal_planner_provider.dart';

class AddMealSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final MealType mealType;
  final List<Meal> savedMeals;

  const AddMealSheet({
    super.key,
    required this.date,
    required this.mealType,
    required this.savedMeals,
  });

  @override
  ConsumerState<AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<AddMealSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _ingredientsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _caloriesController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(widget.mealType.icon, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Add ${widget.mealType.displayName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Create New'),
                Tab(text: 'From Saved'),
              ],
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CreateNewTab(
                    scrollController: scrollController,
                    nameController: _nameController,
                    descController: _descController,
                    caloriesController: _caloriesController,
                    ingredientsController: _ingredientsController,
                    onSave: _createMeal,
                  ),
                  _SavedMealsTab(
                    scrollController: scrollController,
                    savedMeals: widget.savedMeals
                        .where((m) => m.type == widget.mealType)
                        .toList(),
                    onSelect: _selectSavedMeal,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createMeal() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meal name')),
      );
      return;
    }

    final meal = Meal(
      id: const Uuid().v4(),
      name: _nameController.text,
      description: _descController.text,
      type: widget.mealType,
      calories: int.tryParse(_caloriesController.text) ?? 0,
      ingredients: _ingredientsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      createdAt: DateTime.now(),
    );

    ref.read(mealPlannerProvider.notifier).setMeal(
          widget.date,
          widget.mealType,
          meal,
        );
    Navigator.pop(context);
  }

  void _selectSavedMeal(Meal meal) {
    ref.read(mealPlannerProvider.notifier).setMeal(
          widget.date,
          widget.mealType,
          meal,
        );
    Navigator.pop(context);
  }
}

class _CreateNewTab extends StatelessWidget {
  final ScrollController scrollController;
  final TextEditingController nameController;
  final TextEditingController descController;
  final TextEditingController caloriesController;
  final TextEditingController ingredientsController;
  final VoidCallback onSave;

  const _CreateNewTab({
    required this.scrollController,
    required this.nameController,
    required this.descController,
    required this.caloriesController,
    required this.ingredientsController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Meal Name *',
            hintText: 'e.g., Grilled Chicken Salad',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: descController,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Brief description of the meal',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: caloriesController,
          decoration: const InputDecoration(
            labelText: 'Calories',
            hintText: 'e.g., 450',
            border: OutlineInputBorder(),
            suffixText: 'cal',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: ingredientsController,
          decoration: const InputDecoration(
            labelText: 'Ingredients',
            hintText: 'Comma-separated: chicken, lettuce, tomatoes',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.add),
          label: const Text('Add Meal'),
        ),
      ],
    );
  }
}

class _SavedMealsTab extends StatelessWidget {
  final ScrollController scrollController;
  final List<Meal> savedMeals;
  final Function(Meal) onSelect;

  const _SavedMealsTab({
    required this.scrollController,
    required this.savedMeals,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (savedMeals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'No saved meals yet',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Create meals and save them for quick access',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: savedMeals.length,
      itemBuilder: (context, index) {
        final meal = savedMeals[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(meal.type.icon, color: scheme.primary),
            title: Text(meal.name),
            subtitle: Text('${meal.calories} cal'),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: () => onSelect(meal),
          ),
        );
      },
    );
  }
}
