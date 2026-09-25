import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/transaction.dart';
import '../providers/recurring_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';

class MonthlyHistoryPage extends ConsumerWidget {
  const MonthlyHistoryPage({super.key});

  static const purple = Color(0xFF5D56AA);
  static const textColor = Color(0xFF23232B);
  static const mutedColor = Color(0xFF70707B);
  static const borderColor = Color(0xFFE4E4EA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Monthly history',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: purple,
          ),
        ),
        error: (error, _) {
          return ErrorView(
            message: 'Unable to load history\n$error',
          );
        },
        data: (items) {
          final months = <DateTime>{
            for (final item in items)
              DateTime(
                item.date.year,
                item.date.month,
              ),
          }.toList()
            ..sort((a, b) => b.compareTo(a));

          if (months.isEmpty) {
            return const EmptyView(
              icon: Icons.calendar_month_outlined,
              title: 'No monthly history yet',
              message:
              'Add transactions to start building your history.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              32,
            ),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];

              final monthItems = items.where((item) {
                final date = item.date.toLocal();

                return date.year == month.year &&
                    date.month == month.month;
              }).toList();

              final income = _total(
                monthItems,
                TransactionType.income,
              );

              final expense = _total(
                monthItems,
                TransactionType.expense,
              );

              final balance = income - expense;

              final spentRatio = income <= 0
                  ? 0.0
                  : (expense / income).clamp(0.0, 1.0);

              return _monthCard(
                context,
                month: month,
                transactionCount: monthItems.length,
                income: income,
                expense: expense,
                balance: balance,
                spentRatio: spentRatio,
              );
            },
          );
        },
      ),
    );
  }

  double _total(
      List<Transaction> items,
      TransactionType type,
      ) {
    return items
        .where((item) => item.type == type)
        .fold<double>(
      0,
          (sum, item) => sum + item.amount,
    );
  }

  Widget _monthCard(
      BuildContext context, {
        required DateTime month,
        required int transactionCount,
        required double income,
        required double expense,
        required double balance,
        required double spentRatio,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$transactionCount transactions',
                style: const TextStyle(
                  color: mutedColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _metric(
                  label: 'Income',
                  value: AppUtils.formatCurrency(income),
                  color: const Color(0xFF00A578),
                ),
              ),
              Expanded(
                child: _metric(
                  label: 'Expense',
                  value: AppUtils.formatCurrency(expense),
                  color: const Color(0xFFE85E6F),
                ),
              ),
              Expanded(
                child: _metric(
                  label: 'Balance',
                  value: AppUtils.formatCurrency(balance),
                  color: balance >= 0
                      ? const Color(0xFF3182CE)
                      : Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: spentRatio,
              minHeight: 7,
              color: spentRatio >= 1
                  ? Colors.redAccent
                  : const Color(0xFF00A578),
              backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            spentRatio == 0
                ? 'No expense data'
                : '${(spentRatio * 100).round()}% of income spent',
            style: const TextStyle(
              color: mutedColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: mutedColor,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class RecurringExpensesPage extends ConsumerWidget {
  const RecurringExpensesPage({super.key});

  static const purple = Color(0xFF5D56AA);
  static const textColor = Color(0xFF23232B);
  static const mutedColor = Color(0xFF70707B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(allRecurringRulesProvider);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Recurring expenses',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Recurring expense form coming soon',
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text(
          'Add recurring',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: rulesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: purple,
          ),
        ),
        error: (error, _) {
          return ErrorView(
            message: 'Unable to load recurring expenses\n$error',
          );
        },
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.repeat_outlined,
              title: 'No recurring expenses',
              message:
              'Add subscriptions and regular bills to automate tracking.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              100,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final rule = items[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: purple.withOpacity(.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.repeat_outlined,
                        color: purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            rule.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${rule.frequency.name} • next '
                                '${AppUtils.formatDate(rule.nextOccurrenceDate)}',
                            style: const TextStyle(
                              color: mutedColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppUtils.formatCurrency(rule.amount),
                      style: const TextStyle(
                        color: purple,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}