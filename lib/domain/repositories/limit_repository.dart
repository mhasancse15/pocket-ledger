

import '../../core/errors/failures.dart';
import '../entities/monthly_limit.dart';

abstract class LimitRepository {
  Future<Either<Failure, MonthlyLimit>> setMonthlyLimit(MonthlyLimit limit);
  Future<Either<Failure, MonthlyLimit?>> getMonthlyLimit(int year, int month);
  Future<Either<Failure, void>> deleteMonthlyLimit(int year, int month);
  Future<Either<Failure, List<MonthlyLimit>>> getAllLimits();
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
