import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/monthly_saving.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/monthly_saving_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/financial_summary_card.dart';
import '../widgets/monthly_savings_chart.dart';

typedef _MonthlyTrend = ({
  DateTime month,
  double income,
  double expense,
  double balance,
});

typedef _CategoryChange = ({
  String id,
  String name,
  double current,
  double previous,
  double difference,
  double? percentage,
});

class TrendAnalysisPage extends ConsumerStatefulWidget {
  const TrendAnalysisPage({super.key});

  @override
  ConsumerState<TrendAnalysisPage> createState() => _TrendAnalysisPageState();
}

class _TrendAnalysisPageState extends ConsumerState<TrendAnalysisPage> {
  static const _incomeColor = Color(0xFF00A578);
  static const _expenseColor = Color(0xFFE85E6F);
  static const _balanceColor = Color(0xFF3182CE);

  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final savingsAsync = ref.watch(allMonthlySavingEntriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Trend analysis',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            ErrorView(message: 'Unable to load transactions\n$error'),
        data: (transactions) => categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              ErrorView(message: 'Unable to load categories\n$error'),
          data: (categories) => savingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                ErrorView(message: 'Unable to load monthly savings\n$error'),
            data: (savingEntries) => _buildContent(
              transactions: transactions,
              categories: categories,
              savingEntries: savingEntries,
            ),
          ),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }

  Widget _buildContent({
    required List<Transaction> transactions,
    required List<Category> categories,
    required List<MonthlySavingEntry> savingEntries,
  }) {
    final trends = _buildMonthlyTrends(transactions);
    final categoryChanges = _buildCategoryChanges(transactions, categories);
    final totalIncome = trends.fold<double>(
      0,
      (sum, item) => sum + item.income,
    );
    final totalExpense = trends.fold<double>(
      0,
      (sum, item) => sum + item.expense,
    );
    final averageExpense = totalExpense / trends.length;
    final monthsWithExpenses = trends
        .where((item) => item.expense > 0)
        .toList();
    final highestMonth = _extremeExpenseMonth(
      monthsWithExpenses,
      highest: true,
    );
    final lowestMonth = _extremeExpenseMonth(
      monthsWithExpenses,
      highest: false,
    );
    final balance = totalIncome - totalExpense;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _monthSelector(),
          const SizedBox(height: 16),
          _overviewCard(
            income: totalIncome,
            expense: totalExpense,
            balance: balance,
          ),
          const SizedBox(height: 22),
          _sectionHeading(
            title: 'Six-month overview',
            subtitle: 'Income, expense, and balance movement',
          ),
          const SizedBox(height: 10),
          _trendChart(trends),
          const SizedBox(height: 18),
          _sectionHeading(
            title: 'Monthly savings',
            subtitle: 'Savings allocated in each of the last six months',
          ),
          const SizedBox(height: 10),
          MonthlySavingsChart(
            entries: savingEntries,
            year: _selectedMonth.year,
            endMonth: _selectedMonth.month,
            monthCount: 6,
          ),
          const SizedBox(height: 18),
          _metricsGrid(
            averageExpense: averageExpense,
            highestMonth: highestMonth,
            lowestMonth: lowestMonth,
            balance: balance,
          ),
          const SizedBox(height: 24),
          _sectionHeading(
            title: 'Spending insights',
            subtitle: 'Highlights from your recent spending activity',
          ),
          const SizedBox(height: 10),
          _insightsCard(
            trends: trends,
            highestMonth: highestMonth,
            lowestMonth: lowestMonth,
            averageExpense: averageExpense,
            categoryChanges: categoryChanges,
          ),
          const SizedBox(height: 24),
          _sectionHeading(
            title: 'Category changes',
            subtitle:
                '${DateFormat('MMMM yyyy').format(_selectedMonth)} compared '
                'with ${DateFormat('MMMM yyyy').format(_previousMonth)}',
          ),
          const SizedBox(height: 10),
          if (categoryChanges.isEmpty)
            _emptyCategoryChanges()
          else
            ...categoryChanges.take(8).map(_categoryChangeCard),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(allCategoriesProvider);
    ref.invalidate(allMonthlySavingEntriesProvider);
    await Future.wait([
      ref.read(allTransactionsProvider.future),
      ref.read(allCategoriesProvider.future),
      ref.read(allMonthlySavingEntriesProvider.future),
    ]);
  }

  DateTime get _previousMonth =>
      DateTime(_selectedMonth.year, _selectedMonth.month - 1);

  List<_MonthlyTrend> _buildMonthlyTrends(List<Transaction> transactions) {
    final totals = <(int, int), ({double income, double expense})>{};

    for (final transaction in transactions) {
      final date = transaction.date.toLocal();
      final key = (date.year, date.month);
      final current = totals[key] ?? (income: 0.0, expense: 0.0);

      totals[key] = transaction.type == TransactionType.income
          ? (
              income: current.income + transaction.amount,
              expense: current.expense,
            )
          : (
              income: current.income,
              expense: current.expense + transaction.amount,
            );
    }

    return List.generate(6, (index) {
      final month = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - (5 - index),
      );
      final total =
          totals[(month.year, month.month)] ?? (income: 0.0, expense: 0.0);

      return (
        month: month,
        income: total.income,
        expense: total.expense,
        balance: total.income - total.expense,
      );
    });
  }

  List<_CategoryChange> _buildCategoryChanges(
    List<Transaction> transactions,
    List<Category> categories,
  ) {
    final names = {
      for (final category in categories) category.id: category.name,
    };
    final currentTotals = <String, double>{};
    final previousTotals = <String, double>{};

    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) continue;
      final date = transaction.date.toLocal();
      final totals =
          date.year == _selectedMonth.year && date.month == _selectedMonth.month
          ? currentTotals
          : date.year == _previousMonth.year &&
                date.month == _previousMonth.month
          ? previousTotals
          : null;
      if (totals == null) continue;

      totals.update(
        transaction.categoryId,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final ids = {...currentTotals.keys, ...previousTotals.keys};
    final changes =
        ids.map((id) {
            final current = currentTotals[id] ?? 0;
            final previous = previousTotals[id] ?? 0;
            return (
              id: id,
              name: names[id] ?? 'Other',
              current: current,
              previous: previous,
              difference: current - previous,
              percentage: previous == 0
                  ? null
                  : (current - previous) / previous * 100,
            );
          }).toList()
          ..sort((a, b) => b.difference.abs().compareTo(a.difference.abs()));

    return changes;
  }

  _MonthlyTrend? _extremeExpenseMonth(
    List<_MonthlyTrend> months, {
    required bool highest,
  }) {
    if (months.isEmpty) return null;
    return months.reduce(
      (best, next) => highest
          ? (next.expense > best.expense ? next : best)
          : (next.expense < best.expense ? next : best),
    );
  }

  Widget _monthSelector() {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
              );
            }),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${DateFormat('MMM yyyy').format(DateTime(_selectedMonth.year, _selectedMonth.month - 5))}'
                  ' - ${DateFormat('MMM yyyy').format(_selectedMonth)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  isCurrentMonth ? 'Latest six months' : 'Six-month period',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: isCurrentMonth
                ? null
                : () => setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    );
                  }),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _overviewCard({
    required double income,
    required double expense,
    required double balance,
  }) {
    final savingsRate = income <= 0 ? 0.0 : balance / income * 100;

    return FinancialSummaryCard(
      label: 'Six-month net balance',
      amount: balance,
      metrics: [
        FinancialSummaryMetric(
          label: 'Income',
          value: AppUtils.formatCurrency(income),
          icon: Icons.south_west,
        ),
        FinancialSummaryMetric(
          label: 'Expense',
          value: AppUtils.formatCurrency(expense),
          icon: Icons.north_east,
        ),
        FinancialSummaryMetric(
          label: 'Savings rate',
          value: '${savingsRate.toStringAsFixed(1)}%',
          icon: Icons.savings_outlined,
        ),
      ],
    );
  }

  Widget _sectionHeading({required String title, required String subtitle}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _trendChart(List<_MonthlyTrend> trends) {
    final theme = Theme.of(context);
    final values = [
      for (final trend in trends) trend.income,
      for (final trend in trends) trend.expense,
      for (final trend in trends) trend.balance,
    ];
    final rawMin = values.reduce(math.min);
    final rawMax = values.reduce(math.max);
    final rawRange = rawMax - rawMin;
    final padding = rawRange == 0
        ? math.max(rawMax.abs() * 0.1, 1)
        : rawRange * 0.1;
    final minY = rawMin < 0 ? rawMin - padding : 0.0;
    final maxY = math.max(rawMax + padding, 1.0);
    final interval = (maxY - minY) / 4;

    List<FlSpot> spots(double Function(_MonthlyTrend) value) => trends.indexed
        .map((entry) => FlSpot(entry.$1.toDouble(), value(entry.$2)))
        .toList();

    return _surfaceCard(
      child: Column(
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              _LegendItem(label: 'Income', color: _incomeColor),
              _LegendItem(label: 'Expense', color: _expenseColor),
              _LegendItem(label: 'Balance', color: _balanceColor),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 255,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 5,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.outlineVariant,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
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
                      reservedSize: 50,
                      interval: interval,
                      getTitlesWidget: (value, _) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          _compactAmount(value),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= trends.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('MMM').format(trends[index].month),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final label = switch (spot.barIndex) {
                        0 => 'Income',
                        1 => 'Expense',
                        _ => 'Balance',
                      };
                      final color = switch (spot.barIndex) {
                        0 => _incomeColor,
                        1 => _expenseColor,
                        _ => _balanceColor,
                      };
                      return LineTooltipItem(
                        '$label\n${AppUtils.formatCurrency(spot.y)}',
                        TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  _lineData(
                    spots: spots((item) => item.income),
                    color: _incomeColor,
                  ),
                  _lineData(
                    spots: spots((item) => item.expense),
                    color: _expenseColor,
                  ),
                  _lineData(
                    spots: spots((item) => item.balance),
                    color: _balanceColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _lineData({
    required List<FlSpot> spots,
    required Color color,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: 3,
          color: Theme.of(context).colorScheme.surface,
          strokeColor: color,
          strokeWidth: 2,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _metricsGrid({
    required double averageExpense,
    required _MonthlyTrend? highestMonth,
    required _MonthlyTrend? lowestMonth,
    required double balance,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: itemWidth,
              child: _metricCard(
                title: 'Average expense',
                value: AppUtils.formatCurrency(averageExpense),
                subtitle: 'Monthly average',
                icon: Icons.calculate_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _metricCard(
                title: 'Highest month',
                value: highestMonth == null
                    ? 'No data'
                    : DateFormat('MMMM').format(highestMonth.month),
                subtitle: highestMonth == null
                    ? 'No spending recorded'
                    : AppUtils.formatCurrency(highestMonth.expense),
                icon: Icons.trending_up,
                color: _expenseColor,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _metricCard(
                title: 'Lowest month',
                value: lowestMonth == null
                    ? 'No data'
                    : DateFormat('MMMM').format(lowestMonth.month),
                subtitle: lowestMonth == null
                    ? 'No spending recorded'
                    : AppUtils.formatCurrency(lowestMonth.expense),
                icon: Icons.trending_down,
                color: _incomeColor,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _metricCard(
                title: 'Net balance',
                value: AppUtils.formatCurrency(balance),
                subtitle: 'Across six months',
                icon: Icons.account_balance_wallet_outlined,
                color: balance >= 0 ? _balanceColor : _expenseColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return _surfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightsCard({
    required List<_MonthlyTrend> trends,
    required _MonthlyTrend? highestMonth,
    required _MonthlyTrend? lowestMonth,
    required double averageExpense,
    required List<_CategoryChange> categoryChanges,
  }) {
    final insights = <String>[];
    if (highestMonth != null) {
      insights.add(
        '${DateFormat('MMMM').format(highestMonth.month)} had the highest '
        'spending at ${AppUtils.formatCurrency(highestMonth.expense)}.',
      );
    }
    if (lowestMonth != null && lowestMonth.month != highestMonth?.month) {
      insights.add(
        '${DateFormat('MMMM').format(lowestMonth.month)} had the lowest '
        'spending at ${AppUtils.formatCurrency(lowestMonth.expense)}.',
      );
    }
    insights.add(
      'Your average monthly expense was ${AppUtils.formatCurrency(averageExpense)}.',
    );

    final current = trends.last;
    final previous = trends[trends.length - 2];
    if (previous.expense > 0) {
      final change =
          (current.expense - previous.expense) / previous.expense * 100;
      if (change > 0) {
        insights.add(
          'Spending increased ${change.toStringAsFixed(1)}% compared with '
          'last month.',
        );
      } else if (change < 0) {
        insights.add(
          'Spending decreased ${change.abs().toStringAsFixed(1)}% compared '
          'with last month.',
        );
      } else {
        insights.add('Spending was unchanged compared with last month.');
      }
    } else if (current.expense > 0) {
      insights.add(
        'You recorded spending this month after no spending last month.',
      );
    }

    if (categoryChanges.isNotEmpty) {
      final topChange = categoryChanges.first;
      if (topChange.previous == 0) {
        insights.add(
          '${topChange.name} is a new spending category this month.',
        );
      } else if (topChange.difference > 0) {
        insights.add(
          '${topChange.name} spending increased '
          '${topChange.percentage!.abs().toStringAsFixed(1)}% compared with '
          'last month.',
        );
      } else if (topChange.difference < 0) {
        insights.add(
          '${topChange.name} spending decreased '
          '${topChange.percentage!.abs().toStringAsFixed(1)}% compared with '
          'last month.',
        );
      }
    }

    final theme = Theme.of(context);
    return _surfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var index = 0; index < insights.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    color: theme.colorScheme.primary,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insights[index],
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
            if (index < insights.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _categoryChangeCard(_CategoryChange change) {
    final theme = Theme.of(context);
    final isNew = change.previous == 0;
    final increased = change.difference > 0;
    final color = isNew
        ? Colors.orange
        : increased
        ? _expenseColor
        : change.difference < 0
        ? _incomeColor
        : theme.colorScheme.onSurfaceVariant;
    final icon = isNew
        ? Icons.fiber_new_outlined
        : increased
        ? Icons.trending_up
        : change.difference < 0
        ? Icons.trending_down
        : Icons.remove;
    final changeLabel = isNew
        ? 'New'
        : change.difference == 0
        ? 'No change'
        : '${increased ? '+' : '-'}'
              '${change.percentage!.abs().toStringAsFixed(1)}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppUtils.formatCurrency(change.previous)} → '
                  '${AppUtils.formatCurrency(change.current)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              changeLabel,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCategoryChanges() {
    final theme = Theme.of(context);
    return _surfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            'No category changes available',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add expenses in both months to compare categories.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  String _compactAmount(double amount) {
    final absolute = amount.abs();
    final value = absolute >= 1000000
        ? '${(absolute / 1000000).toStringAsFixed(1)}M'
        : absolute >= 1000
        ? '${(absolute / 1000).toStringAsFixed(0)}K'
        : absolute.toStringAsFixed(0);
    return '${amount < 0 ? '-' : ''}৳$value';
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
