import 'package:my_wallet/core/errors/failures.dart';
import 'package:my_wallet/domain/entities/recurring_rule.dart';
import 'package:my_wallet/domain/repositories/recurring_rule_repository.dart';

class RecurringRuleRepositoryImpl implements RecurringRuleRepository {
  static final List<RecurringRule> _rules = [];

  @override
  Future<Either<Failure, RecurringRule>> addRecurringRule(RecurringRule rule) async {
    try {
      _rules.add(rule);
      return Either.right(rule);
    } catch (e) {
      return Either.left(DatabaseFailure('Failed to add recurring rule: $e'));
    }
  }

  @override
  Future<Either<Failure, RecurringRule>> updateRecurringRule(RecurringRule rule) async {
    try {
      final index = _rules.indexWhere((r) => r.id == rule.id);
      if (index == -1) {
        return Either.left(NotFoundFailure('Recurring rule not found'));
      }
      _rules[index] = rule;
      return Either.right(rule);
    } catch (e) {
      return Either.left(DatabaseFailure('Failed to update recurring rule: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRecurringRule(String ruleId) async {
    try {
      _rules.removeWhere((r) => r.id == ruleId);
      return Either.right(null);
    } catch (e) {
      return Either.left(DatabaseFailure('Failed to delete recurring rule: $e'));
    }
  }

  @override
  Future<Either<Failure, RecurringRule>> getRecurringRule(String id) async {
    try {
      final rule = _rules.firstWhere((r) => r.id == id);
      return Either.right(rule);
    } catch (e) {
      return Either.left(NotFoundFailure('Recurring rule not found'));
    }
  }

  @override
  Future<Either<Failure, List<RecurringRule>>> getAllRecurringRules() async {
    try {
      return Either.right(_rules.toList());
    } catch (e) {
      return Either.left(DatabaseFailure('Failed to get all recurring rules: $e'));
    }
  }

  @override
  Future<Either<Failure, List<RecurringRule>>> getActiveRecurringRules() async {
    try {
      final active = _rules.where((r) => r.isActive).toList();
      return Either.right(active);
    } catch (e) {
      return Either.left(DatabaseFailure('Failed to get active recurring rules: $e'));
    }
  }
}
