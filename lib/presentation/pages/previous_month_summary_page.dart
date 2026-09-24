import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/transaction.dart';
import '../providers/limit_provider.dart';
import '../providers/transaction_provider.dart';

class PreviousMonthSummaryPage extends ConsumerWidget {
  const PreviousMonthSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    final transactionsAsync = ref.watch(allTransactionsProvider);

    final currentMonthLimitAsync = ref.watch(
      monthlyLimitProvider(
        (
        now.year,
        now.month,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expense summary',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => _ErrorState(
          message: 'Unable to load expense data\n$error',
        ),
        data: (transactions) {
          final currentLimit =
              currentMonthLimitAsync.valueOrNull?.amount;

          return _ExpenseSummaryContent(
            transactions: transactions,
            currentMonthLimit: currentLimit,
            currentDate: now,
          );
        },
      ),
    );
  }
}

class _ExpenseSummaryContent extends StatelessWidget {
  const _ExpenseSummaryContent({
    required this.transactions,
    required this.currentMonthLimit,
    required this.currentDate,
  });

  final List<Transaction> transactions;
  final double? currentMonthLimit;
  final DateTime currentDate;

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateTime(
      currentDate.year,
      currentDate.month,
    );

    final previousMonth = DateTime(
      currentDate.year,
      currentDate.month - 1,
    );

    final currentMonthExpense = _getMonthlyExpense(currentMonth);

    final previousMonthExpense = _getMonthlyExpense(previousMonth);

    final currentYearExpenses = _getCurrentYearExpenses();

    final currentYearTotal = currentYearExpenses.fold<double>(
      0,
          (sum, transaction) => sum + transaction.amount,
    );

    final monthsPassed = currentDate.month;
    final monthlyAverage = monthsPassed == 0
        ? 0.0
        : currentYearTotal / monthsPassed;

    final monthlyTotals = _getMonthlyTotals();
    final highestMonth = _getHighestExpenseMonth(monthlyTotals);

    final difference =
        currentMonthExpense - previousMonthExpense;

    final percentageChange = previousMonthExpense == 0
        ? 0.0
        : difference / previousMonthExpense * 100;

    final targetUsage = currentMonthLimit == null ||
        currentMonthLimit! <= 0
        ? 0.0
        : currentMonthExpense / currentMonthLimit!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _YearHeader(year: currentDate.year),
        const SizedBox(height: 16),

        _YearSummaryCard(
          total: currentYearTotal,
          average: monthlyAverage,
          highestMonth: highestMonth,
        ),

        const SizedBox(height: 18),

