import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/monthly_limit.dart';
import '../../domain/entities/transaction.dart';
import '../providers/limit_provider.dart';
import '../providers/transaction_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  (int, int) get _monthKey => (
  _selectedMonth.year,
  _selectedMonth.month,
  );

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
  }

  Future<void> _editMonthlyTarget() async {
    final currentLimit = await ref.read(
      monthlyLimitProvider(_monthKey).future,
    );

    if (!mounted) return;

    final result = await showDialog<_TargetDialogResult>(
      context: context,
      builder: (_) => _TargetEditorDialog(
        month: _selectedMonth,
        current: currentLimit,
      ),
    );

    if (result == null || !mounted) return;

    try {
      if (result.remove) {
        await ref.read(limitRepositoryProvider).deleteMonthlyLimit(
          _selectedMonth.year,
          _selectedMonth.month,
        );
      } else if (result.amount != null) {
        final now = DateTime.now();

        await ref.read(limitRepositoryProvider).setMonthlyLimit(
          MonthlyLimit(
            id: currentLimit?.id ?? AppUtils.generateId(),
            year: _selectedMonth.year,
            month: _selectedMonth.month,
            amount: result.amount!,
            createdAt: currentLimit?.createdAt ?? now,
            updatedAt: now,
          ),
        );
      }

      ref.invalidate(monthlyLimitProvider(_monthKey));
      ref.invalidate(allLimitsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.remove
                ? 'Monthly target removed'
                : 'Monthly target saved',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update target: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final transactionsAsync = ref.watch(
      monthlyTransactionsProvider(_monthKey),
    );

    final limitAsync = ref.watch(
      monthlyLimitProvider(_monthKey),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pocket Ledger',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Your financial overview',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Set monthly target',
            onPressed: _editMonthlyTarget,
            icon: const Icon(Icons.track_changes_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => _ErrorState(
          message: error.toString(),
        ),
        data: (transactions) {
          final expenseTotal = _calculateTotal(
            transactions,
            TransactionType.expense,
          );

          final incomeTotal = _calculateTotal(
            transactions,
            TransactionType.income,
          );

          final balance = incomeTotal - expenseTotal;
          final monthlyLimit = limitAsync.valueOrNull;
          final todayTransactions = _todayTransactions(transactions);

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _MonthSelector(
                        month: _selectedMonth,
                        onPrevious: () => _changeMonth(-1),
                        onNext: () => _changeMonth(1),
                      ),
                      const SizedBox(height: 16),
                      _BudgetCard(
                        expenseTotal: expenseTotal,
                        monthlyLimit: monthlyLimit?.amount,
                        onEdit: _editMonthlyTarget,
                      ),
                      const SizedBox(height: 16),
                      _SummaryGrid(
                        income: incomeTotal,
                        expense: expenseTotal,
                        balance: balance,
                      ),
                      const SizedBox(height: 28),
                      _SectionTitle(
                        title: 'Today’s transactions',
                        actionLabel: 'View all',
                        onAction: () {
                          context.go(AppRoutes.transactions);
                        },
                      ),
                      const SizedBox(height: 10),
                      if (todayTransactions.isEmpty)
                        const _EmptyTransactions()
                      else
                        ...todayTransactions
                            .take(4)
                            .map(
                              (transaction) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TransactionCard(
                              transaction: transaction,
                            ),
                          ),
                        ),
                      const SizedBox(height: 22),
                      const _SectionTitle(
                        title: 'Quick actions',
                      ),
                      const SizedBox(height: 10),
                      _QuickActions(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

    );
  }

  double _calculateTotal(
      List<Transaction> transactions,
      TransactionType type,
      ) {
    return transactions
        .where((transaction) => transaction.type == type)
        .fold<double>(
      0,
          (sum, transaction) => sum + transaction.amount,
    );
  }

  List<Transaction> _todayTransactions(
      List<Transaction> transactions,
      ) {
    final now = DateTime.now();

    return transactions.where((transaction) {
      final date = transaction.date.toLocal();

      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

class _TargetDialogResult {
  const _TargetDialogResult.save(this.amount) : remove = false;

  const _TargetDialogResult.remove()
      : amount = null,
        remove = true;

  final double? amount;
  final bool remove;
}

class _TargetEditorDialog extends StatefulWidget {
  const _TargetEditorDialog({
    required this.month,
    required this.current,
  });

  final DateTime month;
  final MonthlyLimit? current;

  @override
  State<_TargetEditorDialog> createState() => _TargetEditorDialogState();
}

class _TargetEditorDialogState extends State<_TargetEditorDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.current?.amount.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_controller.text.trim());

    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Enter an amount greater than ৳0.';
      });
      return;
    }

    Navigator.pop(
      context,
      _TargetDialogResult.save(amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Monthly expense target'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(widget.month),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: 'Target amount',
              prefixText: '৳ ',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                const _TargetDialogResult.remove(),
              );
            },
            child: const Text('Remove'),
          ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save target'),
        ),
      ],
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.expenseTotal,
    required this.monthlyLimit,
    required this.onEdit,
  });

  final double expenseTotal;
  final double? monthlyLimit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (monthlyLimit == null) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.track_changes_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No monthly target',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('Set a target to track your spending progress.'),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      );
    }

    final limit = monthlyLimit!;
    final percentage = limit <= 0 ? 0.0 : expenseTotal / limit * 100.0;
    final progress = (percentage / 100).clamp(0.0, 1.0);
    final remaining = limit - expenseTotal;
    final status = _budgetStatus(percentage);
    final statusColor = _budgetColor(percentage);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Budget status',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusBadge(
                  label: status,
                  color: statusColor,
                ),
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit target',
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spent this month',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${AppUtils.formatCurrency(expenseTotal)} / '
                            '${AppUtils.formatCurrency(limit)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: theme.colorScheme.outlineVariant,
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              remaining >= 0
                  ? '${AppUtils.formatCurrency(remaining)} remaining'
                  : '${AppUtils.formatCurrency(remaining.abs())} over budget',
              style: theme.textTheme.bodySmall?.copyWith(
                color: remaining >= 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _budgetStatus(double percentage) {
    if (percentage < 75) return 'On track';
    if (percentage < 90) return 'Warning';
    if (percentage < 100) return 'Critical';
    return 'Exceeded';
  }

  Color _budgetColor(double percentage) {
    if (percentage < 75) return Colors.green;
    if (percentage < 90) return Colors.amber.shade800;
    if (percentage < 100) return Colors.orange;
    return Colors.red;
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.income,
    required this.expense,
    required this.balance,
  });

  final double income;
  final double expense;
  final double balance;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final isSmallScreen = width < 420;
        final gap = 12.0;

        final twoColumnWidth = (width - gap) / 2;

        final cards = [
          SizedBox(
            width: isSmallScreen ? twoColumnWidth : twoColumnWidth,
            child: _SummaryCard(
              label: 'Income',
              amount: income,
              icon: Icons.arrow_downward,
              color: Colors.green,
            ),
          ),
          SizedBox(
            width: isSmallScreen ? twoColumnWidth : twoColumnWidth,
            child: _SummaryCard(
              label: 'Expense',
              amount: expense,
              icon: Icons.arrow_upward,
              color: Colors.redAccent,
            ),
          ),
          SizedBox(
            width: isSmallScreen ? width : twoColumnWidth,
            child: _SummaryCard(
              label: 'Balance',
              amount: balance,
              icon: Icons.account_balance_wallet_outlined,
              color: balance >= 0 ? Colors.blue : Colors.red,
            ),
          ),
        ];

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards,
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppUtils.formatCurrency(amount),
                      maxLines: 1,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
  });

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? Colors.green : Colors.redAccent;

    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(
            isIncome ? Icons.south_west : Icons.north_east,
            color: color,
          ),
        ),
        title: Text(
          transaction.note?.trim().isNotEmpty == true
              ? transaction.note!
              : transaction.categoryId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Date: ${DateFormat('d MMM yyyy').format(transaction.date.toLocal())}',
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}'
              '${AppUtils.formatCurrency(transaction.amount)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.addTransaction),
            icon: const Icon(Icons.add),
            label: const Text('Add expense'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.addTransaction),
            icon: const Icon(Icons.trending_up),
            label: const Text('Add income'),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 10),
            const Text(
              'No transactions today',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Add your first transaction to start tracking.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52),
            const SizedBox(height: 12),
            const Text(
              'Unable to load dashboard',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
  Color _getStatusColor(double percentage) {
    if (percentage < 75) return Colors.green;
    if (percentage < 90) return Colors.amber;
    if (percentage < 100) return Colors.orange;
    return Colors.red;

}
