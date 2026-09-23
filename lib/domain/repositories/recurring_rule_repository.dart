

import '../../core/errors/failures.dart';
import '../entities/recurring_rule.dart';

abstract class RecurringRuleRepository {
  Future<Either<Failure, RecurringRule>> addRecurringRule(RecurringRule rule);
  Future<Either<Failure, RecurringRule>> updateRecurringRule(RecurringRule rule);
  Future<Either<Failure, void>> deleteRecurringRule(String ruleId);
  Future<Either<Failure, RecurringRule>> getRecurringRule(String id);
  Future<Either<Failure, List<RecurringRule>>> getAllRecurringRules();
  Future<Either<Failure, List<RecurringRule>>> getActiveRecurringRules();
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
