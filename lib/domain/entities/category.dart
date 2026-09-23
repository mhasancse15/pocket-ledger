/// Domain Entity for Category
import 'package:equatable/equatable.dart';

enum CategoryType { income, expense }

class Category extends Equatable {
  final String id;
  final String name;
  final CategoryType type;
  final String? icon;
  final String? color;
  final bool isArchived;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.isArchived = false,
    required this.createdAt,
  });

  Category copyWith({
    String? id,
    String? name,
    CategoryType? type,
    String? icon,
    String? color,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, type, icon, color, isArchived, createdAt];
}
