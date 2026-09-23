import '../../domain/entities/category.dart';

/// Category model - data layer with JSON serialization


class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.name,
    required super.type,
    super.icon,
    super.color,
    super.isArchived,
    required super.createdAt,
  });

  /// Convert to JSON for Drift storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.toString().split('.').last,
    'icon': icon,
    'color': color,
    'isArchived': isArchived ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Convert from JSON (from Drift database)
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] == 'income' ? CategoryType.income : CategoryType.expense,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isArchived: (json['isArchived'] as int?) == 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert to domain entity
  Category toEntity() => Category(
    id: id,
    name: name,
    type: type,
    icon: icon,
    color: color,
    isArchived: isArchived,
    createdAt: createdAt,
  );

  /// Default categories
  static List<CategoryModel> getDefaults() => [
    CategoryModel(
      id: 'cat_food',
      name: 'Food',
      type: CategoryType.expense,
      icon: 'restaurant',
      color: '#FF9800',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'cat_transport',
      name: 'Transport',
      type: CategoryType.expense,
      icon: 'directions_car',
      color: '#2196F3',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'cat_shopping',
      name: 'Shopping',
      type: CategoryType.expense,
      icon: 'shopping_bag',
      color: '#E91E63',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'cat_bills',
      name: 'Bills',
      type: CategoryType.expense,
      icon: 'receipt',
      color: '#9C27B0',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'cat_health',
      name: 'Health',
      type: CategoryType.expense,
      icon: 'local_hospital',
      color: '#F44336',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'cat_entertainment',
      name: 'Entertainment',
      type: CategoryType.expense,
      icon: 'movie',
      color: '#FF5722',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'cat_education',
      name: 'Education',
      type: CategoryType.expense,
      icon: 'school',
      color: '#009688',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'cat_mobile',
      name: 'Mobile/Internet',
      type: CategoryType.expense,
      icon: 'phone',
      color: '#00BCD4',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'cat_other',
      name: 'Other',
      type: CategoryType.expense,
      icon: 'category',
      color: '#795548',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'cat_salary',
      name: 'Salary',
      type: CategoryType.income,
      icon: 'attach_money',
      color: '#4CAF50',
      createdAt: DateTime.now(),
    ),
  ];
}