        Text(
          'Current month comparison',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        _ComparisonCard(
          currentMonth: currentMonth,
          previousMonth: previousMonth,
          currentExpense: currentMonthExpense,
          previousExpense: previousMonthExpense,
          difference: difference,
          percentageChange: percentageChange,
        ),

        const SizedBox(height: 18),

        _CurrentTargetCard(
          currentMonthExpense: currentMonthExpense,
          target: currentMonthLimit,
          usage: targetUsage,
        ),

        const SizedBox(height: 22),

        Text(
          'This year’s expense graph',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Monthly spending from January to December ${currentDate.year}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),

        _YearlyExpenseChart(
          monthlyTotals: monthlyTotals,
          currentMonth: currentDate.month,
        ),

        const SizedBox(height: 22),

        _InsightCard(
          currentExpense: currentMonthExpense,
          previousExpense: previousMonthExpense,
          currentYearTotal: currentYearTotal,
          target: currentMonthLimit,
        ),
      ],
    );
  }

  List<Transaction> _getCurrentYearExpenses() {
    return transactions.where((transaction) {
      final date = transaction.date.toLocal();

      return transaction.type == TransactionType.expense &&
          date.year == currentDate.year &&
          date.month <= currentDate.month;
    }).toList();
  }

  double _getMonthlyExpense(DateTime month) {
    return transactions
        .where((transaction) {
      final date = transaction.date.toLocal();

      return transaction.type == TransactionType.expense &&
          date.year == month.year &&
          date.month == month.month;
    })
        .fold<double>(
      0,
          (sum, transaction) => sum + transaction.amount,
    );
  }

  List<double> _getMonthlyTotals() {
    return List<double>.generate(
      12,
          (index) {
        final month = DateTime(
          currentDate.year,
          index + 1,
        );

        return _getMonthlyExpense(month);
      },
    );
  }

  String? _getHighestExpenseMonth(List<double> totals) {
    if (totals.every((amount) => amount == 0)) {
      return null;
    }

    var highestIndex = 0;

    for (var index = 1; index < totals.length; index++) {
      if (totals[index] > totals[highestIndex]) {
        highestIndex = index;
      }
    }

    return DateFormat('MMMM').format(
      DateTime(currentDate.year, highestIndex + 1),
    );
  }
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({
    required this.year,
  });

  final int year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Year-to-date overview',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '$year expense summary',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _YearSummaryCard extends StatelessWidget {
  const _YearSummaryCard({
    required this.total,
    required this.average,
    required this.highestMonth,
  });

  final double total;
  final double average;
  final String? highestMonth;

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Total expense this year',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppUtils.formatCurrency(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _WhiteMetric(
                  label: 'Monthly average',
                  value: AppUtils.formatCurrency(average),
                ),
              ),
              Expanded(
                child: _WhiteMetric(
                  label: 'Highest month',
                  value: highestMonth ?? 'N/A',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.currentMonth,
    required this.previousMonth,
    required this.currentExpense,
    required this.previousExpense,
    required this.difference,
    required this.percentageChange,
  });

  final DateTime currentMonth;
  final DateTime previousMonth;
  final double currentExpense;
  final double previousExpense;
  final double difference;
  final double percentageChange;

  @override
  Widget build(BuildContext context) {
    final spendingIncreased = difference > 0;
    final comparisonColor =
    spendingIncreased ? Colors.red : Colors.green;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _ComparisonValue(
                    label: DateFormat('MMM yyyy').format(previousMonth),
                    value: previousExpense,
                    color: Colors.orange,
                  ),
                ),
                const Icon(Icons.arrow_forward),
                Expanded(
                  child: _ComparisonValue(
                    label: DateFormat('MMM yyyy').format(currentMonth),
                    value: currentExpense,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Icon(
                  spendingIncreased
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: comparisonColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    spendingIncreased
                        ? 'You spent more than last month'
                        : 'You spent less than last month',
                    style: TextStyle(
                      color: comparisonColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${difference >= 0 ? '+' : '-'}'
                      '${AppUtils.formatCurrency(difference.abs())}',
                  style: TextStyle(
                    color: comparisonColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${percentageChange.abs().toStringAsFixed(1)}% '
                    '${spendingIncreased ? 'increase' : 'decrease'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonValue extends StatelessWidget {
  const _ComparisonValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Text(
          AppUtils.formatCurrency(value),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _CurrentTargetCard extends StatelessWidget {
  const _CurrentTargetCard({
    required this.currentMonthExpense,
    required this.target,
    required this.usage,
  });

  final double currentMonthExpense;
  final double? target;
  final double usage;

  @override
  Widget build(BuildContext context) {
    if (target == null || target! <= 0) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.track_changes_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No target set for the current month.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final remaining = target! - currentMonthExpense;
    final exceeded = remaining < 0;
    final progress = usage.clamp(0.0, 1.0);

    final color = exceeded
        ? Colors.red
        : usage >= 0.9
        ? Colors.orange
        : Colors.green;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.track_changes_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Current month target',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${(usage * 100).round()}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: color,
            ),
            const SizedBox(height: 10),
            Text(
              exceeded
                  ? '${AppUtils.formatCurrency(remaining.abs())} over target'
                  : '${AppUtils.formatCurrency(remaining)} remaining',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearlyExpenseChart extends StatelessWidget {
  const _YearlyExpenseChart({
    required this.monthlyTotals,
    required this.currentMonth,
  });

  final List<double> monthlyTotals;
  final int currentMonth;

  @override
  Widget build(BuildContext context) {
    final highest = monthlyTotals.isEmpty
        ? 0.0
        : monthlyTotals.reduce((a, b) => a > b ? a : b);

    final maxY = highest <= 0 ? 100.0 : highest * 1.25;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 16),
        child: SizedBox(
          height: 270,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        _formatShortAmount(value),
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final monthIndex = value.toInt();

                      if (monthIndex < 0 || monthIndex > 11) {
                        return const SizedBox.shrink();
                      }

                      return Text(
                        DateFormat('MMM').format(
                          DateTime(2026, monthIndex + 1),
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var index = 0;
                index < monthlyTotals.length;
                index++)
                  BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: monthlyTotals[index],
                        width: 14,
                        borderRadius: BorderRadius.circular(5),
                        color: index + 1 == currentMonth
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.35),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatShortAmount(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }

    return value.toStringAsFixed(0);
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.currentExpense,
    required this.previousExpense,
    required this.currentYearTotal,
    required this.target,
  });

  final double currentExpense;
  final double previousExpense;
  final double currentYearTotal;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difference = currentExpense - previousExpense;

    String message;
    IconData icon;
    Color color;

    if (target != null && currentExpense > target!) {
      message = 'Your current month spending is above your target.';
      icon = Icons.warning_amber_outlined;
      color = Colors.red;
    } else if (difference < 0) {
      message = 'Good progress. You spent less than last month.';
      icon = Icons.trending_down;
      color = Colors.green;
    } else if (difference > 0) {
      message = 'Your spending increased compared with last month.';
      icon = Icons.trending_up;
      color = Colors.orange;
    } else {
      message = 'Your spending is the same as last month.';
      icon = Icons.horizontal_rule;
      color = Colors.blue;
    }

    return Card(
      elevation: 0,
      color: color.withOpacity(0.10),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spending insight',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(message),
                  const SizedBox(height: 6),
                  Text(
                    'Year-to-date expense: '
                        '${AppUtils.formatCurrency(currentYearTotal)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteMetric extends StatelessWidget {
  const _WhiteMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
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
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}