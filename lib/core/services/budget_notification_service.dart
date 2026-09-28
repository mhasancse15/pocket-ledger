import 'dart:async';

import '../../data/datasources/drift/database.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/monthly_limit.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/budget_calculations.dart';
import '../../domain/usecases/budget_warning_level.dart';
import '../utils/constants.dart';
import 'local_notification_service.dart';

class BudgetNotificationService {
  BudgetNotificationService({
    required this._database,
    required this._notifications,
  });

  final AppDatabase _database;
  final LocalNotificationService _notifications;

  Future<void> _lastEvaluation = Future<void>.value();

  Future<void> checkCurrentMonth({
    required bool budgetNotificationsEnabled,
    required bool targetNotificationsEnabled,
  }) {
    final previousEvaluation = _lastEvaluation;
    final completed = Completer<void>();
    _lastEvaluation = completed.future;

    return _evaluateAfter(
      previousEvaluation,
      completed,
      budgetNotificationsEnabled,
      targetNotificationsEnabled,
    );
  }

  Future<void> _evaluateAfter(
    Future<void> previousEvaluation,
    Completer<void> completed,
    bool budgetNotificationsEnabled,
    bool targetNotificationsEnabled,
  ) async {
    await previousEvaluation;

    try {
      await _evaluateCurrentMonth(
        budgetNotificationsEnabled: budgetNotificationsEnabled,
        targetNotificationsEnabled: targetNotificationsEnabled,
      );
    } finally {
      completed.complete();
    }
  }

  Future<void> _evaluateCurrentMonth({
    required bool budgetNotificationsEnabled,
    required bool targetNotificationsEnabled,
  }) async {
    if (!budgetNotificationsEnabled && !targetNotificationsEnabled) return;

    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final transactionRows = await _database.getAllTransactions();
    final transactions = transactionRows
        .map(
          (row) => Transaction(
            id: row.id,
            type: TransactionType.values.byName(row.type),
            amount: row.amount,
            categoryId: row.categoryId,
            date: row.date,
            paymentMethod: PaymentMethod.values.byName(row.paymentMethod),
            note: row.note,
            recurringRuleId: row.recurringRuleId,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
        )
        .toList();

    final budgetRows = await _database.getAllBudgets();
    final budgets = budgetRows
        .map(
          (row) => Budget(
            id: row.id,
            year: row.year,
            month: row.month,
            scope: BudgetScope.values.byName(row.scope),
            scopeKey: row.scopeKey,
            amount: row.amount,
            rollover: row.rollover,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
        )
        .toList();

    if (budgetNotificationsEnabled) {
      final categoryNames = {
        for (final category
            in await _database.getAllCategoriesIncludingArchived())
          category.id: category.name,
      };
      for (final budget in budgets.where(
        (item) => item.year == year && item.month == month,
      )) {
        final limit = calculateEffectiveBudgetLimit(
          budget: budget,
          allBudgets: budgets,
          transactions: transactions,
        );
        final spent = calculateBudgetSpent(
          budget: budget,
          transactions: transactions,
        );
        await _evaluate(
          sourceId: 'budget:${budget.id}',
          name: _budgetName(budget, categoryNames),
          spent: spent,
          limit: limit,
          year: year,
          month: month,
          isTarget: false,
        );
      }
    }

    if (targetNotificationsEnabled) {
      final row = await _database.getMonthlyLimit(year, month);
      if (row != null) {
        final target = MonthlyLimit(
          id: row.id,
          year: row.year,
          month: row.month,
          amount: row.amount,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        );
        final spent = transactions
            .where(
              (transaction) =>
                  transaction.type == TransactionType.expense &&
                  transaction.date.toLocal().year == year &&
                  transaction.date.toLocal().month == month,
            )
            .fold<double>(0, (sum, item) => sum + item.amount);

        await _evaluate(
          sourceId: 'target:${target.id}',
          name: 'Monthly target',
          spent: spent,
          limit: target.amount,
          year: year,
          month: month,
          isTarget: true,
        );
      }
    }
  }

  Future<void> _evaluate({
    required String sourceId,
    required String name,
    required double spent,
    required double limit,
    required int year,
    required int month,
    required bool isTarget,
  }) async {
    final level = calculateWarningLevel(spent: spent, limit: limit);
    if (level == BudgetWarningLevel.none) return;

    final previousLevel = await _database.getHighestBudgetWarning(
      sourceId: sourceId,
      year: year,
      month: month,
    );
    if (level.index <= previousLevel) return;

    final percentage = spent / limit * 100;
    final title = _notificationTitle(level, isTarget: isTarget);
    final message = _notificationMessage(
      level: level,
      name: name,
      spent: spent,
      limit: limit,
      percentage: percentage,
      isTarget: isTarget,
    );

    await _notifications.showBudgetNotification(
      sourceId: sourceId,
      year: year,
      month: month,
      title: title,
      message: message,
    );
    await _database.saveBudgetWarning(
      sourceId: sourceId,
      year: year,
      month: month,
      warningLevel: level.index,
    );
  }

  String _budgetName(Budget budget, Map<String, String> categoryNames) {
    return switch (budget.scope) {
      BudgetScope.monthly => 'Monthly budget',
      BudgetScope.category =>
        'Category budget: ${categoryNames[budget.scopeKey] ?? _humanize(budget.scopeKey)}',
      BudgetScope.wallet => 'Payment method budget: ${budget.scopeKey}',
    };
  }

  String _humanize(String value) {
    return value
        .split(RegExp(r'[_\s-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _notificationTitle(
    BudgetWarningLevel level, {
    required bool isTarget,
  }) {
    final subject = isTarget ? 'Monthly target' : 'Budget';
    return switch (level) {
      BudgetWarningLevel.none => '$subject update',
      BudgetWarningLevel.warning75 =>
        isTarget ? 'Monthly target warning' : 'Budget warning',
      BudgetWarningLevel.warning90 =>
        isTarget ? 'Monthly target almost reached' : 'Budget almost reached',
      BudgetWarningLevel.reached100 =>
        isTarget ? 'Monthly target reached' : 'Budget reached',
      BudgetWarningLevel.exceeded =>
        isTarget ? 'Monthly target exceeded' : 'Budget exceeded',
    };
  }

  String _notificationMessage({
    required BudgetWarningLevel level,
    required String name,
    required double spent,
    required double limit,
    required double percentage,
    required bool isTarget,
  }) {
    final subject = isTarget ? 'monthly target' : name;
    return switch (level) {
      BudgetWarningLevel.none => '$subject is currently on track.',
      BudgetWarningLevel.warning75 =>
        'You have used ${percentage.round()}% of your $subject.',
      BudgetWarningLevel.warning90 =>
        '$subject is almost used up. ${percentage.round()}% has been spent.',
      BudgetWarningLevel.reached100 =>
        '$subject has reached its ${AppUtils.formatCurrency(limit)} limit.',
      BudgetWarningLevel.exceeded =>
        'You exceeded your $subject by '
            '${AppUtils.formatCurrency(spent - limit)}.',
    };
  }
}
