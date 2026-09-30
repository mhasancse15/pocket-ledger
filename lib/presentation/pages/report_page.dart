import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/constants/monthly_saving_constants.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/monthly_saving_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/financial_summary_card.dart';

/// -----------------------------------------------------------------------
/// Design tokens
/// Centralising spacing / radius keeps every card visually consistent and
/// makes future tuning a one-line change instead of a find-and-replace.
/// -----------------------------------------------------------------------
class _Spacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
}

class _Radius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
}

/// Muted, professional palette instead of raw Material swatches — reads
/// calmer at a glance and still gives each category clear separation.
const _kCategoryColors = <Color>[
  Color(0xFF2F6F5E), // teal
  Color(0xFFB4682A), // burnt orange
  Color(0xFF3D4E9C), // indigo
  Color(0xFFA84470), // muted pink
  Color(0xFFB08900), // amber
  Color(0xFF6B4C9A), // purple
  Color(0xFF2E6DA4), // blue
  Color(0xFF3F8752), // green
];

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Color get cardColor => Theme.of(context).colorScheme.surface;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? const <Budget>[];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: .72),
        title: const Text(
          'Reports',
          style: TextStyle(
            fontSize: 28,
            height: 1.1,
            letterSpacing: -.7,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
        actions: [
          _ReportAppBarButton(
            tooltip: 'Trend analysis',
            icon: Icons.query_stats_rounded,
            onPressed: () => context.pushNamed(AppRoutes.trendAnalysisName),
          ),
          _ReportAppBarButton(
            tooltip: 'Previous expense summary',
            icon: Icons.bar_chart_rounded,
            onPressed: () => context.pushNamed(AppRoutes.previousExpanseName),
          ),
          const SizedBox(width: _Spacing.xs),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [
                          Color(0xFF101114),
                          Color(0xFF171522),
                          Color(0xFF101114),
                        ]
                      : const [
                          Color(0xFFFAF8FF),
                          Color(0xFFF1EEFF),
                          Color(0xFFF7FBFF),
                        ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(child: _ReportAmbient(isDark: isDark)),
          ),
          transactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                ErrorView(message: 'Unable to load transactions\n$error'),
            data: (transactions) => categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  ErrorView(message: 'Unable to load categories\n$error'),
              data: (categories) => _ReportBody(
                transactions: transactions,
                categories: categories,
                budgets: budgets,
                selectedMonth: selectedMonth,
                onMonthChanged: (month) =>
                    setState(() => selectedMonth = month),
                onRefresh: () async {
                  ref.invalidate(allTransactionsProvider);
                  ref.invalidate(allCategoriesProvider);
                  ref.invalidate(budgetsProvider);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportAppBarButton extends StatelessWidget {
  const _ReportAppBarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size(42, 42),
          backgroundColor: theme.colorScheme.surface.withValues(alpha: .92),
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .35),
          ),
          elevation: 1,
          shadowColor: theme.colorScheme.primary.withValues(alpha: .08),
        ),
        icon: Icon(icon, size: 21),
      ),
    );
  }
}

class _ReportAmbient extends StatelessWidget {
  const _ReportAmbient({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -95,
          left: -95,
          child: _glow(
            color: isDark ? const Color(0xFF4338CA) : const Color(0xFF8B80FF),
            size: 270,
          ),
        ),
        Positioned(
          top: 280,
          right: -130,
          child: _glow(
            color: isDark ? const Color(0xFF712AE2) : const Color(0xFFC4B5FD),
            size: 300,
          ),
        ),
        Positioned(
          bottom: 60,
          left: -130,
          child: _glow(
            color: isDark ? const Color(0xFF005E40) : const Color(0xFF99F6E4),
            size: 300,
          ),
        ),
      ],
    );
  }

  Widget _glow({required Color color, required double size}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? .12 : .22),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Pure-data view built once the two async sources have resolved. Splitting
/// this out of the State class keeps rebuild scope small and the file easy
/// to scan top-to-bottom.
class _ReportBody extends StatefulWidget {
  const _ReportBody({
    required this.transactions,
    required this.categories,
    required this.budgets,
    required this.selectedMonth,
    required this.onMonthChanged,
    required this.onRefresh,
  });

  final List<Transaction> transactions;
  final List<Category> categories;
  final List<Budget> budgets;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final Future<void> Function() onRefresh;

  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  bool _showDailyBreakdown = false;

