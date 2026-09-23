import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/category_repository_impl.dart';
import '../../domain/entities/category.dart';
import 'database_provider.dart';


/// Provides the category repository
final categoryRepositoryProvider = Provider((ref) {
  return CategoryRepositoryImpl(ref.watch(databaseProvider));
});

/// Fetches all categories
final allCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  final result = await repository.getAllCategories();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (categories) => categories,
  );
});

/// Fetches categories by type (income/expense)
final categoriesByTypeProvider = FutureProvider.family<List<Category>, CategoryType>((ref, type) async {
  final repository = ref.watch(categoryRepositoryProvider);
  final result = await repository.getCategoriesByType(type);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (categories) => categories,
  );
});

/// StateNotifier for managing category additions/updates
class CategoryNotifier extends StateNotifier<AsyncValue<Category>> {
  final CategoryRepositoryImpl _repository;

  CategoryNotifier(this._repository) : super(const AsyncValue.loading());

  Future<void> addCategory(Category category) async {
    state = const AsyncValue.loading();
    final result = await _repository.addCategory(category);
    state = result.fold(
      (failure) => AsyncValue.error(Exception(failure.message), StackTrace.current),
      (category) => AsyncValue.data(category),
    );
  }

  Future<void> updateCategory(Category category) async {
    state = const AsyncValue.loading();
    final result = await _repository.updateCategory(category);
    state = result.fold(
      (failure) => AsyncValue.error(Exception(failure.message), StackTrace.current),
      (category) => AsyncValue.data(category),
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    final result = await _repository.deleteCategory(categoryId);
    result.fold(
      (failure) => state = AsyncValue.error(Exception(failure.message), StackTrace.current),
      (_) => null,
    );
  }
}

final categoryNotifierProvider = StateNotifierProvider<CategoryNotifier, AsyncValue<Category>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return CategoryNotifier(repository);
});
