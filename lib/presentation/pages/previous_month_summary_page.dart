import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/services/export_service.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/monthly_limit.dart';
import '../../domain/entities/monthly_saving.dart';
import '../../domain/entities/transaction.dart';
import '../providers/budget_notification_provider.dart';
import '../providers/category_provider.dart';
import '../providers/limit_provider.dart';
import '../providers/monthly_saving_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/monthly_target_editor_sheet.dart';

class PreviousMonthSummaryPage extends ConsumerStatefulWidget {
  const PreviousMonthSummaryPage({super.key});

  @override
  ConsumerState<PreviousMonthSummaryPage> createState() =>
      _PreviousMonthSummaryPageState();
}

class _PreviousMonthSummaryPageState
    extends ConsumerState<PreviousMonthSummaryPage> {
  final ExportService _exportService = const ExportService();
  ExportFileType? _exportingType;
  bool _savingTarget = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final savingsAsync = ref.watch(allMonthlySavingEntriesProvider);
    final limitAsync = ref.watch(monthlyLimitProvider((now.year, now.month)));
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense summary'),
        actions: [
          IconButton(
            tooltip: 'Export yearly expenses',
            onPressed:
                _exportingType == null && transactionsAsync.valueOrNull != null
                ? () => _showExportOptions(
                    context,
                    transactionsAsync.requireValue,
                  )
                : null,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _SummaryAmbient()),
          transactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _SummaryError(
              message: 'Unable to load expense data.',
              onRetry: () => ref.invalidate(allTransactionsProvider),
            ),
            data: (transactions) => savingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _SummaryError(
                message: 'Unable to load savings data.',
                onRetry: () => ref.invalidate(allMonthlySavingEntriesProvider),
              ),
              data: (savingEntries) => _ExpenseSummaryContent(
                transactions: transactions,
                savingEntries: savingEntries,
                categories: categories,
                currentLimit: limitAsync.valueOrNull,
                targetLoadFailed: limitAsync.hasError,
                currentDate: now,
                exportingType: _exportingType,
                savingTarget: _savingTarget,
                onEditTarget: _editTarget,
                onRetryTarget: () =>
                    ref.invalidate(monthlyLimitProvider((now.year, now.month))),
                onOpenBudgets: () => context.pushNamed(AppRoutes.budgetsName),
                onExport: (type) => _exportYearExpenses(type, transactions),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editTarget({
    required DateTime month,
    required MonthlyLimit? currentLimit,
  }) async {
    final result = await showModalBottomSheet<MonthlyTargetEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          MonthlyTargetEditorSheet(month: month, current: currentLimit),
    );
    if (result == null || !mounted) return;

    setState(() => _savingTarget = true);
    try {
      if (result.remove) {
        await ref
            .read(limitRepositoryProvider)
            .deleteMonthlyLimit(month.year, month.month);
      } else if (result.amount != null) {
        final now = DateTime.now();
        await ref
            .read(limitRepositoryProvider)
            .setMonthlyLimit(
              MonthlyLimit(
                id: currentLimit?.id ?? AppUtils.generateId(),
                year: month.year,
                month: month.month,
                amount: result.amount!,
                createdAt: currentLimit?.createdAt ?? now,
                updatedAt: now,
              ),
            );
      }
      ref.invalidate(monthlyLimitProvider((month.year, month.month)));
      ref.invalidate(allLimitsProvider);
      await reportWidgetBudgetNotificationCheck(ref);
      if (!mounted) return;
      _showMessage(
        result.remove ? 'Monthly target removed.' : 'Monthly target saved.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to update monthly target: $error');
    } finally {
      if (mounted) setState(() => _savingTarget = false);
    }
  }

  Future<void> _showExportOptions(
    BuildContext context,
    List<Transaction> transactions,
  ) async {
    final type = await showModalBottomSheet<ExportFileType>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export yearly expenses',
              style: Theme.of(sheetContext).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Share this year’s expense transactions as a PDF or CSV file.',
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Share PDF'),
              onTap: () => Navigator.pop(sheetContext, ExportFileType.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded),
              title: const Text('Share CSV'),
              onTap: () => Navigator.pop(sheetContext, ExportFileType.csv),
            ),
          ],
        ),
      ),
    );
    if (type != null && mounted) {
      await _exportYearExpenses(type, transactions);
    }
  }

  Future<void> _exportYearExpenses(
    ExportFileType type,
    List<Transaction> transactions,
  ) async {
    if (_exportingType != null) return;
    setState(() => _exportingType = type);
    try {
      final year = DateTime.now().year;
      final yearExpenses = transactions.where((transaction) {
        final date = transaction.date.toLocal();
        return transaction.type == TransactionType.expense && date.year == year;
      }).toList();
      final categories = await ref.read(allCategoriesProvider.future);
      await _exportService.exportAndShare(
        transactions: yearExpenses,
        categories: categories,
        options: ExportOptions(
          fileType: type,
          period: ExportPeriod.all,
          transactionType: TransactionType.expense,
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('Unable to export expenses: $error');
    } finally {
      if (mounted) setState(() => _exportingType = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExpenseSummaryContent extends StatelessWidget {
  const _ExpenseSummaryContent({
    required this.transactions,
    required this.savingEntries,
    required this.categories,
    required this.currentLimit,
    required this.targetLoadFailed,
    required this.currentDate,
    required this.exportingType,
    required this.savingTarget,
    required this.onEditTarget,
    required this.onRetryTarget,
    required this.onOpenBudgets,
    required this.onExport,
  });

  final List<Transaction> transactions;
  final List<MonthlySavingEntry> savingEntries;
  final List<Category> categories;
  final MonthlyLimit? currentLimit;
  final bool targetLoadFailed;
  final DateTime currentDate;
  final ExportFileType? exportingType;
  final bool savingTarget;
  final Future<void> Function({
    required DateTime month,
    required MonthlyLimit? currentLimit,
  })
  onEditTarget;
  final VoidCallback onRetryTarget;
  final VoidCallback onOpenBudgets;
  final ValueChanged<ExportFileType> onExport;

  @override
  Widget build(BuildContext context) {
    final year = currentDate.year;
    final month = DateTime(year, currentDate.month);
    final previousMonth = DateTime(year, currentDate.month - 1);
    final monthlyTotals = List<double>.generate(
      12,
      (index) => index + 1 > currentDate.month
          ? 0.0
          : _expenseForMonth(transactions, year, index + 1),
    );
    final currentExpense = monthlyTotals[currentDate.month - 1];
    final previousExpense = _expenseForMonth(
      transactions,
      previousMonth.year,
      previousMonth.month,
    );
    final yearToDate = monthlyTotals
        .take(currentDate.month)
        .fold<double>(0, (sum, amount) => sum + amount);
    final monthlyAverage = yearToDate / currentDate.month;
    final peakMonthIndex = _peakMonth(monthlyTotals, currentDate.month);
    final peakTotal = peakMonthIndex < 0 ? 0.0 : monthlyTotals[peakMonthIndex];
    final difference = currentExpense - previousExpense;
    final percentageChange = previousExpense == 0
        ? null
        : difference / previousExpense * 100;
    final target = currentLimit?.amount;
    final targetUsage = target == null || target <= 0
        ? 0.0
        : currentExpense / target;
    final peakCategory = _peakCategory(
      transactions,
      categories,
      year,
      peakMonthIndex + 1,
    );
    final savingsTotals = List<double>.generate(12, (index) {
      final monthNumber = index + 1;
      if (monthNumber > currentDate.month) return 0.0;
      return savingEntries
          .where((entry) => entry.year == year && entry.month == monthNumber)
          .fold<double>(0, (sum, entry) => sum + entry.amount);
    });
    final peakSavingsMonth = _peakMonth(savingsTotals, currentDate.month);
    final peakSavingsAmount = peakSavingsMonth < 0
        ? 0.0
        : savingsTotals[peakSavingsMonth];
    final forecastTotal = currentDate.month == 0
        ? 0.0
        : yearToDate / currentDate.month * 12;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _OverviewBadge(year: year),
          const SizedBox(height: 12),
          _YearHeroCard(
            total: yearToDate,
            monthlyAverage: monthlyAverage,
            peakMonth: peakMonthIndex < 0
                ? null
                : DateTime(year, peakMonthIndex + 1),
            peakTotal: peakTotal,
          ),
          const SizedBox(height: 14),
          _ComparisonCard(
            month: month,
            previousMonth: previousMonth,
            currentExpense: currentExpense,
            previousExpense: previousExpense,
            difference: difference,
            percentageChange: percentageChange,
          ),
          const SizedBox(height: 14),
          _TargetCard(
            month: month,
            expense: currentExpense,
            target: target,
            usage: targetUsage,
            targetLoadFailed: targetLoadFailed,
            saving: savingTarget,
            onEdit: () =>
                onEditTarget(month: month, currentLimit: currentLimit),
            onRetry: onRetryTarget,
            onBudgets: onOpenBudgets,
          ),
          const SizedBox(height: 14),
          _ChartCard(
            title: 'This year’s expenses',
            subtitle: 'Monthly expense breakdown · $year',
            badge: 'BDT',
            footer: peakMonthIndex < 0
                ? 'No expenses recorded this year'
                : 'Highest: ${DateFormat('MMMM').format(DateTime(year, peakMonthIndex + 1))} · ${AppUtils.formatCurrency(peakTotal)}',
            child: _ExpenseBarChart(
              totals: monthlyTotals,
              currentMonth: currentDate.month,
              peakMonth: peakMonthIndex,
              year: year,
            ),
          ),
          const SizedBox(height: 14),
          _ChartCard(
            title: 'This year’s savings',
            subtitle: 'Saved amount by month · $year',
            badge: 'BDT',
            footer: peakSavingsMonth < 0
                ? 'No savings recorded this year'
                : 'Highest: ${DateFormat('MMMM').format(DateTime(year, peakSavingsMonth + 1))} · ${AppUtils.formatCurrency(peakSavingsAmount)}',
            child: _ExpenseBarChart(
              totals: savingsTotals,
              currentMonth: currentDate.month,
              peakMonth: peakSavingsMonth,
              year: year,
            ),
          ),
          const SizedBox(height: 14),
          _InsightCard(
            currentExpense: currentExpense,
            previousExpense: previousExpense,
            currentYearTotal: yearToDate,
            target: target,
          ),
          const SizedBox(height: 14),
          _ForecastCard(
            year: year,
            spent: yearToDate,
            forecast: forecastTotal,
            monthlyTotals: monthlyTotals,
            currentMonth: currentDate.month,
            peakCategory: peakCategory,
          ),
          const SizedBox(height: 14),
          _ExportCard(exportingType: exportingType, onExport: onExport),
          if (yearToDate == 0) ...[
            const SizedBox(height: 14),
            const _EmptyExpenseNote(),
          ],
        ],
      ),
    );
  }
}

double _expenseForMonth(List<Transaction> transactions, int year, int month) {
  return transactions
      .where((transaction) {
        final date = transaction.date.toLocal();
        return transaction.type == TransactionType.expense &&
            date.year == year &&
            date.month == month;
      })
      .fold<double>(0, (sum, transaction) => sum + transaction.amount);
}

int _peakMonth(List<double> totals, int monthCount) {
  if (monthCount <= 0) return -1;
  var highestIndex = -1;
  for (var index = 0; index < monthCount; index++) {
    if (totals[index] > 0 &&
        (highestIndex < 0 || totals[index] > totals[highestIndex])) {
      highestIndex = index;
    }
  }
  return highestIndex;
}

({String name, double share})? _peakCategory(
  List<Transaction> transactions,
  List<Category> categories,
  int year,
  int month,
) {
  if (month < 1) return null;
  final totals = <String, double>{};
  var monthTotal = 0.0;
  for (final transaction in transactions) {
    final date = transaction.date.toLocal();
    if (date.year != year ||
        date.month != month ||
        transaction.type != TransactionType.expense) {
      continue;
    }
    totals.update(
      transaction.categoryId,
      (total) => total + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
    monthTotal += transaction.amount;
  }
  if (totals.isEmpty || monthTotal <= 0) return null;
  final highest = totals.entries.reduce(
    (first, second) => first.value >= second.value ? first : second,
  );
  final category = categories.where((item) => item.id == highest.key);
  return (
    name: category.isEmpty ? 'Other / uncategorized' : category.first.name,
    share: highest.value / monthTotal * 100,
  );
}

class _OverviewBadge extends StatelessWidget {
  const _OverviewBadge({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: scheme.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YEAR-TO-DATE OVERVIEW',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
                Text(
                  '$year expense summary',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          _StatusPill(
            label: 'Live',
            color: scheme.tertiary,
            icon: Icons.circle,
          ),
        ],
      ),
    );
  }
}

class _YearHeroCard extends StatelessWidget {
  const _YearHeroCard({
    required this.total,
    required this.monthlyAverage,
    required this.peakMonth,
    required this.peakTotal,
  });

  final double total;
  final double monthlyAverage;
  final DateTime? peakMonth;
  final double peakTotal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5148D7), Color(0xFF4338CA), Color(0xFF321570)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .24),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -52,
            child: _GlowCircle(
              size: 145,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Pocket Ledger',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const _StatusPill(
                    label: 'YTD Live',
                    color: Color(0xFF9EF5CF),
                    icon: Icons.circle,
                    translucent: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'TOTAL EXPENSE THIS YEAR',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Color(0xFFD8D5FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppUtils.formatCurrency(total),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.7,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 5, bottom: 5),
                    child: Text(
                      'BDT',
                      style: TextStyle(
                        color: Color(0xFFD8D5FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: Colors.white.withValues(alpha: .16)),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _HeroMetric(
                      label: 'Monthly average',
                      value: AppUtils.formatCurrency(monthlyAverage),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroMetric(
                      label: 'Highest month',
                      value: peakMonth == null
                          ? 'No activity'
                          : '${DateFormat('MMMM').format(peakMonth!)} · ${_compactCurrency(peakTotal)}',
                      valueColor: const Color(0xFFFFD875),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: const Color(0xFFD8D5FF), fontSize: 9),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: valueColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.month,
    required this.previousMonth,
    required this.currentExpense,
    required this.previousExpense,
    required this.difference,
    required this.percentageChange,
  });

  final DateTime month;
  final DateTime previousMonth;
  final double currentExpense;
  final double previousExpense;
  final double difference;
  final double? percentageChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final increased = difference > 0;
    final statusColor = increased ? scheme.error : scheme.tertiary;
    final maxExpense = currentExpense > previousExpense
        ? currentExpense
        : previousExpense;
    final changeAmount = percentageChange?.abs().toStringAsFixed(1);
    final changeLabel = changeAmount == null
        ? previousExpense == 0 && currentExpense > 0
              ? 'No spending recorded last month'
              : 'No percentage change available'
        : '$changeAmount% ${increased ? 'increase' : 'decrease'}';
    return _SummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            title: 'Month-over-month comparison',
            subtitle:
                '${DateFormat('MMM').format(previousMonth)} vs ${DateFormat('MMM yyyy').format(month)}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ComparisonMetric(
                  month: previousMonth,
                  amount: previousExpense,
                  fraction: maxExpense == 0 ? 0 : previousExpense / maxExpense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ComparisonMetric(
                  month: month,
                  amount: currentExpense,
                  fraction: maxExpense == 0 ? 0 : currentExpense / maxExpense,
                  current: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: .14)),
            ),
            child: Row(
              children: [
                Icon(
                  increased
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: statusColor,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    difference == 0
                        ? 'Spending is unchanged from last month'
                        : increased
                        ? 'You spent more than last month'
                        : 'You spent less than last month',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  AppUtils.formatCurrency(difference.abs()),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              changeLabel,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.month,
    required this.amount,
    required this.fraction,
    this.current = false,
  });

  final DateTime month;
  final double amount;
  final double fraction;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barColor = current ? scheme.tertiary : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: current
            ? scheme.primary.withValues(alpha: .045)
            : scheme.surfaceContainerHighest.withValues(alpha: .33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: current
              ? scheme.primary.withValues(alpha: .12)
              : scheme.outlineVariant.withValues(alpha: .22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('MMM yyyy').format(month)}${current ? ' · Current' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: current ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              AppUtils.formatCurrency(amount),
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: barColor.withValues(alpha: .13),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.month,
    required this.expense,
    required this.target,
    required this.usage,
    required this.targetLoadFailed,
    required this.saving,
    required this.onEdit,
    required this.onRetry,
    required this.onBudgets,
  });

  final DateTime month;
  final double expense;
  final double? target;
  final double usage;
  final bool targetLoadFailed;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onRetry;
  final VoidCallback onBudgets;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasTarget = !targetLoadFailed && target != null && target! > 0;
    final exceeded = hasTarget && usage > 1;
    final statusColor = !hasTarget
        ? scheme.primary
        : exceeded
        ? scheme.error
        : usage >= .85
        ? const Color(0xFFB76A00)
        : scheme.tertiary;
    final remaining = hasTarget ? target! - expense : 0.0;
    final remainingDays =
        DateUtils.getDaysInMonth(month.year, month.month) -
        DateTime.now().day +
        1;
    final dailyAllowance = hasTarget && remaining > 0 && remainingDays > 0
        ? remaining / remainingDays
        : 0.0;
    final percentLabel = hasTarget ? '${(usage * 100).round()}%' : '—';
    return _SummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _CardHeading(
                  title: '${DateFormat('MMMM').format(month)} target & pacing',
                  subtitle: 'Monthly budget consumption',
                ),
              ),
              _StatusPill(
                label: targetLoadFailed
                    ? 'Unavailable'
                    : !hasTarget
                    ? 'Not set'
                    : exceeded
                    ? 'Over target'
                    : usage >= .85
                    ? 'Near limit'
                    : 'On track',
                color: statusColor,
                icon: !hasTarget
                    ? Icons.add_circle_outline_rounded
                    : exceeded
                    ? Icons.warning_rounded
                    : Icons.circle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (targetLoadFailed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unable to load the monthly target.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: CircularProgressIndicator(
                          value: hasTarget ? usage.clamp(0.0, 1.0) : 0,
                          strokeWidth: 7,
                          strokeCap: StrokeCap.round,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: statusColor,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            percentLabel,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            hasTarget ? 'USED' : 'TARGET',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 8,
                                  color: scheme.onSurfaceVariant,
                                  letterSpacing: .6,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      _KeyValueRow(
                        label: 'Spent',
                        value: hasTarget
                            ? '${AppUtils.formatCurrency(expense)} / ${AppUtils.formatCurrency(target!)}'
                            : AppUtils.formatCurrency(expense),
                      ),
                      const SizedBox(height: 7),
                      _KeyValueRow(
                        label: exceeded ? 'Over by' : 'Remaining',
                        value: hasTarget
                            ? AppUtils.formatCurrency(remaining.abs())
                            : 'Set a target to track',
                        valueColor: statusColor,
                      ),
                      if (dailyAllowance > 0) ...[
                        const SizedBox(height: 7),
                        _KeyValueRow(
                          label: 'Daily allowance',
                          value:
                              '${AppUtils.formatCurrency(dailyAllowance)} / day',
                          valueColor: scheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: .32),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CompactAction(
                  label: targetLoadFailed
                      ? 'Retry target'
                      : hasTarget
                      ? 'Adjust target'
                      : 'Set monthly target',
                  icon: targetLoadFailed
                      ? Icons.refresh_rounded
                      : Icons.edit_outlined,
                  onPressed: saving
                      ? null
                      : targetLoadFailed
                      ? onRetry
                      : onEdit,
                  primary: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactAction(
                  label: 'Category budgets',
                  icon: Icons.tune_rounded,
                  onPressed: onBudgets,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.child,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final String badge;
  final Widget child;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SummaryCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _CardHeading(title: title, subtitle: subtitle),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  badge,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
          const SizedBox(height: 4),
          Divider(
            height: 12,
            color: scheme.outlineVariant.withValues(alpha: .32),
          ),
          Text(
            footer,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ExpenseBarChart extends StatelessWidget {
  const _ExpenseBarChart({
    required this.totals,
    required this.currentMonth,
    required this.peakMonth,
    required this.year,
  });

  final List<double> totals;
  final int currentMonth;
  final int peakMonth;
  final int year;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = totals.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = maxValue == 0 ? 100.0 : maxValue * 1.22;
    final interval = maxY / 3;
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${DateFormat('MMMM').format(DateTime(year, group.x + 1))}\n'
                '${AppUtils.formatCurrency(rod.toY)}',
                TextStyle(
                  color: scheme.onInverseSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: .32),
              dashArray: [3, 4],
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
                reservedSize: 37,
                interval: interval,
                getTitlesWidget: (value, _) => Text(
                  _compactAmount(value),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontSize: 9, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index > 11) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      DateFormat('MMM').format(DateTime(year, index + 1)),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 8,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var index = 0; index < totals.length; index++)
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: totals[index],
                    width: 11,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    color: index == currentMonth - 1
                        ? scheme.tertiary
                        : index == peakMonth
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: .2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
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
    final scheme = Theme.of(context).colorScheme;
    final increased = currentExpense > previousExpense;
    final exceeded = target != null && currentExpense > target!;
    final color = exceeded
        ? scheme.error
        : increased
        ? const Color(0xFFB76A00)
        : scheme.tertiary;
    final message = exceeded
        ? 'This month’s spending is ${AppUtils.formatCurrency(currentExpense - target!)} above the target.'
        : currentExpense == previousExpense
        ? 'This month’s spending matches last month.'
        : increased
        ? 'This month’s spending is higher than last month.'
        : 'This month’s spending is lower than last month.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              exceeded
                  ? Icons.warning_amber_rounded
                  : increased
                  ? Icons.insights_rounded
                  : Icons.trending_down_rounded,
              size: 20,
              color: scheme.onPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spending insight',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '$message Year-to-date expenses: ${AppUtils.formatCurrency(currentYearTotal)}.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.year,
    required this.spent,
    required this.forecast,
    required this.monthlyTotals,
    required this.currentMonth,
    required this.peakCategory,
  });

  final int year;
  final double spent;
  final double forecast;
  final List<double> monthlyTotals;
  final int currentMonth;
  final ({String name, double share})? peakCategory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quarters = List.generate(4, (index) {
      final firstMonth = index * 3 + 1;
      final monthsElapsed = (currentMonth - firstMonth + 1).clamp(0, 3);
      final actual = monthlyTotals
          .skip(firstMonth - 1)
          .take(monthsElapsed)
          .fold<double>(0, (sum, amount) => sum + amount);
      final estimate = monthsElapsed == 3
          ? actual
          : monthsElapsed > 0
          ? actual / monthsElapsed * 3
          : currentMonth == 0
          ? 0.0
          : spent / currentMonth * 3;
      return (number: index + 1, amount: estimate, elapsed: monthsElapsed);
    });
    final monthLabel = DateFormat('MMMM').format(DateTime(year, currentMonth));
    return _SummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _CardHeading(
                  title: '$year expense forecast',
                  subtitle: 'Estimate based on year-to-date average',
                ),
              ),
              _StatusPill(
                label: 'Estimate',
                color: scheme.primary,
                icon: Icons.auto_graph_rounded,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .33),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                _KeyValueRow(
                  label: 'Year-end projected expenses',
                  value: AppUtils.formatCurrency(forecast),
                  bold: true,
                ),
                const SizedBox(height: 5),
                _KeyValueRow(
                  label: 'Recorded through $monthLabel',
                  value: AppUtils.formatCurrency(spent),
                  valueColor: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quarterly projections',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Run rate',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final quarter in quarters) ...[
                if (quarter.number > 1) const SizedBox(width: 6),
                Expanded(
                  child: _QuarterTile(
                    quarter: quarter.number,
                    amount: quarter.amount,
                    elapsed: quarter.elapsed,
                    currentQuarter: (currentMonth - 1) ~/ 3 + 1,
                  ),
                ),
              ],
            ],
          ),
          if (peakCategory != null) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.tertiary.withValues(alpha: .2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.category_outlined,
                    color: scheme.tertiary,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Largest category in $monthLabel: ${peakCategory!.name} (${peakCategory!.share.toStringAsFixed(1)}% of monthly expenses).',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurface, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuarterTile extends StatelessWidget {
  const _QuarterTile({
    required this.quarter,
    required this.amount,
    required this.elapsed,
    required this.currentQuarter,
  });

  final int quarter;
  final double amount;
  final int elapsed;
  final int currentQuarter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = quarter == currentQuarter && elapsed < 3;
    final isFuture = elapsed == 0;
    final color = isFuture ? scheme.tertiary : scheme.primary;
    final status = isCurrent
        ? 'In progress'
        : isFuture
        ? 'Estimate'
        : elapsed == 3
        ? 'Actual'
        : 'Run rate';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Column(
        children: [
          Text(
            'Q$quarter',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              AppUtils.formatCurrency(amount),
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontSize: 8, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.exportingType, required this.onExport});

  final ExportFileType? exportingType;
  final ValueChanged<ExportFileType> onExport;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _ExportButton(
              label: exportingType == ExportFileType.pdf
                  ? 'Preparing PDF…'
                  : 'Share PDF',
              icon: Icons.picture_as_pdf_rounded,
              primary: true,
              isBusy: exportingType == ExportFileType.pdf,
              onPressed: exportingType == null
                  ? () => onExport(ExportFileType.pdf)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ExportButton(
              label: exportingType == ExportFileType.csv
                  ? 'Preparing CSV…'
                  : 'Share CSV',
              icon: Icons.table_chart_rounded,
              isBusy: exportingType == ExportFileType.csv,
              onPressed: exportingType == null
                  ? () => onExport(ExportFileType.csv)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isBusy,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isBusy;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: primary
              ? scheme.primary
              : scheme.surfaceContainerHighest.withValues(alpha: .7),
          foregroundColor: primary ? scheme.onPrimary : scheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          textStyle: Theme.of(context).textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        icon: isBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 17),
        label: Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 38,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: primary
              ? scheme.primary.withValues(alpha: .09)
              : scheme.surfaceContainerHighest.withValues(alpha: .62),
          foregroundColor: primary ? scheme.primary : scheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          textStyle: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        icon: Icon(icon, size: 15),
        label: Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: valueColor ?? scheme.onSurface,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
    this.translucent = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    final foreground = translucent ? color : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: translucent
            ? Colors.white.withValues(alpha: .12)
            : color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(99),
        border: translucent
            ? Border.all(color: Colors.white.withValues(alpha: .14))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: icon == Icons.circle ? 6 : 12, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: translucent ? Colors.white : color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.child,
    this.padding = const EdgeInsets.all(15),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? .96 : .94,
        ),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .23)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SummaryAmbient extends StatelessWidget {
  const _SummaryAmbient();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        ),
        Positioned(
          top: -105,
          right: -120,
          child: _GlowCircle(
            size: 310,
            color: scheme.primary.withValues(alpha: .08),
          ),
        ),
        Positioned(
          top: 430,
          left: -145,
          child: _GlowCircle(
            size: 290,
            color: scheme.secondary.withValues(alpha: .07),
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 42, color: scheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyExpenseNote extends StatelessWidget {
  const _EmptyExpenseNote();

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Add an expense to start building your yearly summary.',
            ),
          ),
        ],
      ),
    );
  }
}

String _compactCurrency(double amount) {
  if (amount >= 1000000) return '৳${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000) return '৳${(amount / 1000).toStringAsFixed(1)}k';
  return AppUtils.formatCurrency(amount);
}

String _compactAmount(double amount) {
  if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}k';
  return amount.toStringAsFixed(0);
}
