import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/export_service.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/monthly_saving.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/monthly_saving_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/error_view.dart';
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
typedef _CategoryTotal = ({String id, String name, double amount});

enum _TrendMode { all, expense, income }

class TrendAnalysisPage extends ConsumerStatefulWidget {
  const TrendAnalysisPage({super.key});

  @override
  ConsumerState<TrendAnalysisPage> createState() => _TrendAnalysisPageState();
}

class _TrendAnalysisPageState extends ConsumerState<TrendAnalysisPage> {
  Color get _incomeColor => Theme.of(context).colorScheme.tertiary;
  Color get _expenseColor => Theme.of(context).colorScheme.error;
  Color get _balanceColor => Theme.of(context).colorScheme.primary;
  final ExportService _exportService = const ExportService();

  late DateTime _selectedMonth;
  _TrendMode _mode = _TrendMode.all;
  bool _exporting = false;

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
    final transactions = transactionsAsync.valueOrNull;
    final categories = categoriesAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 64,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'POCKET LEDGER',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 9,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              'Trend analysis',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export trend report',
            onPressed: _exporting || transactions == null || categories == null
                ? null
                : () => _exportTrendReport(transactions, categories),
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _TrendBackdrop()),
          Positioned.fill(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  ErrorView(message: 'Unable to load transactions\n$error'),
              data: (transactions) => categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    ErrorView(message: 'Unable to load categories\n$error'),
                data: (categories) => savingsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ErrorView(
                    message: 'Unable to load monthly savings\n$error',
                  ),
                  data: (savingEntries) => _buildContent(
                    transactions: transactions,
                    categories: categories,
                    savingEntries: savingEntries,
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final selectedType = switch (_mode) {
      _TrendMode.all => null,
      _TrendMode.expense => TransactionType.expense,
      _TrendMode.income => TransactionType.income,
    };
    final categoryChanges = selectedType == null
        ? _buildCategoryChanges(
            transactions,
            categories,
            type: TransactionType.expense,
          )
        : _buildCategoryChanges(transactions, categories, type: selectedType);
    final incomeChanges = selectedType == null
        ? _buildCategoryChanges(
            transactions,
            categories,
            type: TransactionType.income,
          )
        : const <_CategoryChange>[];
    final categoryTotals = selectedType == null
        ? const <_CategoryTotal>[]
        : _buildCategoryTotals(transactions, categories, type: selectedType);
    final totalIncome = trends.fold<double>(
      0,
      (sum, item) => sum + item.income,
    );
    final totalExpense = trends.fold<double>(
      0,
      (sum, item) => sum + item.expense,
    );
    final averageExpense = totalExpense / trends.length;
    final valueForMode = _mode == _TrendMode.income
        ? (_MonthlyTrend item) => item.income
        : (_MonthlyTrend item) => item.expense;
    final monthsWithActivity = trends
        .where((item) => valueForMode(item) > 0)
        .toList();
    final highestMonth = _extremeMonth(
      monthsWithActivity,
      value: valueForMode,
      highest: true,
    );
    final lowestMonth = _extremeMonth(
      monthsWithActivity,
      value: valueForMode,
      highest: false,
    );
    final balance = totalIncome - totalExpense;
    final modeTotal = switch (_mode) {
      _TrendMode.all => balance,
      _TrendMode.expense => totalExpense,
      _TrendMode.income => totalIncome,
    };
    final modeAverage = switch (_mode) {
      _TrendMode.all => averageExpense,
      _TrendMode.expense => averageExpense,
      _TrendMode.income => totalIncome / trends.length,
    };
    final incomeCategoryTotals = _buildCategoryTotals(
      transactions,
      categories,
      type: TransactionType.income,
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _monthSelector(),
          const SizedBox(height: 16),
          _modeSelector(),
          const SizedBox(height: 14),
          _overviewCard(
            mode: _mode,
            trends: trends,
            transactions: transactions,
            categories: categories,
          ),
          const SizedBox(height: 18),
          _trendChart(
            trends,
            mode: _mode,
            transactions: transactions,
            categories: categories,
          ),
          if (_mode == _TrendMode.all) ...[
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
              mode: _mode,
              averageAmount: modeAverage,
              highestMonth: highestMonth,
              lowestMonth: lowestMonth,
              balance: balance,
            ),
            const SizedBox(height: 18),
            _insightsCard(
              trends: trends,
              mode: _mode,
              highestMonth: highestMonth,
              lowestMonth: lowestMonth,
              averageAmount: modeAverage,
              categoryChanges: categoryChanges,
            ),
            const SizedBox(height: 18),
            _movementBreakdown(
              mode: _mode,
              expenseChanges: categoryChanges,
              incomeChanges: incomeChanges,
            ),
            const SizedBox(height: 18),
            _runRateCard(trends: trends, mode: _mode),
          ],
          if (_mode == _TrendMode.expense) ...[
            const SizedBox(height: 18),
            _categoryBreakdown(
              totals: categoryTotals,
              total: modeTotal,
              type: TransactionType.expense,
            ),
            const SizedBox(height: 18),
            _movementBreakdown(
              mode: _mode,
              expenseChanges: categoryChanges,
              incomeChanges: const [],
            ),
            const SizedBox(height: 18),
            _expenseRecommendations(categoryChanges),
          ],
          if (_mode == _TrendMode.income) ...[
            const SizedBox(height: 18),
            _categoryBreakdown(
              totals: incomeCategoryTotals,
              total: totalIncome,
              type: TransactionType.income,
            ),
            const SizedBox(height: 18),
            _movementBreakdown(
              mode: _mode,
              expenseChanges: const [],
              incomeChanges: categoryChanges,
            ),
            const SizedBox(height: 18),
            _runRateCard(trends: trends, mode: _mode),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _exporting
                ? null
                : () => _exportTrendReport(transactions, categories),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(switch (_mode) {
              _TrendMode.all => 'Export trend report (PDF)',
              _TrendMode.expense => 'Export expense report (PDF)',
              _TrendMode.income => 'Export income report (PDF)',
            }),
          ),
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

  Future<void> _exportTrendReport(
    List<Transaction> transactions,
    List<Category> categories,
  ) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final firstMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 5);
    final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final selectedType = switch (_mode) {
      _TrendMode.all => null,
      _TrendMode.expense => TransactionType.expense,
      _TrendMode.income => TransactionType.income,
    };

    try {
      await _exportService.exportAndShare(
        transactions: transactions,
        categories: categories,
        options: ExportOptions(
          fileType: ExportFileType.pdf,
          period: ExportPeriod.customRange,
          startDate: firstMonth,
          endDate: endDate,
          transactionType: selectedType,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trend report is ready to share.')),
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to export trend report: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
    List<Category> categories, {
    required TransactionType type,
  }) {
    final names = {
      for (final category in categories) category.id: category.name,
    };
    final currentTotals = <String, double>{};
    final previousTotals = <String, double>{};

    for (final transaction in transactions) {
      if (transaction.type != type) continue;
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

  List<_CategoryTotal> _buildCategoryTotals(
    List<Transaction> transactions,
    List<Category> categories, {
    required TransactionType type,
  }) {
    final names = {
      for (final category in categories) category.id: category.name,
    };
    final totals = <String, double>{};
    final start = DateTime(_selectedMonth.year, _selectedMonth.month - 5);

    for (final transaction in transactions) {
      if (transaction.type != type) continue;
      final date = transaction.date.toLocal();
      final month = DateTime(date.year, date.month);
      if (month.isBefore(start) || month.isAfter(_selectedMonth)) continue;
      totals.update(
        transaction.categoryId,
        (amount) => amount + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final result =
        totals.entries
            .map(
              (entry) => (
                id: entry.key,
                name: names[entry.key] ?? 'Other',
                amount: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  _MonthlyTrend? _extremeMonth(
    List<_MonthlyTrend> months, {
    required double Function(_MonthlyTrend) value,
    required bool highest,
  }) {
    if (months.isEmpty) return null;
    return months.reduce(
      (best, next) => highest
          ? (value(next) > value(best) ? next : best)
          : (value(next) < value(best) ? next : best),
    );
  }

  Widget _modeSelector() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          for (final mode in _TrendMode.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _TrendModeChip(
                  label: switch (mode) {
                    _TrendMode.all => 'All trends',
                    _TrendMode.expense => 'Expense view',
                    _TrendMode.income => 'Income view',
                  },
                  selected: mode == _mode,
                  indicatorColor: switch (mode) {
                    _TrendMode.all => theme.colorScheme.primary,
                    _TrendMode.expense => _expenseColor,
                    _TrendMode.income => _incomeColor,
                  },
                  selectedColor: theme.colorScheme.primaryContainer,
                  selectedForegroundColor: theme.colorScheme.onPrimaryContainer,
                  onTap: () => setState(() => _mode = mode),
                ),
              ),
            ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .35),
        ),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: theme.colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${DateFormat('MMM yyyy').format(DateTime(_selectedMonth.year, _selectedMonth.month - 5))}'
                        ' – ${DateFormat('MMM yyyy').format(_selectedMonth)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                Text(
                  isCurrentMonth ? 'Latest six months' : 'Six months',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
    required _TrendMode mode,
    required List<_MonthlyTrend> trends,
    required List<Transaction> transactions,
    required List<Category> categories,
  }) {
    final theme = Theme.of(context);
    final income = trends.fold<double>(0, (sum, month) => sum + month.income);
    final expense = trends.fold<double>(0, (sum, month) => sum + month.expense);
    final balance = income - expense;
    final savingsRate = income <= 0 ? 0.0 : balance / income * 100;
    final start = DateFormat('MMM')
        .format(DateTime(_selectedMonth.year, _selectedMonth.month - 5));
    final end = DateFormat('MMM yyyy').format(_selectedMonth);
    final periodEnd = DateTime(_selectedMonth.year, _selectedMonth.month - 6);
    final previousIncome = _periodTotal(
      transactions,
      TransactionType.income,
      endMonth: periodEnd,
    );
    final previousExpense = _periodTotal(
      transactions,
      TransactionType.expense,
      endMonth: periodEnd,
    );
    final highest = _extremeMonth(
      trends
          .where(
            (month) =>
                (mode == _TrendMode.expense ? month.expense : month.income) > 0,
          )
          .toList(),
      value: (month) =>
          mode == _TrendMode.expense ? month.expense : month.income,
      highest: true,
    );
    final lowest = _extremeMonth(
      trends
          .where(
            (month) =>
                (mode == _TrendMode.expense ? month.expense : month.income) > 0,
          )
          .toList(),
      value: (month) =>
          mode == _TrendMode.expense ? month.expense : month.income,
      highest: false,
    );
    final incomeSources = _buildCategoryTotals(
      transactions,
      categories,
      type: TransactionType.income,
    ).length;
    final activeIncomeMonths = trends.where((month) => month.income > 0).length;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: switch (mode) {
            _TrendMode.all => const [
              Color(0xFF2A14B4),
              Color(0xFF4338CA),
              Color(0xFF712AE2),
            ],
            _TrendMode.expense => const [
              Color(0xFF1E1069),
              Color(0xFF372ABF),
              Color(0xFF801B44),
            ],
            _TrendMode.income => const [
              Color(0xFF4338CA),
              Color(0xFF2E2692),
              Color(0xFF005E40),
            ],
          },
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .2)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: .25),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -48,
            child: _heroGlow(145, Colors.white.withValues(alpha: .09)),
          ),
          Positioned(
            right: 20,
            bottom: -70,
            child: _heroGlow(140, Colors.white.withValues(alpha: .06)),
          ),
          if (mode != _TrendMode.all)
            Positioned(
              right: -25,
              top: 18,
              child: _HeroRings(color: Colors.white.withValues(alpha: .13)),
            ),
          Padding(
            padding: const EdgeInsets.all(19),
            child: switch (mode) {
              _TrendMode.all => _allHeroContent(
                income: income,
                expense: expense,
                balance: balance,
                previousBalance: previousIncome - previousExpense,
                savingsRate: savingsRate,
                start: start,
                end: end,
              ),
              _TrendMode.expense => _expenseHeroContent(
                total: expense,
                average: expense / 6,
                highest: highest,
                lowest: lowest,
                income: income,
                expense: expense,
                previousExpense: previousExpense,
                start: start,
                end: end,
              ),
              _TrendMode.income => _incomeHeroContent(
                total: income,
                average: income / 6,
                highest: highest,
                sourceCount: incomeSources,
                activeMonths: activeIncomeMonths,
                previousIncome: previousIncome,
                start: start,
                end: end,
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _allHeroContent({
    required double income,
    required double expense,
    required double balance,
    required double previousBalance,
    required double savingsRate,
    required String start,
    required String end,
  }) {
    final theme = Theme.of(context);
    final retention = income <= 0 ? 0.0 : (balance / income).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _proBadge(),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Net Cash Flow (6 Months)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: .85),
                ),
              ),
            ),
            _comparisonBadge(balance, previousBalance, compact: true),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${balance < 0 ? '−' : ''}${AppUtils.formatCurrency(balance.abs())}',
                  maxLines: 1,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'BDT',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: .8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Icon(Icons.circle, size: 7, color: _mint),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '${savingsRate.clamp(0, 100).toStringAsFixed(1)}% Inflow retained',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${(100 - savingsRate).clamp(0, 100).toStringAsFixed(1)}% Outflow',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: .8),
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.circle, size: 7, color: _rose),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 7,
            child: LinearProgressIndicator(
              value: retention,
              backgroundColor: _rose,
              valueColor: const AlwaysStoppedAnimation<Color>(_mint),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: Colors.white.withValues(alpha: .2)),
        const SizedBox(height: 10),
        Row(
          children: [
            _heroSimpleMetric('Income', AppUtils.formatCurrency(income)),
            _heroDivider(),
            _heroSimpleMetric('Expense', AppUtils.formatCurrency(expense)),
            _heroDivider(),
            _heroSimpleMetric('Savings', '${savingsRate.toStringAsFixed(1)}%'),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '$start – $end',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: .65),
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _expenseHeroContent({
    required double total,
    required double average,
    required _MonthlyTrend? highest,
    required _MonthlyTrend? lowest,
    required double income,
    required double expense,
    required double previousExpense,
    required String start,
    required String end,
  }) {
    final theme = Theme.of(context);
    final ratio = income <= 0 ? 0.0 : (expense / income).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _proBadge(),
            const Spacer(),
            const Icon(
              Icons.analytics_outlined,
              color: Colors.white70,
              size: 19,
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          'Total 6-Month Expense Outflow · $start–$end',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: .84),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  AppUtils.formatCurrency(total),
                  maxLines: 1,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _comparisonBadge(total, previousExpense),
          ],
        ),
        const SizedBox(height: 13),
        Divider(height: 1, color: Colors.white.withValues(alpha: .2)),
        const SizedBox(height: 12),
        Row(
          children: [
            _heroLabeledValue('Monthly avg', AppUtils.formatCurrency(average)),
            _heroLabeledValue(
              'Peak month',
              highest == null
                  ? 'No activity'
                  : '${DateFormat('MMM').format(highest.month)}: ${AppUtils.formatCurrency(highest.expense)}',
              color: _rose,
            ),
            _heroLabeledValue(
              'Lowest month',
              lowest == null
                  ? 'No activity'
                  : '${DateFormat('MMM').format(lowest.month)}: ${AppUtils.formatCurrency(lowest.expense)}',
              color: _mint,
            ),
          ],
        ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .2),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.speed_rounded, size: 15, color: _mint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      income <= 0
                          ? 'Outflow ratio · no income recorded'
                          : 'Outflow ratio · ${(expense / income * 100).toStringAsFixed(1)}% of inflow',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: .9),
                      ),
                    ),
                  ),
                  Text(
                    income > 0 && ratio < .3 ? 'EXCELLENT' : 'HIGH',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: income > 0 && ratio < .3 ? _mint : _rose,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: .17),
                  valueColor: const AlwaysStoppedAnimation<Color>(_mint),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _incomeHeroContent({
    required double total,
    required double average,
    required _MonthlyTrend? highest,
    required int sourceCount,
    required int activeMonths,
    required double previousIncome,
    required String start,
    required String end,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _proBadge(),
            const Spacer(),
            _comparisonBadge(total, previousIncome, compact: true),
          ],
        ),
        const SizedBox(height: 11),
        Text(
          'Total 6-Month Income Inflow · $start–$end',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: .82),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  AppUtils.formatCurrency(total),
                  maxLines: 1,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'BDT Gross',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .17)),
          ),
          child: Row(
            children: [
              Icon(Icons.health_and_safety_outlined, color: _mint, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Income recorded in $activeMonths of 6 months',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$sourceCount ${sourceCount == 1 ? 'source' : 'sources'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _mint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: Colors.white.withValues(alpha: .2)),
        const SizedBox(height: 10),
        Row(
          children: [
            _heroBentoMetric('Monthly avg', AppUtils.formatCurrency(average)),
            const SizedBox(width: 7),
            _heroBentoMetric(
              'Peak month',
              highest == null
                  ? 'No activity'
                  : DateFormat('MMM').format(highest.month),
              detail: highest == null
                  ? null
                  : AppUtils.formatCurrency(highest.income),
            ),
            const SizedBox(width: 7),
            _heroBentoMetric('Sources', '$sourceCount active'),
          ],
        ),
      ],
    );
  }

  Widget _proBadge() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: _mint),
          const SizedBox(width: 5),
          Text(
            'POCKET LEDGER',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize: 9,
              letterSpacing: .4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonBadge(
    double current,
    double previous, {
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final difference = previous == 0
        ? null
        : (current - previous) / previous.abs() * 100;
    final label = difference == null
        ? current == 0
              ? 'No change'
              : 'New activity'
        : '${difference > 0 ? '+' : ''}${difference.toStringAsFixed(1)}%';
    final up = difference == null ? current > 0 : difference >= 0;
    final color = up ? _mint : _rose;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            compact ? label : '$label vs prev 6 mo',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroSimpleMetric(String label, String value) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: .72),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() => Container(
    width: 1,
    height: 35,
    margin: const EdgeInsets.symmetric(horizontal: 9),
    color: Colors.white.withValues(alpha: .2),
  );

  Widget _heroLabeledValue(
    String label,
    String value, {
    Color color = Colors.white,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: .66),
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroBentoMetric(String label, String value, {String? detail}) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 65),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: .7),
                fontSize: 8,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (detail != null)
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _mint,
                  fontSize: 8,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _heroGlow(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );

  double _periodTotal(
    List<Transaction> transactions,
    TransactionType type, {
    required DateTime endMonth,
  }) {
    final start = DateTime(endMonth.year, endMonth.month - 5);
    return transactions
        .where((transaction) {
          final date = transaction.date.toLocal();
          final month = DateTime(date.year, date.month);
          return transaction.type == type &&
              !month.isBefore(start) &&
              !month.isAfter(endMonth);
        })
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  static const _mint = Color(0xFF85F8C4);
  static const _rose = Color(0xFFFFB4AB);

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

  Widget _trendChart(
    List<_MonthlyTrend> trends, {
    required _TrendMode mode,
    required List<Transaction> transactions,
    required List<Category> categories,
  }) {
    final theme = Theme.of(context);
    final series = <(String, Color, List<double>)>[];
    if (mode == _TrendMode.all) {
      series.addAll([
        ('Income', _incomeColor, trends.map((item) => item.income).toList()),
        ('Expense', _expenseColor, trends.map((item) => item.expense).toList()),
        ('Balance', _balanceColor, trends.map((item) => item.balance).toList()),
      ]);
    } else if (mode == _TrendMode.expense) {
      series.add((
        'Expense',
        _expenseColor,
        trends.map((item) => item.expense).toList(),
      ));
    } else {
      final sourceTotals = _buildCategoryTotals(
        transactions,
        categories,
        type: TransactionType.income,
      );
      final sourceColors = [_incomeColor, _balanceColor, _expenseColor];
      for (final (index, source) in sourceTotals.take(3).indexed) {
        final monthlyAmounts = [
          for (final trend in trends)
            transactions
                .where((transaction) {
                  final date = transaction.date.toLocal();
                  return transaction.type == TransactionType.income &&
                      transaction.categoryId == source.id &&
                      date.year == trend.month.year &&
                      date.month == trend.month.month;
                })
                .fold<double>(
                  0,
                  (sum, transaction) => sum + transaction.amount,
                ),
        ];
        series.add((source.name, sourceColors[index], monthlyAmounts));
      }
      if (series.isEmpty) {
        series.add((
          'Income',
          _incomeColor,
          trends.map((item) => item.income).toList(),
        ));
      }
    }
    final values = series.expand((item) => item.$3);
    final rawMin = values.reduce(math.min);
    final rawMax = values.reduce(math.max);
    final rawRange = rawMax - rawMin;
    final padding = rawRange == 0
        ? math.max(rawMax.abs() * 0.1, 1)
        : rawRange * 0.1;
    final minY = rawMin < 0 ? rawMin - padding : 0.0;
    final maxY = math.max(rawMax + padding, 1.0);
    final interval = (maxY - minY) / 4;

    final heading = switch (mode) {
      _TrendMode.all => 'Income vs expense trend',
      _TrendMode.expense => 'Monthly expense trajectory',
      _TrendMode.income => 'Income growth trajectory',
    };
    final subtitle = switch (mode) {
      _TrendMode.all => 'Monthly cash flow across the selected period',
      _TrendMode.expense => 'Monthly outflow and variation',
      _TrendMode.income => 'Monthly income by source',
    };
    final peakExpense = trends.reduce(
      (best, item) => item.expense > best.expense ? item : best,
    );
    final topSource = mode == _TrendMode.income
        ? _buildCategoryTotals(
            transactions,
            categories,
            type: TransactionType.income,
          ).firstOrNull
        : null;

    return _surfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _chartContextLabel(mode, series.length),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in series)
                _LegendPill(label: item.$1, color: item.$2),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (trends.length - 1).toDouble(),
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
                      reservedSize: 38,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= trends.length) {
                          return const SizedBox.shrink();
                        }
                        final amount = switch (mode) {
                          _TrendMode.all => trends[index].balance,
                          _TrendMode.expense => trends[index].expense,
                          _TrendMode.income => trends[index].income,
                        };
                        final isPeak =
                            mode == _TrendMode.expense &&
                            trends[index].month == peakExpense.month;
                        return Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('MMM').format(trends[index].month),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isPeak
                                      ? _expenseColor
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: isPeak
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  fontSize: 9,
                                ),
                              ),
                              Text(
                                _compactAmount(amount),
                                maxLines: 1,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 8,
                                ),
                              ),
                            ],
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
                      final seriesItem = series[spot.barIndex];
                      return LineTooltipItem(
                        '${seriesItem.$1}\n${AppUtils.formatCurrency(spot.y)}',
                        TextStyle(
                          color: seriesItem.$2,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  for (final item in series)
                    _lineData(
                      spots: item.$3.indexed
                          .map((entry) => FlSpot(entry.$1.toDouble(), entry.$2))
                          .toList(),
                      color: item.$2,
                    ),
                ],
              ),
            ),
          ),
          if (mode == _TrendMode.expense && peakExpense.expense > 0) ...[
            const SizedBox(height: 10),
            _chartTakeaway(
              icon: Icons.info_outline_rounded,
              color: _expenseColor,
              text:
                  '${DateFormat('MMMM').format(peakExpense.month)} had the '
                  'highest outflow at '
                  '${AppUtils.formatCurrency(peakExpense.expense)}.',
            ),
          ],
          if (mode == _TrendMode.income &&
              topSource != null &&
              topSource.amount > 0) ...[
            const SizedBox(height: 10),
            _chartTakeaway(
              icon: Icons.bolt_rounded,
              color: _incomeColor,
              text:
                  '${topSource.name} contributed '
                  '${(topSource.amount / trends.fold<double>(0, (sum, item) => sum + item.income) * 100).toStringAsFixed(1)}% '
                  'of recorded income in this period.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _chartContextLabel(_TrendMode mode, int seriesCount) {
    final theme = Theme.of(context);
    final label = switch (mode) {
      _TrendMode.all => '6 MONTHS',
      _TrendMode.expense => 'PEAK MONTH',
      _TrendMode.income => '$seriesCount SOURCES',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _chartTakeaway({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .22), color.withValues(alpha: .015)],
        ),
      ),
    );
  }

  Widget _metricsGrid({
    required _TrendMode mode,
    required double averageAmount,
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
                title: mode == _TrendMode.income
                    ? 'Average income'
                    : 'Average expense',
                value: AppUtils.formatCurrency(averageAmount),
                subtitle: 'Monthly average',
                icon: Icons.calculate_outlined,
                color: mode == _TrendMode.income
                    ? _incomeColor
                    : Theme.of(context).colorScheme.primary,
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
                    ? 'No activity recorded'
                    : AppUtils.formatCurrency(
                        mode == _TrendMode.income
                            ? highestMonth.income
                            : highestMonth.expense,
                      ),
                icon: Icons.trending_up,
                color: mode == _TrendMode.income ? _incomeColor : _expenseColor,
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
                    ? 'No activity recorded'
                    : AppUtils.formatCurrency(
                        mode == _TrendMode.income
                            ? lowestMonth.income
                            : lowestMonth.expense,
                      ),
                icon: Icons.trending_down,
                color: mode == _TrendMode.income ? _balanceColor : _incomeColor,
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

  Widget _categoryBreakdown({
    required List<_CategoryTotal> totals,
    required double total,
    required TransactionType type,
  }) {
    final theme = Theme.of(context);
    final accent = type == TransactionType.income
        ? _incomeColor
        : _expenseColor;

    return _surfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type == TransactionType.income
                ? 'Income sources'
                : 'Category breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Distribution across the selected six-month period',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (totals.isEmpty) ...[
            const SizedBox(height: 14),
            Text(
              type == TransactionType.income
                  ? 'No income recorded in this period.'
                  : 'No expenses recorded in this period.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            for (final (index, entry) in totals.take(6).indexed) ...[
              Container(
                padding: const EdgeInsets.all(11),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow.withValues(
                    alpha: .65,
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _categoryIcon(entry.name),
                            color: accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                total <= 0
                                    ? '0% of total'
                                    : '${(entry.amount / total * 100).toStringAsFixed(1)}% of ${type == TransactionType.income ? 'income' : 'expenses'}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppUtils.formatCurrency(entry.amount),
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (index == 0)
                              Text(
                                type == TransactionType.income
                                    ? 'Top source'
                                    : 'Largest driver',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: accent,
                                  fontSize: 9,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: total <= 0
                            ? 0
                            : (entry.amount / total).clamp(0, 1),
                        minHeight: 5,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  IconData _categoryIcon(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('food') || normalized.contains('dining')) {
      return Icons.restaurant_outlined;
    }
    if (normalized.contains('transport') || normalized.contains('bike')) {
      return Icons.directions_bike_outlined;
    }
    if (normalized.contains('home') || normalized.contains('rent')) {
      return Icons.home_outlined;
    }
    if (normalized.contains('salary') || normalized.contains('job')) {
      return Icons.work_outline_rounded;
    }
    if (normalized.contains('invest') || normalized.contains('dividend')) {
      return Icons.show_chart_rounded;
    }
    if (normalized.contains('bill') || normalized.contains('utilit')) {
      return Icons.receipt_long_outlined;
    }
    if (normalized.contains('health') || normalized.contains('medical')) {
      return Icons.health_and_safety_outlined;
    }
    return Icons.category_outlined;
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
    required _TrendMode mode,
    required _MonthlyTrend? highestMonth,
    required _MonthlyTrend? lowestMonth,
    required double averageAmount,
    required List<_CategoryChange> categoryChanges,
  }) {
    final isIncome = mode == _TrendMode.income;
    double amount(_MonthlyTrend trend) =>
        isIncome ? trend.income : trend.expense;
    final transactionLabel = isIncome ? 'income' : 'spending';
    final insights = <String>[];
    if (highestMonth != null) {
      insights.add(
        '${DateFormat('MMMM').format(highestMonth.month)} had the highest '
        '$transactionLabel at ${AppUtils.formatCurrency(amount(highestMonth))}.',
      );
    }
    if (lowestMonth != null && lowestMonth.month != highestMonth?.month) {
      insights.add(
        '${DateFormat('MMMM').format(lowestMonth.month)} had the lowest '
        '$transactionLabel at ${AppUtils.formatCurrency(amount(lowestMonth))}.',
      );
    }
    insights.add(
      'Your average monthly ${isIncome ? 'income' : 'expense'} was '
      '${AppUtils.formatCurrency(averageAmount)}.',
    );

    final current = trends.last;
    final previous = trends[trends.length - 2];
    if (previous.month.isBefore(_selectedMonth) && amount(previous) > 0) {
      final change =
          (amount(current) - amount(previous)) / amount(previous) * 100;
      if (change > 0) {
        insights.add(
          '${isIncome ? 'Income increased' : 'Spending increased'} '
          '${change.toStringAsFixed(1)}% compared with last month.',
        );
      } else if (change < 0) {
        insights.add(
          '${isIncome ? 'Income decreased' : 'Spending decreased'} '
          '${change.abs().toStringAsFixed(1)}% compared with last month.',
        );
      } else {
        insights.add(
          '${isIncome ? 'Income' : 'Spending'} was unchanged compared with last month.',
        );
      }
    } else if (amount(current) > 0 && _selectedMonth == trends.last.month) {
      insights.add(
        'You recorded ${isIncome ? 'income' : 'spending'} this month after none last month.',
      );
    }

    if (categoryChanges.isNotEmpty) {
      final topChange = categoryChanges.first;
      if (topChange.previous == 0) {
        insights.add(
          '${topChange.name} is a new ${isIncome ? 'income source' : 'spending category'} this month.',
        );
      } else if (topChange.difference > 0) {
        insights.add(
          '${topChange.name} ${isIncome ? 'income' : 'spending'} increased '
          '${topChange.percentage!.abs().toStringAsFixed(1)}% compared with '
          'last month.',
        );
      } else if (topChange.difference < 0) {
        insights.add(
          '${topChange.name} ${isIncome ? 'income' : 'spending'} decreased '
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

  Widget _movementBreakdown({
    required _TrendMode mode,
    required List<_CategoryChange> expenseChanges,
    required List<_CategoryChange> incomeChanges,
  }) {
    final theme = Theme.of(context);
    return _surfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mode == _TrendMode.all
                ? 'Inflow & outflow movement'
                : mode == _TrendMode.income
                ? 'Income stream velocity'
                : 'Category changes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${DateFormat('MMMM').format(_selectedMonth)} vs '
            '${DateFormat('MMMM').format(_previousMonth)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 13),
          if (mode != _TrendMode.income)
            _movementGroup(
              title: mode == _TrendMode.all
                  ? 'Expense movement'
                  : 'Expense categories',
              changes: expenseChanges,
              type: TransactionType.expense,
            ),
          if (mode == _TrendMode.all) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: .4),
            ),
            const SizedBox(height: 12),
          ],
          if (mode != _TrendMode.expense)
            _movementGroup(
              title: mode == _TrendMode.all
                  ? 'Income movement'
                  : 'Income sources',
              changes: incomeChanges,
              type: TransactionType.income,
            ),
        ],
      ),
    );
  }

  Widget _movementGroup({
    required String title,
    required List<_CategoryChange> changes,
    required TransactionType type,
  }) {
    final theme = Theme.of(context);
    final color = type == TransactionType.income ? _incomeColor : _expenseColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: .35,
            ),
          ),
        ),
        if (changes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              type == TransactionType.income
                  ? 'No income source changes this month.'
                  : 'No expense category changes this month.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < changes.length && index < 8;
                  index++
                ) ...[
                  if (index > 0) const Divider(height: 1),
                  _categoryChangeCard(changes[index], type: type),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _categoryChangeCard(
    _CategoryChange change, {
    required TransactionType type,
  }) {
    final theme = Theme.of(context);
    final isNew = change.previous == 0;
    final increased = change.difference > 0;
    final favorable = type == TransactionType.income ? increased : !increased;
    final color = isNew
        ? Colors.orange
        : change.difference == 0
        ? theme.colorScheme.onSurfaceVariant
        : favorable
        ? _incomeColor
        : _expenseColor;
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
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

  Widget _expenseRecommendations(List<_CategoryChange> changes) {
    final theme = Theme.of(context);
    final increases = changes.where((change) => change.difference > 0).length;
    return _surfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Spending changes to review',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Month-over-month category shifts from your recorded expenses.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (changes.isEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Add expenses in this and the previous month to see category changes.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (var index = 0; index < changes.length && index < 3; index++)
              Column(
                children: [
                  if (index > 0) const Divider(height: 1),
                  _categoryChangeCard(
                    changes[index],
                    type: TransactionType.expense,
                  ),
                ],
              ),
          ],
          if (increases > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _chartTakeaway(
                icon: Icons.search_rounded,
                color: theme.colorScheme.primary,
                text:
                    '$increases ${increases == 1 ? 'category is' : 'categories are'} higher than last month. Review the related transactions to understand the change.',
              ),
            ),
        ],
      ),
    );
  }

  Widget _runRateCard({
    required List<_MonthlyTrend> trends,
    required _TrendMode mode,
  }) {
    final theme = Theme.of(context);
    final incomeAverage =
        trends.fold<double>(0, (sum, item) => sum + item.income) /
        trends.length;
    final expenseAverage =
        trends.fold<double>(0, (sum, item) => sum + item.expense) /
        trends.length;
    final isIncome = mode == _TrendMode.income;
    final estimate = isIncome
        ? incomeAverage * 3
        : (incomeAverage - expenseAverage) * 3;
    final title = isIncome
        ? 'Income run-rate estimate'
        : 'Net cash flow run-rate';

    return _surfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                estimate >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: .45,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '3 MONTHS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Simple estimate using the average monthly totals from this six-month period.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppUtils.formatCurrency(estimate),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: estimate >= 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (isIncome)
            _runRateDetail(
              label: 'Monthly income average',
              value: AppUtils.formatCurrency(incomeAverage),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _runRateDetail(
                    label: 'Monthly income average',
                    value: AppUtils.formatCurrency(incomeAverage),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _runRateDetail(
                    label: 'Monthly expense average',
                    value: AppUtils.formatCurrency(expenseAverage),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _runRateDetail({required String label, required String value}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
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
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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

class _TrendBackdrop extends StatelessWidget {
  const _TrendBackdrop();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -110, left: -110, child: _glow(scheme.primary, .12)),
          Positioned(
            top: 340,
            right: -130,
            child: _glow(scheme.secondary, .09),
          ),
          Positioned(
            bottom: 40,
            left: -110,
            child: _glow(scheme.tertiary, .08),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double opacity) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _HeroRings extends StatelessWidget {
  const _HeroRings({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
          ),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendModeChip extends StatelessWidget {
  const _TrendModeChip({
    required this.label,
    required this.selected,
    required this.indicatorColor,
    required this.selectedColor,
    required this.selectedForegroundColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color indicatorColor;
  final Color selectedColor;
  final Color selectedForegroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 42),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: selected
                              ? selectedForegroundColor
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .25),
        ),
      ),
      child: Row(
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
      ),
    );
  }
}
