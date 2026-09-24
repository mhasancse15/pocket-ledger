import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';

class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});
  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  BudgetScope _scope = BudgetScope.monthly;
  String? _scopeKey;
  final _amount = TextEditingController();
  bool _rollover = false;
  Budget? _editingBudget;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double _spent(List<Transaction> items, Budget budget) {
    return items.where((item) {
      final date = item.date.toLocal();
      final month = date.year == budget.year && date.month == budget.month;
      final keyMatches = budget.scope == BudgetScope.monthly ||
          (budget.scope == BudgetScope.category &&
              item.categoryId == budget.scopeKey) ||
          (budget.scope == BudgetScope.wallet &&
              item.paymentMethod.name == budget.scopeKey);
      return month && item.type == TransactionType.expense && keyMatches;
    }).fold(0, (sum, item) => sum + item.amount);
  }

  double _effectiveAmount(
    Budget budget,
    List<Budget> allBudgets,
    List<Transaction> transactions,
  ) {
    if (!budget.rollover) return budget.amount;
    final previous = allBudgets.where((candidate) =>
        candidate.scope == budget.scope &&
        candidate.scopeKey == budget.scopeKey &&
        candidate.year == DateTime(budget.year, budget.month - 1).year &&
        candidate.month == DateTime(budget.year, budget.month - 1).month);
    if (previous.isEmpty) return budget.amount;
    final previousBudget = previous.first;
    final unused =
        previousBudget.amount - _spent(transactions, previousBudget);
    return budget.amount + (unused > 0 ? unused : 0);
  }

  String _budgetLabel(
    Budget budget,
    List<Category> categories,
  ) {
    final monthLabel = DateFormat(
      'MMMM yyyy',
    ).format(DateTime(budget.year, budget.month));

    switch (budget.scope) {
      case BudgetScope.monthly:
        return 'Monthly budget • $monthLabel';
      case BudgetScope.category:
        final category = categories.where(
          (item) => item.id == budget.scopeKey,
        );
        final name = category.isEmpty ? budget.scopeKey : category.first.name;
        return 'Category budget • $name • $monthLabel';
      case BudgetScope.wallet:
        return 'Wallet budget • ${_formatLabel(budget.scopeKey)} • $monthLabel';
    }
  }

  String _formatLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid budget amount')),
      );
      return;
    }
    if (_scope != BudgetScope.monthly && _scopeKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _scope == BudgetScope.category
                ? 'Select a category'
                : 'Select a wallet or payment method',
          ),
        ),
      );
      return;
    }
    final now = DateTime.now();
    final existing = _editingBudget;
    await ref.read(budgetStoreProvider).save(Budget(
          id: existing?.id ?? AppUtils.generateId(),
          year: _month.year,
          month: _month.month,
          scope: _scope,
          scopeKey: _scope == BudgetScope.monthly ? 'all' : _scopeKey!,
          amount: amount,
          rollover: _rollover,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ));
    _amount.clear();
    if (!mounted) return;
    setState(() => _editingBudget = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget saved')),
      );
    }

  }

  void _startEditing(Budget budget) {
    setState(() {
      _month = DateTime(budget.year, budget.month);
      _scope = budget.scope;
      _scopeKey = budget.scope == BudgetScope.monthly ? null : budget.scopeKey;
      _amount.text = budget.amount.toStringAsFixed(2);
      _rollover = budget.rollover;
      _editingBudget = budget;
    });
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text('${_budgetLabel(budget, const [])} will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(budgetStoreProvider).delete(budget);
    if (_editingBudget?.id == budget.id) {
      setState(() {
        _editingBudget = null;
        _amount.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(budgetsProvider);
    final transactions = ref.watch(allTransactionsProvider);
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];
    final items = transactions.valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget management'),
        actions: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => setState(() {
              _month = DateTime(_month.year, _month.month - 1);
              _clearEditingBudget();
            }),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: () => setState(() {
              _month = DateTime(_month.year, _month.month + 1);
              _clearEditingBudget();
            }),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            DateFormat('MMMM yyyy').format(_month),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<BudgetScope>(
            initialValue: _scope,
            decoration: const InputDecoration(labelText: 'Budget type'),
            items: const [
              DropdownMenuItem(
                value: BudgetScope.monthly,
                child: Text('Monthly budget'),
              ),
              DropdownMenuItem(
                value: BudgetScope.category,
                child: Text('Category budget'),
              ),
              DropdownMenuItem(
                value: BudgetScope.wallet,
                child: Text('Wallet/payment budget'),
              ),
            ],
            onChanged: (value) => setState(() {
              _scope = value ?? BudgetScope.monthly;
              _scopeKey = null;
            }),
          ),
          if (_scope != BudgetScope.monthly) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _scope == BudgetScope.category
                  ? categories.any((category) => category.id == _scopeKey)
                      ? _scopeKey
                      : null
                  : PaymentMethod.values.any(
                      (method) => method.name == _scopeKey,
                    )
                      ? _scopeKey
                      : null,
              decoration: InputDecoration(
                labelText: _scope == BudgetScope.category
                    ? 'Category'
                    : 'Wallet/payment method',
              ),
              items: _scope == BudgetScope.category
                  ? categories
                      .where((category) => category.type == CategoryType.expense)
                      .map((category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ))
                      .toList()
                  : PaymentMethod.values
                      .map((method) => DropdownMenuItem(
                            value: method.name,
                            child: Text(method.name),
                          ))
                      .toList(),
              onChanged: (value) => setState(() => _scopeKey = value),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Budget amount',
              prefixText: '৳ ',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rollover unused amount'),
            subtitle: const Text('Carry last month’s unused budget forward'),
            value: _rollover,
            onChanged: (value) => setState(() => _rollover = value),
          ),
          FilledButton.icon(
            onPressed: _save,
            icon: Icon(
              _editingBudget == null
                  ? Icons.save_outlined
                  : Icons.edit_outlined,
            ),
            label: Text(
              _editingBudget == null ? 'Save budget' : 'Update budget',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Budget history and status',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          budgets.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Unable to load budgets: $error'),
            data: (all) {
              final monthBudgets = all.where(
                (budget) =>
                    budget.year == _month.year &&
                    budget.month == _month.month,
              ).toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

              if (monthBudgets.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No budgets set for this month.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Column(
              children: monthBudgets.map((budget) {
                final spent = _spent(items, budget);
                final effectiveAmount = _effectiveAmount(budget, all, items);
                final percent = effectiveAmount <= 0
                    ? (spent > 0 ? double.infinity : 0.0)
                    : spent / effectiveAmount * 100;
                final isExceeded = spent >= effectiveAmount &&
                    effectiveAmount > 0;
                final status = isExceeded
                    ? 'Exceeded'
                    : percent >= 90
                        ? 'Critical'
                        : percent >= 75
                            ? 'Warning'
                            : 'On track';
                final color = isExceeded
                    ? Colors.red
                    : percent >= 90
                        ? Colors.deepOrange
                        : percent >= 75
                            ? Colors.amber.shade800
                            : Colors.green;
                return Card(
                  child: ListTile(
                    title: Text(_budgetLabel(budget, categories)),
                    subtitle: Text(
                      '${AppUtils.formatCurrency(spent)} of '
                      '${AppUtils.formatCurrency(effectiveAmount)}'
                      '${budget.rollover ? ' • rollover' : ''}',
                    ),
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(.12),
                      child: Icon(Icons.track_changes_outlined, color: color),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 28,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit') {
                                _startEditing(budget);
                              } else if (value == 'delete') {
                                _deleteBudget(budget);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
            },
          ),
          const SizedBox(height: 16),
          _MonthComparison(
            transactions: items,
            month: _month,
          ),
        ],
      ),
    );
  }

  void _clearEditingBudget() {
    _editingBudget = null;
    _amount.clear();
    _scope = BudgetScope.monthly;
    _scopeKey = null;
    _rollover = false;
  }
}

class _MonthComparison extends StatelessWidget {
  const _MonthComparison({required this.transactions, required this.month});
  final List<Transaction> transactions;
  final DateTime month;

  double _total(DateTime value) => transactions.where((item) {
        final date = item.date.toLocal();
        return item.type == TransactionType.expense &&
            date.year == value.year &&
            date.month == value.month;
      }).fold(0, (sum, item) => sum + item.amount);

  @override
  Widget build(BuildContext context) {
    final current = _total(month);
    final previous = _total(DateTime(month.year, month.month - 1));
    final difference = current - previous;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.compare_arrows_outlined),
        title: const Text('Current vs previous month'),
        subtitle: Text(
          '${AppUtils.formatCurrency(current)} vs '
          '${AppUtils.formatCurrency(previous)}',
        ),
        trailing: Text(
          '${difference >= 0 ? '+' : '-'}'
          '${AppUtils.formatCurrency(difference.abs())}',
          style: TextStyle(
            color: difference <= 0 ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
