import 'package:drift/drift.dart' as drift;

import 'package:my_wallet/core/errors/failures.dart';
import 'package:my_wallet/data/datasources/drift/database.dart';
import 'package:my_wallet/data/models/category_model.dart';
import 'package:my_wallet/domain/entities/category.dart';
import 'package:my_wallet/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final AppDatabase _database;

  CategoryRepositoryImpl(this._database);

  Category _entity(CategoryTableData row) => CategoryModel.fromJson({
        'id': row.id,
        'name': row.name,
        'type': row.type,
        'icon': row.icon,
        'color': row.color,
        'isArchived': row.isArchived ? 1 : 0,
        'createdAt': row.createdAt.toIso8601String(),
      });

  CategoryTableCompanion _companion(Category category) =>
      CategoryTableCompanion.insert(
        id: category.id,
        name: category.name,
        type: category.type.name,
        icon: drift.Value(category.icon),
        color: drift.Value(category.color),
        isArchived: drift.Value(category.isArchived),
        createdAt: category.createdAt,
      );

  Future<void> _ensureDefaults() async {
    if ((await _database.getAllCategories()).isNotEmpty) return;
    for (final category in CategoryModel.getDefaults()) {
      await _database.insertCategory(_companion(category));
    }
  }

  @override
  Future<Either<Failure, Category>> addCategory(Category category) async {
    try {
      await _ensureDefaults();
      await _database.insertCategory(_companion(category));
      return Either.right(category);
    } catch (error) {
      return Either.left(DatabaseFailure('Failed to add category: $error'));
    }
  }

  @override
  Future<Either<Failure, Category>> updateCategory(Category category) async {
    try {
      await _ensureDefaults();
      final changed = await _database.updateCategory(CategoryTableData(
        id: category.id,
        name: category.name,
        type: category.type.name,
        icon: category.icon,
        color: category.color,
        isArchived: category.isArchived,
        createdAt: category.createdAt,
      ));
      return changed
          ? Either.right(category)
          : Either.left(NotFoundFailure('Category not found'));
    } catch (error) {
      return Either.left(DatabaseFailure('Failed to update category: $error'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String categoryId) async {
    return updateCategory((await getAllCategories()).fold(
      (failure) => throw StateError(failure.message),
      (categories) {
        final category = categories.firstWhere(
          (value) => value.id == categoryId,
          orElse: () => throw StateError('Category not found'),
        );
        return category.copyWith(isArchived: true);
      },
    )).then((result) => result.fold(
          Either.left,
          (_) => Either.right(null),
        ));
  }

  @override
  Future<Either<Failure, List<Category>>> getAllCategories() async {
    try {
      await _ensureDefaults();
      final rows = await _database.getAllCategories();
      return Either.right(rows.map(_entity).toList());
    } catch (error) {
      return Either.left(DatabaseFailure('Failed to fetch categories: $error'));
    }
  }

  @override
  Future<Either<Failure, List<Category>>> getCategoriesByType(
      CategoryType type) async {
    try {
      await _ensureDefaults();
      final rows = await _database.getCategoriesByType(type.name);
      return Either.right(rows.map(_entity).toList());
    } catch (error) {
      return Either.left(DatabaseFailure('Failed to fetch categories: $error'));
    }
  }
}
