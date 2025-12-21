import 'package:flutter/material.dart';

/// Represents a single meal
class Meal {
  final String id;
  final String name;
  final String description;
  final MealType type;
  final int calories;
  final List<String> ingredients;
  final String? recipe;
  final String? imageUrl;
  final DateTime createdAt;

  const Meal({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.calories = 0,
    this.ingredients = const [],
    this.recipe,
    this.imageUrl,
    required this.createdAt,
  });

  Meal copyWith({
    String? name,
    String? description,
    MealType? type,
    int? calories,
    List<String>? ingredients,
    String? recipe,
    String? imageUrl,
  }) {
    return Meal(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      calories: calories ?? this.calories,
      ingredients: ingredients ?? this.ingredients,
      recipe: recipe ?? this.recipe,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type.name,
        'calories': calories,
        'ingredients': ingredients,
        'recipe': recipe,
        'imageUrl': imageUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        id: json['id'],
        name: json['name'],
        description: json['description'] ?? '',
        type: MealType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => MealType.lunch,
        ),
        calories: json['calories'] ?? 0,
        ingredients: List<String>.from(json['ingredients'] ?? []),
        recipe: json['recipe'],
        imageUrl: json['imageUrl'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
    }
  }

  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.free_breakfast;
      case MealType.lunch:
        return Icons.lunch_dining;
      case MealType.dinner:
        return Icons.dinner_dining;
      case MealType.snack:
        return Icons.cookie;
    }
  }

  String get timeRange {
    switch (this) {
      case MealType.breakfast:
        return '7:00 - 9:00';
      case MealType.lunch:
        return '12:00 - 14:00';
      case MealType.dinner:
        return '18:00 - 20:00';
      case MealType.snack:
        return '15:00 - 16:00';
    }
  }
}

/// Represents a day's meal plan
class DayMealPlan {
  final String id;
  final DateTime date;
  final Map<MealType, Meal?> meals;
  final int targetCalories;
  final String? notes;

  const DayMealPlan({
    required this.id,
    required this.date,
    this.meals = const {},
    this.targetCalories = 2000,
    this.notes,
  });

  int get totalCalories =>
      meals.values.whereType<Meal>().fold(0, (sum, m) => sum + m.calories);

  DayMealPlan copyWith({
    Map<MealType, Meal?>? meals,
    int? targetCalories,
    String? notes,
  }) {
    return DayMealPlan(
      id: id,
      date: date,
      meals: meals ?? this.meals,
      targetCalories: targetCalories ?? this.targetCalories,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'meals': meals.map((k, v) => MapEntry(k.name, v?.toJson())),
        'targetCalories': targetCalories,
        'notes': notes,
      };

  factory DayMealPlan.fromJson(Map<String, dynamic> json) {
    final mealsJson = json['meals'] as Map<String, dynamic>? ?? {};
    final meals = <MealType, Meal?>{};
    for (final type in MealType.values) {
      final mealJson = mealsJson[type.name];
      meals[type] = mealJson != null ? Meal.fromJson(mealJson) : null;
    }
    return DayMealPlan(
      id: json['id'],
      date: DateTime.parse(json['date']),
      meals: meals,
      targetCalories: json['targetCalories'] ?? 2000,
      notes: json['notes'],
    );
  }
}

/// Weekly meal plan
class WeeklyMealPlan {
  final String id;
  final String name;
  final DateTime weekStart;
  final List<DayMealPlan> days;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WeeklyMealPlan({
    required this.id,
    required this.name,
    required this.weekStart,
    required this.days,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'weekStart': weekStart.toIso8601String(),
        'days': days.map((d) => d.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WeeklyMealPlan.fromJson(Map<String, dynamic> json) => WeeklyMealPlan(
        id: json['id'],
        name: json['name'],
        weekStart: DateTime.parse(json['weekStart']),
        days:
            (json['days'] as List).map((d) => DayMealPlan.fromJson(d)).toList(),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}