  @override
  Widget build(BuildContext context) {
    final categoryNames = <String, String>{
      for (final category in widget.categories) category.id: category.name,
    };

    final expenses = widget.transactions.where((t) {
      final date = t.date.toLocal();
      return t.type == TransactionType.expense &&
          date.year == widget.selectedMonth.year &&
          date.month == widget.selectedMonth.month;
    }).toList();

    final totals = <String, double>{};
    final categoryCounts = <String, int>{};
    for (final expense in expenses) {
      final name = categoryNames[expense.categoryId]?.trim().isNotEmpty == true
          ? categoryNames[expense.categoryId]!
          : 'Other';
      categoryCounts.update(name, (count) => count + 1, ifAbsent: () => 1);
      totals.update(
        name,
        (v) => v + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalExpense = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final dailyTotals = List<double>.filled(
      DateUtils.getDaysInMonth(
        widget.selectedMonth.year,
        widget.selectedMonth.month,
      ),
      0,
    );
    for (final expense in expenses) {
      dailyTotals[expense.date.toLocal().day - 1] += expense.amount;
    }

    final monthBudgets = widget.budgets.where((b) {
      return b.year == widget.selectedMonth.year &&
          b.month == widget.selectedMonth.month;
    }).toList();

    final monthlyBudgets = monthBudgets.where(
      (b) => b.scope == BudgetScope.monthly,
    );

    final categoryAndWalletBudgets = monthBudgets
        .where((b) => b.scope != BudgetScope.monthly)
        .fold<double>(0, (sum, b) => sum + b.amount);

    final totalBudget = monthlyBudgets.isNotEmpty
        ? monthlyBudgets.first.amount
        : categoryAndWalletBudgets;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          _Spacing.lg,
          _Spacing.sm,
          _Spacing.lg,
          112,
        ),
        children: [
          _MonthSelector(
            month: widget.selectedMonth,
            onChanged: widget.onMonthChanged,
          ),
          const SizedBox(height: _Spacing.md),
          _SummaryHeader(
            totalExpense: totalExpense,
            transactionCount: expenses.length,
            topCategory: entries.isEmpty ? null : entries.first.key,
          ),
          const SizedBox(height: _Spacing.md),
          _BudgetCard(
            totalBudget: totalBudget,
            totalExpense: totalExpense,
            budgetCount: monthBudgets.length,
          ),
          const SizedBox(height: _Spacing.md),
          _MonthlySavingsReport(
            month: widget.selectedMonth,
            transactions: widget.transactions,
          ),
          const SizedBox(height: _Spacing.md),
          _BreakdownCard(
            entries: entries,
            totalExpense: totalExpense,
            dailyTotals: dailyTotals,
            showDaily: _showDailyBreakdown,
            onViewChanged: (showDaily) {
              setState(() => _showDailyBreakdown = showDaily);
            },
          ),
          const SizedBox(height: _Spacing.md),
          if (entries.isEmpty)
            const EmptyView(
              icon: Icons.pie_chart_outline,
              title: 'No report data',
              message: 'Add expenses for this month to see your report.',
            )
          else ...[
            _CategoryDetailsCard(
              entries: entries,
              totalExpense: totalExpense,
              categoryCounts: categoryCounts,
              month: widget.selectedMonth,
            ),
            const SizedBox(height: _Spacing.md),
          ],
          _SpendingVelocityCard(
            month: widget.selectedMonth,
            dailyTotals: dailyTotals,
            totalExpense: totalExpense,
          ),
        ],
      ),
    );
  }
}

class _MonthlySavingsReport extends ConsumerWidget {
  const _MonthlySavingsReport({
    required this.month,
    required this.transactions,
  });

