import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recurring_rule.dart';
import '../../domain/usecases/recurring_date_calculator.dart';
import '../providers/recurring_provider.dart';

/// ViewModel for recurring expense management
class RecurringViewModel {
  final Ref _ref;
  static const _dateCalculator = RecurringDateCalculator();

  RecurringViewModel(this._ref);

  /// Get all recurring rules
  Future<List<RecurringRule>> getAllRecurringRules() async {
    return _ref.read(allRecurringRulesProvider.future);
  }

  /// Get active recurring rules only
  Future<List<RecurringRule>> getActiveRecurringRules() async {
    return _ref.read(activeRecurringRulesProvider.future);
  }

  /// Add new recurring rule
  Future<void> addRecurringRule(RecurringRule rule) async {
    await _ref.read(recurringNotifierProvider.notifier).addRecurringRule(rule);
  }

  /// Update recurring rule
  Future<void> updateRecurringRule(RecurringRule rule) async {
    await _ref
        .read(recurringNotifierProvider.notifier)
        .updateRecurringRule(rule);
  }

  /// Delete recurring rule
  Future<void> deleteRecurringRule(String ruleId) async {
    await _ref
        .read(recurringNotifierProvider.notifier)
        .deleteRecurringRule(ruleId);
  }

  /// Calculate next occurrence date
  DateTime calculateNextOccurrence(RecurringRule rule) {
    return _dateCalculator.calculateNextDate(
      currentDate: rule.nextOccurrenceDate,
      frequency: rule.frequency,
      anchorDay: rule.anchorDay,
    );
  }
}

/// Provider for RecurringViewModel
final recurringViewModelProvider = Provider((ref) {
  return RecurringViewModel(ref);
});
