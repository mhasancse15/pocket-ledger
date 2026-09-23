import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/category.dart';
import '../providers/category_provider.dart';

/// ViewModel for category management
class CategoryViewModel {
  final Ref _ref;

  CategoryViewModel(this._ref);

  /// Get all categories
  Future<List<Category>> getAllCategories() async {
    try {
      return await _ref.read(allCategoriesProvider.future);
    } catch (e) {
      return [];
    }
  }

  /// Get categories by type
  Future<List<Category>> getCategoriesByType(CategoryType type) async {
    try {
      return await _ref.read(categoriesByTypeProvider(type).future);
    } catch (e) {
      return [];
    }
  }

  /// Add new category
  Future<void> addCategory(Category category) async {
    await _ref.read(categoryNotifierProvider.notifier).addCategory(category);
  }

  /// Update category
  Future<void> updateCategory(Category category) async {
    await _ref.read(categoryNotifierProvider.notifier).updateCategory(category);
  }

  /// Delete category
  Future<void> deleteCategory(String categoryId) async {
    await _ref.read(categoryNotifierProvider.notifier).deleteCategory(categoryId);
  }
}

/// Provider for CategoryViewModel
final categoryViewModelProvider = Provider((ref) {
  return CategoryViewModel(ref);
});