  final DateTime month;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(
      monthlySavingEntriesProvider((month.year, month.month)),
    );
    return entries.when(
      loading: () => Container(
        padding: const EdgeInsets.all(_Spacing.lg),
        decoration: _reportCardDecoration(context),
        child: const LinearProgressIndicator(),
      ),
      error: (error, _) => Container(
        padding: const EdgeInsets.all(_Spacing.lg),
        decoration: _reportCardDecoration(context),
        child: Text(
          'Unable to load monthly savings: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (values) {
        final saved = values.fold<double>(
          0,
          (sum, entry) => sum + entry.amount,
        );
        final carried = transactions
            .where((transaction) {
              final date = transaction.date.toLocal();
              return transaction.type == TransactionType.income &&
                  transaction.categoryId == monthlySurplusIncomeCategoryId &&
                  date.year == month.year &&
                  date.month == month.month;
            })
            .fold<double>(0, (sum, transaction) => sum + transaction.amount);

        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(_Spacing.lg),
          decoration: _reportCardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.savings_rounded,
                    color: theme.colorScheme.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: _Spacing.sm),
                  Text(
                    'Monthly savings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _Spacing.md),
              Row(
                children: [
                  Expanded(
                    child: _MonthlySavingsValue(
                      label: 'Saved this month',
                      value: AppUtils.formatCurrency(saved),
                    ),
                  ),
                  const SizedBox(width: _Spacing.sm),
                  Expanded(
                    child: _MonthlySavingsValue(
                      label: 'Carried from last',
                      value: AppUtils.formatCurrency(carried),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthlySavingsValue extends StatelessWidget {
  const _MonthlySavingsValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(_Spacing.md),
      decoration: _reportInsetDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: _Spacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// Compact month navigator in the reference's centered pill treatment.
/// -----------------------------------------------------------------------
class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.outlineVariant.withValues(alpha: .35)
                : Colors.white,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: .055),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _MonthArrowButton(
              tooltip: 'Previous month',
              icon: Icons.chevron_left_rounded,
              onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
            ),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 17,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMMM yyyy').format(month),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _MonthArrowButton(
              tooltip: 'Next month',
              icon: Icons.chevron_right_rounded,
              onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Soft glass surface shared by report sections.
BoxDecoration _reportCardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark
        ? theme.colorScheme.surface.withValues(alpha: .96)
        : Colors.white.withValues(alpha: .94),
    borderRadius: BorderRadius.circular(_Radius.lg),
    border: Border.all(
      color: isDark
          ? theme.colorScheme.outlineVariant.withValues(alpha: .28)
          : Colors.white.withValues(alpha: .92),
    ),
    boxShadow: [
      BoxShadow(
        color: theme.colorScheme.primary.withValues(alpha: isDark ? .05 : .055),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? .08 : .018),
        blurRadius: 5,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

BoxDecoration _reportInsetDecoration(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: .32)
        : const Color(0xFFF8FAFC),
    borderRadius: BorderRadius.circular(_Radius.md),
    border: Border.all(
      color: isDark
          ? theme.colorScheme.outlineVariant.withValues(alpha: .2)
          : const Color(0xFFEDF1F7),
    ),
  );
}

/// -----------------------------------------------------------------------
/// Branded report summary with month-specific expense metrics.
/// -----------------------------------------------------------------------
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.totalExpense,
    required this.transactionCount,
    required this.topCategory,
  });

  final double totalExpense;
  final int transactionCount;
  final String? topCategory;

  @override
  Widget build(BuildContext context) {
    return FinancialSummaryCard(
      label: 'Total expense',
      amount: totalExpense,
      metrics: [
        FinancialSummaryMetric(
          label: 'Records',
          value: '$transactionCount',
          icon: Icons.receipt_long_outlined,
        ),
        FinancialSummaryMetric(
          label: 'Top category',
          value: topCategory ?? 'N/A',
          icon: Icons.category_outlined,
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------------
/// Budget card — same information, tighter visual noise: single accent
/// color driven by status, a slim status chip with icon, and a proper
/// legend under the progress bar instead of duplicated text blocks.
/// -----------------------------------------------------------------------
class _BudgetStatus {
  const _BudgetStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  static _BudgetStatus resolve({
    required bool hasBudget,
    required bool isExceeded,
    required double usage,
    required ColorScheme colorScheme,
  }) {
    if (!hasBudget) {
      return const _BudgetStatus(
        'Not set',
        Colors.blueGrey,
        Icons.remove_circle_outline,
      );
    }
    if (isExceeded) {
      return _BudgetStatus('Exceeded', colorScheme.error, Icons.error_outline);
    }
    if (usage >= 0.9) {
      return _BudgetStatus(
        'Critical',
        colorScheme.error,
        Icons.warning_amber_rounded,
      );
    }
    if (usage >= 0.75) {
      return _BudgetStatus(
        'Warning',
        colorScheme.secondary,
        Icons.info_outline,
      );
    }
    return _BudgetStatus(
      'On track',
      colorScheme.tertiary,
      Icons.check_circle_outline,
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.totalBudget,
    required this.totalExpense,
    required this.budgetCount,
  });

  final double totalBudget;
  final double totalExpense;
  final int budgetCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBudget = totalBudget > 0;
    final remaining = totalBudget - totalExpense;
    final usage = hasBudget ? totalExpense / totalBudget : 0.0;
    final progress = usage.clamp(0.0, 1.0);
    final isExceeded = hasBudget && remaining < 0;

    final status = _BudgetStatus.resolve(
      hasBudget: hasBudget,
      isExceeded: isExceeded,
      usage: usage,
      colorScheme: theme.colorScheme,
    );

    return Container(
      padding: const EdgeInsets.all(_Spacing.lg),
      decoration: _reportCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget report',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              _StatusChip(
                status: status,
                detail: isExceeded
                    ? 'by ${AppUtils.formatCurrency(remaining.abs())}'
                    : null,
              ),
            ],
          ),
          const SizedBox(height: _Spacing.md),
          if (!hasBudget)
            Text(
              'Set a budget to compare your spending against a target.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: _reportInsetDecoration(context),
              child: Row(
                children: [
                  Expanded(
                    child: _BudgetValue(
                      label: 'Budget',
                      value: AppUtils.formatCurrency(totalBudget),
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Expanded(
                    child: _BudgetValue(
                      label: 'Spent',
                      value: AppUtils.formatCurrency(totalExpense),
                      color: status.color,
                    ),
                  ),
                  Expanded(
                    child: _BudgetValue(
                      label: remaining >= 0 ? 'Remaining' : 'Over',
                      value: AppUtils.formatCurrency(remaining.abs()),
                      color: remaining >= 0
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _Spacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(_Radius.sm),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: status.color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: _Spacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(usage * 100).round()}% used',
                  style: TextStyle(
                    color: status.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  remaining >= 0
                      ? '${AppUtils.formatCurrency(remaining)} available'
                      : 'Budget exceeded',
                  style: TextStyle(
                    color: remaining >= 0
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.detail});

  final _BudgetStatus status;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _Spacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 4),
          Text(
            detail == null ? status.label : '${status.label} $detail',
            style: TextStyle(
              color: status.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetValue extends StatelessWidget {
  const _BudgetValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------------
/// Category and daily views share one report surface and month-filtered data.
/// -----------------------------------------------------------------------
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.entries,
    required this.totalExpense,
    required this.dailyTotals,
    required this.showDaily,
    required this.onViewChanged,
  });

  final List<MapEntry<String, double>> entries;
  final double totalExpense;
  final List<double> dailyTotals;
  final bool showDaily;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topEntry = entries.isEmpty ? null : entries.first;
    final topColor = entries.isEmpty
        ? theme.colorScheme.tertiary
        : _kCategoryColors.first;
    final percentage = topEntry == null || totalExpense == 0
        ? 0
        : (topEntry.value / totalExpense * 100).round();

    return Container(
      padding: const EdgeInsets.all(_Spacing.lg),
      decoration: _reportCardDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spending breakdown',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showDaily ? 'Daily spending' : 'Categorical allocation',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _BreakdownModeToggle(
                showDaily: showDaily,
                onChanged: onViewChanged,
              ),
            ],
          ),
          const SizedBox(height: _Spacing.md),
          if (showDaily)
            _DailyBreakdownChart(dailyTotals: dailyTotals)
          else if (entries.isEmpty)
            SizedBox(
              height: 190,
              child: Center(
                child: Text(
                  'No expenses recorded this month',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 61,
                      sectionsSpace: 2,
                      sections: [
                        for (var i = 0; i < entries.length; i++)
                          PieChartSectionData(
                            value: entries[i].value,
                            color:
                                _kCategoryColors[i % _kCategoryColors.length],
                            radius: 27,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TOTAL',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppUtils.formatCurrency(totalExpense),
                            maxLines: 1,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiary.withValues(
                              alpha: .08,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${entries.length} ${entries.length == 1 ? 'Category' : 'Categories'}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: _Spacing.sm),
          if (!showDaily && topEntry != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: _reportInsetDecoration(context),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: topColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: _Spacing.sm),
                  Expanded(
                    child: Text(
                      topEntry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: _Spacing.sm),
                  Text(
                    AppUtils.formatCurrency(topEntry.value),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BreakdownModeToggle extends StatelessWidget {
  const _BreakdownModeToggle({
    required this.showDaily,
    required this.onChanged,
  });

  final bool showDaily;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: .5)
            : const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BreakdownModeOption(
            label: 'Category',
            selected: !showDaily,
            onTap: () => onChanged(false),
          ),
          _BreakdownModeOption(
            label: 'Daily',
            selected: showDaily,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _BreakdownModeOption extends StatelessWidget {
  const _BreakdownModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyBreakdownChart extends StatelessWidget {
  const _DailyBreakdownChart({required this.dailyTotals});

  final List<double> dailyTotals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = dailyTotals.fold<double>(
      0,
      (maximum, value) => value > maximum ? value : maximum,
    );
    final peakDay = dailyTotals.indexOf(maxValue) + 1;

    return Column(
      children: [
        Container(
          height: 170,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          decoration: _reportInsetDecoration(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < dailyTotals.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: maxValue == 0
                            ? 4
                            : (dailyTotals[i] / maxValue * 126)
                                  .clamp(4, 126)
                                  .toDouble(),
                        decoration: BoxDecoration(
                          gradient: dailyTotals[i] == maxValue && maxValue > 0
                              ? const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF34D399),
                                    Color(0xFF059669),
                                  ],
                                )
                              : null,
                          color: dailyTotals[i] == maxValue && maxValue > 0
                              ? null
                              : theme.colorScheme.outlineVariant.withValues(
                                  alpha: .42,
                                ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: _Spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Day 1', style: theme.textTheme.labelSmall),
            Text(
              maxValue == 0
                  ? 'No spending yet'
                  : 'Day $peakDay peak · ${AppUtils.formatCurrency(maxValue)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Day ${dailyTotals.length}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------------
/// Ranked category rows provide transaction count, share, and spend.
/// -----------------------------------------------------------------------
class _CategoryDetailsCard extends StatelessWidget {
  const _CategoryDetailsCard({
    required this.entries,
    required this.totalExpense,
    required this.categoryCounts,
    required this.month,
  });

  final List<MapEntry<String, double>> entries;
  final double totalExpense;
  final Map<String, int> categoryCounts;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(_Spacing.lg),
      decoration: _reportCardDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Category details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${entries.length} Active',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _Spacing.md),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: _Spacing.sm),
            _CategoryDetailRow(
              color: _kCategoryColors[i % _kCategoryColors.length],
              entry: entries[i],
              count: categoryCounts[entries[i].key] ?? 0,
              month: month,
              percentage: totalExpense == 0
                  ? 0
                  : entries[i].value / totalExpense,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryDetailRow extends StatelessWidget {
  const _CategoryDetailRow({
    required this.color,
    required this.entry,
    required this.count,
    required this.month,
    required this.percentage,
  });

  final Color color;
  final MapEntry<String, double> entry;
  final int count;
  final DateTime month;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _reportInsetDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: color.withValues(alpha: .18)),
                ),
                child: Icon(Icons.category_outlined, size: 20, color: color),
              ),
              const SizedBox(width: _Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$count ${count == 1 ? 'transaction' : 'transactions'} · ${DateFormat('MMM yyyy').format(month)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _Spacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppUtils.formatCurrency(entry.value),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${(percentage * 100).round()}% share',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: _Spacing.md),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percentage.clamp(0.0, 1.0),
                    minHeight: 8,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: .75),
                  ),
                ),
              ),
              const SizedBox(width: _Spacing.sm),
              Text(
                '${(percentage * 100).round()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpendingVelocityCard extends StatelessWidget {
  const _SpendingVelocityCard({
    required this.month,
    required this.dailyTotals,
    required this.totalExpense,
  });

  final DateTime month;
  final List<double> dailyTotals;
  final double totalExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = dailyTotals.length;
    final dailyAverage = days == 0 ? 0.0 : totalExpense / days;
    final peakValue = dailyTotals.fold<double>(
      0,
      (maximum, value) => value > maximum ? value : maximum,
    );
    final peakDay = dailyTotals.indexOf(peakValue) + 1;
    final peakColor = theme.colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.all(_Spacing.lg),
      decoration: _reportCardDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: _Spacing.sm),
              Expanded(
                child: Text(
                  'Spending velocity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$days days',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: _Spacing.md),
          Container(
            padding: const EdgeInsets.all(_Spacing.md),
            decoration: _reportInsetDecoration(context),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily average',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppUtils.formatCurrency(dailyAverage),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        DateFormat('MMMM').format(month),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$days days period',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: _Spacing.md),
          Container(
            height: 62,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            decoration: _reportInsetDecoration(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < dailyTotals.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: peakValue == 0
                              ? 5
                              : (dailyTotals[i] / peakValue * 50)
                                    .clamp(5, 50)
                                    .toDouble(),
                          decoration: BoxDecoration(
                            color: dailyTotals[i] == peakValue && peakValue > 0
                                ? peakColor
                                : theme.colorScheme.outlineVariant.withValues(
                                    alpha: .42,
                                  ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: _Spacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM d')
                    .format(DateTime(month.year, month.month, 1)),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                peakValue == 0
                    ? 'No spending yet'
                    : '${AppUtils.formatCurrency(peakValue)} peak · ${DateFormat('MMM d').format(DateTime(month.year, month.month, peakDay))}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: peakColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                DateFormat(
                  'MMM d',
                ).format(DateTime(month.year, month.month, dailyTotals.length)),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
