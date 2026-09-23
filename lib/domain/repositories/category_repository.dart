import '../../core/errors/failures.dart';
import '../entities/category.dart';

/// Category repository interface


abstract class CategoryRepository {
  Future<Either<Failure, Category>> addCategory(Category category);
  Future<Either<Failure, Category>> updateCategory(Category category);
  Future<Either<Failure, void>> deleteCategory(String categoryId);
  Future<Either<Failure, List<Category>>> getAllCategories();
  Future<Either<Failure, List<Category>>> getCategoriesByType(CategoryType type);
}

class Either<L, R> {
  final L? _left;
  final R? _right;
  final bool _isRight;

  Either.left(this._left) : _right = null, _isRight = false;
  Either.right(this._right) : _left = null, _isRight = true;

  T fold<T>(T Function(L) ifLeft, T Function(R) ifRight) {
    return _isRight ? ifRight(_right as R) : ifLeft(_left as L);
  }

  bool get isRight => _isRight;
  bool get isLeft => !_isRight;
}
