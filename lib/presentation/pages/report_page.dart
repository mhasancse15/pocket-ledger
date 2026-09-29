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
  static const xl = 20.0;
  static const xxl = 28.0;
}

class _Radius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
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
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? const <Budget>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Trend analysis',
            onPressed: () => context.pushNamed(AppRoutes.trendAnalysisName),
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            tooltip: 'Previous expense summary',
            onPressed: () => context.pushNamed(AppRoutes.previousExpanseName),
            icon: const Icon(Icons.bar_chart_outlined),
          ),
          const SizedBox(width: _Spacing.xs),
        ],
      ),
      body: transactionsAsync.when(
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
            onMonthChanged: (month) => setState(() => selectedMonth = month),
            onRefresh: () async {
              ref.invalidate(allTransactionsProvider);
              ref.invalidate(allCategoriesProvider);
              ref.invalidate(budgetsProvider);
            },
          ),
        ),
      ),
    );
  }
}

/// Pure-data view built once the two async sources have resolved. Splitting
/// this out of the State class keeps rebuild scope small and the file easy
/// to scan top-to-bottom.
class _ReportBody extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final categoryNames = <String, String>{
      for (final category in categories) category.id: category.name,
    };

    final expenses = transactions.where((t) {
      final date = t.date.toLocal();
      return t.type == TransactionType.expense &&
          date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList();

    final totals = <String, double>{};
    for (final expense in expenses) {
      final name = categoryNames[expense.categoryId]?.trim().isNotEmpty == true
          ? categoryNames[expense.categoryId]!
          : 'Other';
      totals.update(
        name,
        (v) => v + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalExpense = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    final monthBudgets = budgets.where((b) {
      return b.year == selectedMonth.year && b.month == selectedMonth.month;
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
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          _Spacing.lg,
          _Spacing.md,
          _Spacing.lg,
          _Spacing.xxl,
        ),
        children: [
          _MonthSelector(month: selectedMonth, onChanged: onMonthChanged),
          const SizedBox(height: _Spacing.lg),
          _SummaryHeader(
            totalExpense: totalExpense,
            transactionCount: expenses.length,
            topCategory: entries.isEmpty ? null : entries.first.key,
          ),
          const SizedBox(height: _Spacing.lg),
          _BudgetCard(
            totalBudget: totalBudget,
            totalExpense: totalExpense,
            budgetCount: monthBudgets.length,
          ),
          const SizedBox(height: _Spacing.xl),
          _MonthlySavingsReport(
            month: selectedMonth,
            transactions: transactions,
          ),
          const SizedBox(height: _Spacing.xl),
          if (entries.isEmpty)
            const EmptyView(
              icon: Icons.pie_chart_outline,
              title: 'No report data',
              message: 'Add expenses for this month to see your report.',
            )
          else ...[
            _SectionHeader(title: 'Spending breakdown'),
            const SizedBox(height: _Spacing.sm),
            _BreakdownChart(entries: entries, totalExpense: totalExpense),
            const SizedBox(height: _Spacing.xl),
            _SectionHeader(title: 'Category details'),
            const SizedBox(height: _Spacing.sm),
            _CategoryList(entries: entries, totalExpense: totalExpense),
          ],
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
      loading: () => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(_Spacing.lg),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (error, _) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(_Spacing.lg),
          child: Text('Unable to load monthly savings: $error'),
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

        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(_Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly savings',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
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
                    Expanded(
                      child: _MonthlySavingsValue(
                        label: 'Carried from last month',
                        value: AppUtils.formatCurrency(carried),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
    return Column(
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
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// -----------------------------------------------------------------------
/// Month selector — a flat white card matching the rest of the page.
/// -----------------------------------------------------------------------
class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _Spacing.xs),
      height: 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(month),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// Summary header — solid surface instead of a gradient. Gradients read as
/// decorative; a flat brand-tinted surface with clear type hierarchy reads
/// as financial-product-grade.
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
  }) {
    if (!hasBudget) {
      return const _BudgetStatus(
        'Not set',
        Colors.blueGrey,
        Icons.remove_circle_outline,
      );
    }
    if (isExceeded) {
      return const _BudgetStatus('Exceeded', Colors.red, Icons.error_outline);
    }
    if (usage >= 0.9) {
      return const _BudgetStatus(
        'Critical',
        Colors.orange,
        Icons.warning_amber_rounded,
      );
    }
    if (usage >= 0.75) {
      return _BudgetStatus(
        'Warning',
        Colors.amber.shade800,
        Icons.info_outline,
      );
    }
    return const _BudgetStatus(
      'On track',
      Colors.green,
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
    );

    return Container(
      padding: const EdgeInsets.all(_Spacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_Radius.lg),
      ),
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
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: _Spacing.lg),
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
                    color: remaining >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: _Spacing.lg),
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
                    color: remaining >= 0 ? Colors.green : Colors.red,
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
  const _StatusChip({required this.status});

  final _BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _Spacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 12,
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
/// Breakdown chart — donut + legend inside one bordered surface, matching
/// the budget card so the page reads as one system rather than a stack of
/// differently-styled `Card`s.
/// -----------------------------------------------------------------------
class _BreakdownChart extends StatelessWidget {
  const _BreakdownChart({required this.entries, required this.totalExpense});

  final List<MapEntry<String, double>> entries;
  final double totalExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(_Spacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_Radius.lg),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 52,
                sectionsSpace: 2,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value,
                      color: _kCategoryColors[i % _kCategoryColors.length],
                      radius: 58,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: _Spacing.lg),
          Wrap(
            spacing: _Spacing.lg,
            runSpacing: _Spacing.sm,
            children: [
              for (var i = 0; i < entries.length; i++)
                _LegendItem(
                  color: _kCategoryColors[i % _kCategoryColors.length],
                  label: entries[i].key,
                  percentage: totalExpense == 0
                      ? 0
                      : (entries[i].value / totalExpense * 100).round(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.percentage,
  });

  final Color color;
  final String label;
  final int percentage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 4),
        Text(
          '$percentage%',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------------
/// Category list — the color dot now IS the category identifier (matching
/// the chart), replacing a repeated generic icon that carried no meaning.
/// -----------------------------------------------------------------------
class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.entries, required this.totalExpense});

  final List<MapEntry<String, double>> entries;
  final double totalExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_Radius.lg),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: _Spacing.lg,
                endIndent: _Spacing.lg,
                color: theme.colorScheme.outlineVariant,
              ),
            _CategoryRow(
              color: _kCategoryColors[i % _kCategoryColors.length],
              name: entries[i].key,
              amount: entries[i].value,
              percentage: totalExpense == 0
                  ? 0.0
                  : entries[i].value / totalExpense,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.color,
    required this.name,
    required this.amount,
    required this.percentage,
  });

  final Color color;
  final String name;
  final double amount;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(_Spacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: _Spacing.md),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                AppUtils.formatCurrency(amount),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: _Spacing.sm),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_Radius.sm),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 6,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: _Spacing.sm),
              SizedBox(
                width: 36,
                child: Text(
                  '${(percentage * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
