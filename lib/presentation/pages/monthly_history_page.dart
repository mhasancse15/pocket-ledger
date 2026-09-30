import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/transaction.dart';
import '../providers/transaction_provider.dart';
import '../widgets/error_view.dart';

class MonthlyHistoryPage extends ConsumerWidget {
  const MonthlyHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Monthly history',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        error: (error, _) {
          return ErrorView(message: 'Unable to load history\n$error');
        },
        data: (items) {
          final months = <DateTime>{
            for (final item in items) DateTime(item.date.year, item.date.month),
          }.toList()..sort((a, b) => b.compareTo(a));

          if (months.isEmpty) {
            return _emptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];

              final monthItems = items.where((item) {
                final date = item.date.toLocal();

                return date.year == month.year && date.month == month.month;
              }).toList();

              final income = _total(monthItems, TransactionType.income);

              final expense = _total(monthItems, TransactionType.expense);

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

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? .92 : .82,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: .45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? .16 : .045,
                ),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: scheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No monthly history yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add a transaction to start building your monthly history.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.pushNamed(
                    AppRoutes.addTransactionName,
                    extra: TransactionType.expense,
                  ),
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text('Add expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _total(List<Transaction> items, TransactionType type) {
    return items
        .where((item) => item.type == type)
        .fold<double>(0, (sum, item) => sum + item.amount);
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
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$transactionCount transactions',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  context,
                  label: 'Income',
                  value: AppUtils.formatCurrency(income),
                  color: const Color(0xFF00A578),
                ),
              ),
              Expanded(
                child: _metric(
                  context,
                  label: 'Expense',
                  value: AppUtils.formatCurrency(expense),
                  color: const Color(0xFFE85E6F),
                ),
              ),
              Expanded(
                child: _metric(
                  context,
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
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.tertiary,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            spentRatio == 0
                ? 'No expense data'
                : '${(spentRatio * 100).round()}% of income spent',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
