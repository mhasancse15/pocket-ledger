import 'package:my_wallet/core/errors/failures.dart';
import 'package:my_wallet/data/models/monthly_limit_model.dart';
import 'package:my_wallet/domain/entities/monthly_limit.dart';
import 'package:my_wallet/domain/repositories/limit_repository.dart';

class LimitRepositoryImpl implements LimitRepository {
  static final List<MonthlyLimitModel> _limits = [];

  @override
  Future<Either<Failure, MonthlyLimit>> setMonthlyLimit(MonthlyLimit limit) async {
    try {
      final index = _limits.indexWhere(
        (l) => l.year == limit.year && l.month == limit.month,
      );

      final model = MonthlyLimitModel(
        id: limit.id,
        year: limit.year,
        month: limit.month,
        amount: limit.amount,
        createdAt: limit.createdAt,
        updatedAt: DateTime.now(),
      );

      if (index != -1) {
        _limits[index] = model;
      } else {
        _limits.add(model);
      }

      return Either.right(model);
    } catch (e) {
      return Either.left(DatabaseFailure('Failed to set monthly limit: $e'));
    }
  }

  @override
  Future<Either<Failure, MonthlyLimit?>> getMonthlyLimit(int year, int month) async {
    try {
      final index = _limits.indexWhere((l) => l.year == year && l.month == month);
      if (index != -1) {
        return Either.right(_limits[index]);
      }
      return Either.right(null);
    } catch (e) {
      return Either.left(DatabaseFailure('Failed to get monthly limit: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMonthlyLimit(int year, int month) async {
    try {
      _limits.removeWhere((l) => l.year == year && l.month == month);
      return Either.right(null);
    } catch (e) {
      return Either.left(DatabaseFailure('Failed to delete monthly limit: $e'));
    }
  }

  @override
  Future<Either<Failure, List<MonthlyLimit>>> getAllLimits() async {
    try {
      return Either.right(_limits.toList());
    } catch (e) {
      return Either.left(DatabaseFailure('Failed to get all limits: $e'));
    }
  }
}
