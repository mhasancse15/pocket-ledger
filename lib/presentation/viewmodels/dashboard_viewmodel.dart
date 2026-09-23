import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/transaction.dart';
import '../providers/limit_provider.dart';
import '../providers/transaction_provider.dart';

/// ViewModel for the Dashboard page
class DashboardViewModel {
  final Ref _ref;

  DashboardViewModel(this._ref);

  /// Get current month transactions
  Future<List<Transaction>> getMonthTransactions(int year, int month) async {
    try {
      final result = await _ref.read(monthlyTransactionsProvider((year, month)).future);
      return result;
    } catch (e) {
      return [];
    }
  }

  /// Get monthly totals
  Future<(double, double)> getMonthlyTotals(int year, int month) async {
    try {
      final expenseResult = await _ref.read(
        monthlyTotalProvider((year, month, TransactionType.expense)).future,
      );
      final incomeResult = await _ref.read(
        monthlyTotalProvider((year, month, TransactionType.income)).future,
      );
      return (incomeResult, expenseResult);
    } catch (e) {
      return (0.0, 0.0);
    }
  }

  /// Get monthly limit
  Future<double?> getMonthlyLimit(int year, int month) async {
    try {
      final result = await _ref.read(monthlyLimitProvider((year, month)).future);
      return result?.amount;
    } catch (e) {
      return null;
    }
  }

  /// Calculate budget percentage
  double calculateBudgetPercentage(double spent, double limit) {
    if (limit <= 0) return 0;
    return (spent / limit) * 100;
  }

  /// Get budget status
  String getBudgetStatus(double percentage) {
    if (percentage < 75) return 'On Track';
    if (percentage < 90) return 'Warning';
    if (percentage < 100) return 'Critical';
    return 'Exceeded';
  }

  /// Get status color based on percentage
  /// Returns: green (0-74%), amber (75-89%), orange (90-99%), red (100%+)
  String getStatusColor(double percentage) {
    if (percentage < 75) return 'green';
    if (percentage < 90) return 'amber';
    if (percentage < 100) return 'orange';
    return 'red';
  }

  /// Get today's transactions
  Future<List<Transaction>> getTodayTransactions(int year, int month, int day) async {
    try {
      final transactions = await getMonthTransactions(year, month);
      final today = DateTime(year, month, day);
      return transactions
          .where((t) =>
              t.date.year == today.year &&
              t.date.month == today.month &&
              t.date.day == today.day)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get balance (income - expense)
  Future<double> getBalance(int year, int month) async {
    try {
      final (income, expense) = await getMonthlyTotals(year, month);
      return income - expense;
    } catch (e) {
      return 0.0;
    }
  }
}

/// Provider for DashboardViewModel
final dashboardViewModelProvider = Provider((ref) {
  return DashboardViewModel(ref);
});
