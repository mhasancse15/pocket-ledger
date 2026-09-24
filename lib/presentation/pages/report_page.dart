
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
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
  DateTime selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              context.go(AppRoutes.previousExpanse);
            },
            padding: const EdgeInsets.only(right: 16),
            icon: const Icon(Icons.history_edu_outlined),
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => ErrorView(
          message: 'Unable to load transactions\n$error',
        ),
        data: (transactions) {
          return categoriesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => ErrorView(
              message: 'Unable to load categories\n$error',
            ),
            data: (categories) {
              return _reportBody(
                context,
                transactions,
                categories,
              );
            },
          );
        },
      ),
    );
  }

  Widget _reportBody(
      BuildContext context,
      List<Transaction> transactions,
      List<Category> categories,
      ) {
    // Convert category ID into readable category name.
    final categoryNames = <String, String>{
      for (final category in categories)
        category.id: category.name,
    };

    final expenses = transactions.where((item) {
      final date = item.date.toLocal();

      return item.type == TransactionType.expense &&
          date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList();

    final totals = <String, double>{};

    for (final item in expenses) {
      final categoryName =
      categoryNames[item.categoryId]?.trim().isNotEmpty == true
          ? categoryNames[item.categoryId]!
          : 'Other';

      totals.update(
        categoryName,
            (value) => value + item.amount,
        ifAbsent: () => item.amount,
      );
    }

    final entries = totals.entries.toList()
      ..sort(
            (a, b) => b.value.compareTo(a.value),
      );

    final totalExpense = expenses.fold<double>(
      0,
          (sum, item) => sum + item.amount,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allTransactionsProvider);
        ref.invalidate(allCategoriesProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _MonthSelector(
            month: selectedMonth,
            onPrevious: () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month - 1,
                );
              });
            },
            onNext: () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month + 1,
                );
              });
            },
          ),

          const SizedBox(height: 16),

          _ReportHeader(
            total: totalExpense,
            count: expenses.length,
            topCategory: entries.isEmpty ? null : entries.first.key,
          ),

          const SizedBox(height: 20),

          if (entries.isEmpty)
            const EmptyView(
              icon: Icons.pie_chart_outline,
              title: 'No report data',
              message: 'Add expenses for this month to see your report.',
            )
          else ...[
            Text(
              'Spending breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Card(
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
                            for (var index = 0;
                            index < entries.length;
                            index++)
                              PieChartSectionData(
                                value: entries[index].value,
                                color: colors[index % colors.length],
                                radius: 76,
                                title: _percentage(
                                  entries[index].value,
                                  totalExpense,
                                ),
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
                        for (var index = 0;
                        index < entries.length;
                        index++)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 5,
                                backgroundColor:
                                colors[index % colors.length],
                              ),
                              const SizedBox(width: 5),
                              Text(
                                entries[index].key,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Category details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...entries.asMap().entries.map(
                  (entry) => _CategoryBreakdown(
                name: entry.value.key,
                amount: entry.value.value,
                total: totalExpense,
                color: colors[entry.key % colors.length],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _percentage(double value, double total) {
    if (total == 0) return '0%';

    return '${(value / total * 100).round()}%';
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.name,
    required this.amount,
    required this.total,
    required this.color,
  });

  final String name;
  final double amount;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percentage = total <= 0 ? 0.0 : amount / total;

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
                  radius: 18,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(Icons.category_outlined, color: color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                Text('${(percentage * 100).round()}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(month),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({
    required this.total,
    required this.count,
    required this.topCategory,
  });

  final double total;
  final int count;
  final String? topCategory;

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
            'Total expense',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 5),
          Text(
            AppUtils.formatCurrency(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _WhiteMetric(
                  label: 'Transactions',
                  value: '$count',
                ),
              ),
              Expanded(
                child: _WhiteMetric(
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
}

class _WhiteMetric extends StatelessWidget {
  const _WhiteMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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