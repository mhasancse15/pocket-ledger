import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recurring_rule.dart';
import '../providers/recurring_provider.dart';

/// ViewModel for recurring expense management
class RecurringViewModel {
  final Ref _ref;

  RecurringViewModel(this._ref);

  /// Get all recurring rules
  Future<List<RecurringRule>> getAllRecurringRules() async {
    try {
      return await _ref.read(allRecurringRulesProvider.future);
    } catch (e) {
      return [];
    }
  }

  /// Get active recurring rules only
  Future<List<RecurringRule>> getActiveRecurringRules() async {
    try {
      return await _ref.read(activeRecurringRulesProvider.future);
    } catch (e) {
      return [];
    }
  }

  /// Add new recurring rule
  Future<void> addRecurringRule(RecurringRule rule) async {
    await _ref.read(recurringNotifierProvider.notifier).addRecurringRule(rule);
  }

  /// Update recurring rule
  Future<void> updateRecurringRule(RecurringRule rule) async {
    await _ref.read(recurringNotifierProvider.notifier).updateRecurringRule(rule);
  }

  /// Delete recurring rule
  Future<void> deleteRecurringRule(String ruleId) async {
    await _ref.read(recurringNotifierProvider.notifier).deleteRecurringRule(ruleId);
  }

  /// Calculate next occurrence date
  DateTime calculateNextOccurrence(RecurringRule rule) {
    final now = DateTime.now();
    switch (rule.frequency) {
      case RecurringFrequency.weekly:
        return rule.nextOccurrenceDate.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        return DateTime(now.year, now.month + 1, rule.nextOccurrenceDate.day);
      case RecurringFrequency.quarterly:
        return DateTime(now.year, now.month + 3, rule.nextOccurrenceDate.day);
      case RecurringFrequency.yearly:
        return DateTime(now.year + 1, rule.nextOccurrenceDate.month, rule.nextOccurrenceDate.day);
    }
  }
}

/// Provider for RecurringViewModel
final recurringViewModelProvider = Provider((ref) {
  return RecurringViewModel(ref);
});
