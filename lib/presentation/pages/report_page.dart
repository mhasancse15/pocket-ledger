import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final colors = const [
    Colors.teal,
    Colors.orange,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.purple,
    Colors.blue,
    Colors.green,
  ];

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? const <Budget>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Previous expense summary',
            onPressed: () {
              context.pushNamed(AppRoutes.previousExpanseName);
            },
            icon: const Icon(Icons.bar_chart_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            ErrorView(message: 'Unable to load transactions\n$error'),
        data: (transactions) {
          return categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                ErrorView(message: 'Unable to load categories\n$error'),
            data: (categories) {
              return _buildReport(context, transactions, categories, budgets);
            },
          );
        },
      ),
    );
  }

  Widget _buildReport(
    BuildContext context,
    List<Transaction> transactions,
    List<Category> categories,
    List<Budget> budgets,
  ) {
    final categoryNames = <String, String>{
      for (final category in categories) category.id: category.name,
    };

    final expenses = transactions.where((transaction) {
      final date = transaction.date.toLocal();

      return transaction.type == TransactionType.expense &&
          date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList();

    final totals = <String, double>{};

    for (final expense in expenses) {
      final categoryName =
          categoryNames[expense.categoryId]?.trim().isNotEmpty == true
          ? categoryNames[expense.categoryId]!
          : 'Other';

      totals.update(
        categoryName,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalExpense = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    final monthBudgets = budgets.where((budget) {
      return budget.year == selectedMonth.year &&
          budget.month == selectedMonth.month;
    }).toList();

    final monthlyBudgets = monthBudgets.where(
      (budget) => budget.scope == BudgetScope.monthly,
    );

    final categoryAndWalletBudgets = monthBudgets
        .where((budget) => budget.scope != BudgetScope.monthly)
        .fold<double>(0, (sum, budget) => sum + budget.amount);

    final totalBudget = monthlyBudgets.isNotEmpty
        ? monthlyBudgets.first.amount
        : categoryAndWalletBudgets;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allTransactionsProvider);
        ref.invalidate(allCategoriesProvider);
        ref.invalidate(budgetsProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildMonthSelector(context),

          const SizedBox(height: 16),

          _buildReportHeader(
            context,
            totalExpense: totalExpense,
            transactionCount: expenses.length,
            topCategory: entries.isEmpty ? null : entries.first.key,
          ),

          const SizedBox(height: 16),

          _buildBudgetReport(
            context,
            totalBudget: totalBudget,
            totalExpense: totalExpense,
            budgetCount: monthBudgets.length,
          ),

          const SizedBox(height: 24),

          if (entries.isEmpty)
            const EmptyView(
              icon: Icons.pie_chart_outline,
              title: 'No report data',
              message: 'Add expenses for this month to see your report.',
            )
          else ...[
            Text(
              'Spending breakdown',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _buildPieChart(
              context,
              entries: entries,
              totalExpense: totalExpense,
            ),

            const SizedBox(height: 24),

            Text(
              'Category details',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            ...entries.asMap().entries.map((entry) {
              final name = entry.value.key;
              final amount = entry.value.value;
              final percentage = totalExpense == 0
                  ? 0.0
                  : amount / totalExpense;

              final color = colors[entry.key % colors.length];

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: color.withOpacity(0.12),
                            child: Icon(
                              Icons.category_outlined,
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            AppUtils.formatCurrency(amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: percentage,
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(8),
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(percentage * 100).round()}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month - 1,
                );
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(selectedMonth),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month + 1,
                );
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHeader(
    BuildContext context, {
    required double totalExpense,
    required int transactionCount,
    required String? topCategory,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total expense', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              AppUtils.formatCurrency(totalExpense),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildWhiteMetric(
                  label: 'Transactions',
                  value: '$transactionCount',
                ),
              ),
              Expanded(
                child: _buildWhiteMetric(
                  label: 'Top category',
                  value: topCategory ?? 'N/A',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteMetric({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetReport(
    BuildContext context, {
    required double totalBudget,
    required double totalExpense,
    required int budgetCount,
  }) {
    final theme = Theme.of(context);
    final hasBudget = totalBudget > 0;

    final remaining = totalBudget - totalExpense;

    final usage = hasBudget ? totalExpense / totalBudget : 0.0;

    final progress = usage.clamp(0.0, 1.0);

    final isExceeded = hasBudget && remaining < 0;

    final statusColor = !hasBudget
        ? Colors.blueGrey
        : isExceeded
        ? Colors.red
        : usage >= 0.9
        ? Colors.orange
        : usage >= 0.75
        ? Colors.amber.shade800
        : Colors.green;

    final statusText = !hasBudget
        ? 'Not set'
        : isExceeded
        ? 'Exceeded'
        : usage >= 0.9
        ? 'Critical'
        : usage >= 0.75
        ? 'Warning'
        : 'On track';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.track_changes_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget report',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        budgetCount == 0
                            ? 'No budget configured'
                            : '$budgetCount budget${budgetCount == 1 ? '' : 's'} configured',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (!hasBudget)
              Text(
                'Set a budget to compare your spending against a target.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildBudgetValue(
                      context,
                      label: 'Budget',
                      value: AppUtils.formatCurrency(totalBudget),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _buildBudgetValue(
                      context,
                      label: 'Spent',
                      value: AppUtils.formatCurrency(totalExpense),
                      color: statusColor,
                    ),
                  ),
                  Expanded(
                    child: _buildBudgetValue(
                      context,
                      label: remaining >= 0 ? 'Remaining' : 'Over',
                      value: AppUtils.formatCurrency(remaining.abs()),
                      color: remaining >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                borderRadius: BorderRadius.circular(10),
                color: statusColor,
                backgroundColor: theme.colorScheme.outlineVariant,
              ),

              const SizedBox(height: 9),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(usage * 100).round()}% used',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    remaining >= 0
                        ? '${AppUtils.formatCurrency(remaining)} available'
                        : 'Budget exceeded',
                    style: TextStyle(
                      color: remaining >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetValue(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart(
    BuildContext context, {
    required List<MapEntry<String, double>> entries,
    required double totalExpense,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 230,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 48,
                  sectionsSpace: 3,
                  sections: [
                    for (var index = 0; index < entries.length; index++)
                      PieChartSectionData(
                        value: entries[index].value,
                        color: colors[index % colors.length],
                        radius: 76,
                        title: _percentage(entries[index].value, totalExpense),
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                for (var index = 0; index < entries.length; index++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 5,
                        backgroundColor: colors[index % colors.length],
                      ),
                      const SizedBox(width: 5),
                      Text(entries[index].key),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _percentage(double value, double total) {
    if (total == 0) return '0%';

    return '${(value / total * 100).round()}%';
  }
}
