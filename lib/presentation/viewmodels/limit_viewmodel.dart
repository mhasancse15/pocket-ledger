import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/monthly_limit.dart';
import '../providers/limit_provider.dart';

/// ViewModel for monthly limit management
class LimitViewModel {
  final Ref _ref;

  LimitViewModel(this._ref);

  /// Get monthly limit
  Future<MonthlyLimit?> getMonthlyLimit(int year, int month) async {
    try {
      return await _ref.read(monthlyLimitProvider((year, month)).future);
    } catch (e) {
      return null;
    }
  }

  /// Set monthly limit
  Future<void> setMonthlyLimit(MonthlyLimit limit) async {
    await _ref.read(limitNotifierProvider.notifier).setMonthlyLimit(limit);
  }

  /// Delete monthly limit
  Future<void> deleteMonthlyLimit(int year, int month) async {
    await _ref.read(limitNotifierProvider.notifier).deleteMonthlyLimit(year, month);
  }

  /// Get all limits
  Future<List<MonthlyLimit>> getAllLimits() async {
    try {
      return await _ref.read(allLimitsProvider.future);
    } catch (e) {
      return [];
    }
  }

  /// Check if budget is on track
  String getBudgetStatus(double percentage) {
    if (percentage < 75) return 'On Track';
    if (percentage < 90) return 'Warning';
    if (percentage < 100) return 'Critical';
    return 'Exceeded';
  }

  /// Get budget status color
  String getStatusColor(double percentage) {
    if (percentage < 75) return 'green';
    if (percentage < 90) return 'amber';
    if (percentage < 100) return 'orange';
    return 'red';
  }
}

/// Provider for LimitViewModel
final limitViewModelProvider = Provider((ref) {
  return LimitViewModel(ref);
});
