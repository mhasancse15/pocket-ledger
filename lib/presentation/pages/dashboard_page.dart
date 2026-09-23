import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/monthly_limit.dart';
import '../providers/transaction_provider.dart';
import '../providers/limit_provider.dart';
import '../viewmodels/dashboard_viewmodel.dart';

class _TargetEditorSheet extends StatefulWidget {
  final TextEditingController controller;
  final DateTime month;
  final MonthlyLimit? current;
  final Future<void> Function()? onRemove;

  const _TargetEditorSheet({
    required this.controller,
    required this.month,
    required this.current,
    required this.onRemove,
  });

  @override
  State<_TargetEditorSheet> createState() => _TargetEditorSheetState();
}

class _TargetEditorSheetState extends State<_TargetEditorSheet> {
  String? _error;
  bool _saving = false;

  void _save() {
    final value = double.tryParse(widget.controller.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a target greater than ৳0.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context, value);
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      if (widget.onRemove != null) {
        await widget.onRemove!();
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not remove target: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Monthly expense target',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(DateFormat('MMMM yyyy').format(widget.month)),
          const SizedBox(height: 18),
          TextField(
            controller: widget.controller,
            autofocus: true,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Target amount',
              prefixText: '৳ ',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save target'),
            ),
            if (widget.current != null)
              TextButton(
                onPressed: _saving ? null : _remove,
                child: const Text('Remove target'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Main dashboard page showing overview and quick actions
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late DateTime _selectedMonth;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  Future<void> _editMonthlyTarget() async {
    try {
      final current = await ref.read(
        monthlyLimitProvider((_selectedMonth.year, _selectedMonth.month)).future,
      );
      if (!mounted) return;
      final controller = TextEditingController(
        text: current?.amount.toStringAsFixed(0) ?? '',
      );
      final amount = await showDialog<double>(
        context: context,
        builder: (sheetContext) => _TargetEditorSheet(
          controller: controller,
          month: _selectedMonth,
          current: current,
          onRemove: current == null
              ? null
              : () => ref.read(limitRepositoryProvider).deleteMonthlyLimit(
                    _selectedMonth.year,
                    _selectedMonth.month,
                  ),
        ),
      );
      controller.dispose();
      if (amount == null || !mounted) return;
      final now = DateTime.now();
      await ref.read(limitRepositoryProvider).setMonthlyLimit(
            MonthlyLimit(
              id: current?.id ?? AppUtils.generateId(),
              year: _selectedMonth.year,
              month: _selectedMonth.month,
              amount: amount,
              createdAt: current?.createdAt ?? now,
              updatedAt: now,
            ),
          );
      ref.invalidate(monthlyLimitProvider((_selectedMonth.year, _selectedMonth.month)));
      ref.invalidate(allLimitsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly target saved')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save monthly target: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateFormat('MMMM yyyy').format(_selectedMonth);
    final dashboardVM = ref.read(dashboardViewModelProvider);
    final monthlyTransactions = ref.watch(
      monthlyTransactionsProvider((_selectedMonth.year, _selectedMonth.month)),
    );
    final monthlyLimit = ref.watch(
      monthlyLimitProvider((_selectedMonth.year, _selectedMonth.month)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Ledger'),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Set monthly target',
            icon: const Icon(Icons.track_changes),
            onPressed: _editMonthlyTarget,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Selector
              Card(
                elevation: 0,
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _previousMonth,
                          ),
                          Text(
                            currentMonth,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _nextMonth,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Budget Status Card
              FutureBuilder<(double, double)>(
                future: dashboardVM.getMonthlyTotals(
                  _selectedMonth.year,
                  _selectedMonth.month,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final (income, expense) = snapshot.data!;
                  final limit = monthlyLimit.value?.amount;
                  if (limit == null) {
                    return Card(
                      elevation: 0,
                      color: Colors.blue.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No monthly limit set for this month.'),
                      ),
                    );
                  }
                  final percentage =
                      dashboardVM.calculateBudgetPercentage(expense, limit);
                  final status = dashboardVM.getBudgetStatus(percentage);
                  final remaining = limit - expense;

                  return Card(
                    elevation: 0,
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Text(
                                'Budget Status',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(percentage)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _getStatusColor(percentage),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) => Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spent this month',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${AppUtils.formatCurrency(expense)} / ${AppUtils.formatCurrency(limit)}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          color: _getStatusColor(percentage),
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (percentage / 100).clamp(0, 1),
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation(
                                _getStatusColor(percentage),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            remaining > 0
                                ? '${AppUtils.formatCurrency(remaining)} remaining'
                                : 'Budget exceeded',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: remaining > 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Summary Cards Row
              FutureBuilder<(double, double)>(
                future: dashboardVM.getMonthlyTotals(
                  _selectedMonth.year,
                  _selectedMonth.month,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(height: 80);
                  }

                  final (income, expense) = snapshot.data!;
                  final balance = income - expense;

                  return Row(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Income',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppUtils.formatCurrency(income),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Colors.green,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Balance',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppUtils.formatCurrency(balance),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: balance >= 0
                                            ? Colors.blue
                                            : Colors.red,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Today's Transactions
              Text(
                "Today's Transactions",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              monthlyTransactions.when(
                data: (transactions) {
                  final today = DateTime.now();
                  final todayTransactions = transactions
                      .where((t) =>
                          t.date.year == today.year &&
                          t.date.month == today.month &&
                          t.date.day == today.day)
                      .toList();

                  if (todayTransactions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No transactions today',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: todayTransactions
                        .take(3)
                        .map((transaction) {
                          final isIncome = transaction.type.toString() ==
                              'TransactionType.income';
                          final icon = isIncome
                              ? Icons.arrow_downward
                              : Icons.arrow_upward;
                          final iconColor = isIncome ? Colors.green : Colors.red;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    icon,
                                    color: iconColor,
                                    size: 20,
                                  ),
                                ),
                              ),
                              title: Text(transaction.note ?? 'Transaction'),
                              subtitle: Text(transaction.categoryId),
                              trailing: Text(
                                '${isIncome ? '+' : '-'}${AppUtils.formatCurrency(transaction.amount)}',
                                style: TextStyle(
                                  color: iconColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text('Error loading transactions'),
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.addTransaction),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.addTransaction),
                      icon: const Icon(Icons.trending_up),
                      label: const Text('Add Income'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 0:
              context.go(AppRoutes.dashboard);
              break;
            case 1:
              context.push(AppRoutes.transactions);
              break;
            case 2:
              context.push(AppRoutes.reports);
              break;
            case 3:
              context.push(AppRoutes.settings);
              break;
          }
        },
      ),
    );
  }

  Color _getStatusColor(double percentage) {
    if (percentage < 75) return Colors.green;
    if (percentage < 90) return Colors.amber;
    if (percentage < 100) return Colors.orange;
    return Colors.red;
  }
}
