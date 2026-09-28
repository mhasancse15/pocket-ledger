import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/budget_calculations.dart';
import '../providers/budget_notification_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];
    final transactions = transactionsAsync.valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Budget management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _openBudgetEditor,
        icon: const Icon(Icons.add),
        label: const Text('Add budget'),
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _ErrorState(message: 'Unable to load budgets\n$error'),
        data: (allBudgets) {
          final monthBudgets =
              allBudgets
                  .where(
                    (budget) =>
                        budget.year == _month.year &&
                        budget.month == _month.month,
                  )
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(budgetsProvider);
              ref.invalidate(allTransactionsProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                _MonthHeader(month: _month),
                const SizedBox(height: 16),
                _BudgetSummaryCard(
                  budgets: monthBudgets,
                  allBudgets: allBudgets,
                  transactions: transactions,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Budgets for this month',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${monthBudgets.length} set',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (monthBudgets.isEmpty)
                  _EmptyBudgetState(onAdd: _openBudgetEditor)
                else
                  ...monthBudgets.map(
                    (budget) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BudgetCard(
                        budget: budget,
                        categories: categories,
                        allBudgets: allBudgets,
                        transactions: transactions,
                        onEdit: () => _openBudgetEditor(budget),
                        onDelete: () => _deleteBudget(budget, categories),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _MonthComparison(transactions: transactions, month: _month),
              ],
            ),
          );
        },
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
    });
  }

  Future<void> _openBudgetEditor([Budget? existing]) async {
    final categories = ref.read(allCategoriesProvider).valueOrNull ?? const [];

    final result = await showModalBottomSheet<_BudgetDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _BudgetEditorSheet(
          month: _month,
          existing: existing,
          categories: categories,
        );
      },
    );

    if (result == null || !mounted) return;

    final now = DateTime.now();
    final budget = Budget(
      id: existing?.id ?? AppUtils.generateId(),
      year: _month.year,
      month: _month.month,
      scope: result.scope,
      scopeKey: result.scope == BudgetScope.monthly ? 'all' : result.scopeKey!,
      amount: result.amount,
      rollover: result.rollover,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await ref.read(budgetStoreProvider).save(budget);
      ref.invalidate(budgetsProvider);
      await reportWidgetBudgetNotificationCheck(ref);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Budget created' : 'Budget updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save budget: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteBudget(Budget budget, List<Category> categories) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text(
          '${_budgetLabel(budget, categories)} will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(budgetStoreProvider).delete(budget);
      ref.invalidate(budgetsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Budget deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete budget: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _budgetLabel(Budget budget, List<Category> categories) {
    final month = DateFormat('MMMM yyyy')
        .format(DateTime(budget.year, budget.month));

    switch (budget.scope) {
      case BudgetScope.monthly:
        return 'Monthly budget • $month';
      case BudgetScope.category:
        final category = categories.where((item) => item.id == budget.scopeKey);
        final name = category.isEmpty ? budget.scopeKey : category.first.name;
        return 'Category budget • $name • $month';
      case BudgetScope.wallet:
        return 'Wallet budget • ${_formatLabel(budget.scopeKey)} • $month';
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
}

class _BudgetEditorSheet extends StatefulWidget {
  const _BudgetEditorSheet({
    required this.month,
    required this.existing,
    required this.categories,
  });

  final DateTime month;
  final Budget? existing;
  final List<Category> categories;

  @override
  State<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<_BudgetEditorSheet> {
  late final TextEditingController amountController;
  late BudgetScope scope;
  String? scopeKey;
  late bool rollover;
  String? error;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    amountController = TextEditingController(
      text: existing?.amount.toStringAsFixed(0) ?? '',
    );
    scope = existing?.scope ?? BudgetScope.monthly;
    scopeKey = existing?.scope == BudgetScope.monthly
        ? null
        : existing?.scopeKey;
    rollover = existing?.rollover ?? false;
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  void submit() {
    final amount = double.tryParse(amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() => error = 'Enter a valid amount greater than ৳0.');
      return;
    }

    if (scope != BudgetScope.monthly && scopeKey == null) {
      setState(() {
        error = scope == BudgetScope.category
            ? 'Select a category.'
            : 'Select a payment method.';
      });
      return;
    }

    Navigator.of(context).pop(
      _BudgetDraft(
        scope: scope,
        scopeKey: scope == BudgetScope.monthly ? null : scopeKey,
        amount: amount,
        rollover: rollover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(20, 12, 20, keyboardInset + 24),
            children: [
              Text(
                widget.existing == null ? 'Add budget' : 'Edit budget',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                DateFormat('MMMM yyyy').format(widget.month),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              _selectionField(
                label: 'Budget type',
                value: _scopeLabel(scope),
                icon: Icons.tune_outlined,
                onTap: _selectScope,
              ),
              if (scope != BudgetScope.monthly) ...[
                const SizedBox(height: 14),
                _selectionField(
                  label: scope == BudgetScope.category
                      ? 'Category'
                      : 'Payment method',
                  value: _scopeKeyLabel(),
                  icon: scope == BudgetScope.category
                      ? Icons.category_outlined
                      : Icons.account_balance_wallet_outlined,
                  onTap: _selectScopeKey,
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Budget amount',
                  prefixText: '৳ ',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  errorText: error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onChanged: (_) {
                  if (error != null) setState(() => error = null);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rollover unused amount'),
                subtitle: const Text('Carry unused budget into the next month'),
                value: rollover,
                onChanged: (value) {
                  setState(() => rollover = value);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: submit,
                  icon: Icon(
                    widget.existing == null ? Icons.add : Icons.save_outlined,
                  ),
                  label: Text(
                    widget.existing == null ? 'Create budget' : 'Save changes',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scopeLabel(BudgetScope value) {
    return switch (value) {
      BudgetScope.monthly => 'Monthly budget',
      BudgetScope.category => 'Category budget',
      BudgetScope.wallet => 'Payment method budget',
    };
  }

  String _scopeKeyLabel() {
    if (scopeKey == null) {
      return scope == BudgetScope.category
          ? 'Select a category'
          : 'Select a payment method';
    }

    if (scope == BudgetScope.category) {
      for (final category in widget.categories) {
        if (category.id == scopeKey) return category.name;
      }
      return scopeKey!;
    }

    return _formatLabel(scopeKey!);
  }

  Widget _selectionField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectScope() async {
    final selected = await _showPicker<BudgetScope>(
      title: 'Budget type',
      subtitle: 'Choose what this budget tracks.',
      options: [
        _BudgetPickerOption(
          value: BudgetScope.monthly,
          title: 'Monthly budget',
          subtitle: 'Set a limit for all expenses',
          icon: Icons.calendar_month_outlined,
        ),
        _BudgetPickerOption(
          value: BudgetScope.category,
          title: 'Category budget',
          subtitle: 'Track spending in one category',
          icon: Icons.category_outlined,
        ),
        _BudgetPickerOption(
          value: BudgetScope.wallet,
          title: 'Payment method budget',
          subtitle: 'Track spending by payment method',
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
      selectedValue: scope,
    );

    if (selected == null || !mounted) return;
    setState(() {
      scope = selected;
      scopeKey = null;
      error = null;
    });
  }

  Future<void> _selectScopeKey() async {
    final List<_BudgetPickerOption<String>> options;
    if (scope == BudgetScope.category) {
      options = widget.categories
          .where((category) => category.type == CategoryType.expense)
          .map(
            (category) => _BudgetPickerOption(
              value: category.id,
              title: category.name,
              subtitle: 'Expense category',
              icon: Icons.category_outlined,
            ),
          )
          .toList();
    } else {
      options = PaymentMethod.values
          .map(
            (method) => _BudgetPickerOption(
              value: method.name,
              title: _formatLabel(method.name),
              subtitle: 'Payment method',
              icon: Icons.account_balance_wallet_outlined,
            ),
          )
          .toList();
    }

    final selected = await _showPicker<String>(
      title: scope == BudgetScope.category ? 'Category' : 'Payment method',
      subtitle: scope == BudgetScope.category
          ? 'Choose an expense category for this budget.'
          : 'Choose which payment method this budget tracks.',
      options: options,
      selectedValue: scopeKey,
    );

    if (selected == null || !mounted) return;
    setState(() {
      scopeKey = selected;
      error = null;
    });
  }

  Future<T?> _showPicker<T>({
    required String title,
    required String subtitle,
    required List<_BudgetPickerOption<T>> options,
    required T? selectedValue,
  }) {
    final theme = Theme.of(context);

    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
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
            const SizedBox(height: 16),
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No expense categories available.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ...options.map((option) {
              final selected = option.value == selectedValue;
              final color = theme.colorScheme.primary;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? color.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: () => Navigator.of(sheetContext).pop(option.value),
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(option.icon, color: color, size: 21),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  option.subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            selected ? Icons.check_circle : Icons.chevron_right,
                            color: selected
                                ? color
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
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
}

class _BudgetPickerOption<T> {
  const _BudgetPickerOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final T value;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _BudgetDraft {
  const _BudgetDraft({
    required this.scope,
    required this.scopeKey,
    required this.amount,
    required this.rollover,
  });

  final BudgetScope scope;
  final String? scopeKey;
  final double amount;
  final bool rollover;
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.account_balance_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget overview',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMMM yyyy').format(month),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.budgets,
    required this.allBudgets,
    required this.transactions,
  });

  final List<Budget> budgets;
  final List<Budget> allBudgets;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final totalBudget = budgets.fold<double>(
      0,
      (sum, budget) => sum + _effectiveAmount(budget),
    );

    final totalSpent = budgets.fold<double>(
      0,
      (sum, budget) => sum + _spent(budget),
    );

    final remaining = totalBudget - totalSpent;
    final usage = totalBudget <= 0 ? 0.0 : totalSpent / totalBudget;
    final progress = usage.clamp(0.0, 1.0);
    final color = usage >= 1
        ? Colors.red
        : usage >= 0.9
        ? Colors.orange
        : Colors.green;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Monthly budget status',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${(usage * 100).round()}% used',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: 'Available budget',
                    value: AppUtils.formatCurrency(totalBudget),
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Spent',
                    value: AppUtils.formatCurrency(totalSpent),
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: remaining >= 0 ? 'Remaining' : 'Over budget',
                    value: AppUtils.formatCurrency(remaining.abs()),
                    color: remaining >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  double _spent(Budget budget) {
    return calculateBudgetSpent(budget: budget, transactions: transactions);
  }

  double _effectiveAmount(Budget budget) {
    return calculateEffectiveBudgetLimit(
      budget: budget,
      allBudgets: allBudgets,
      transactions: transactions,
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.categories,
    required this.allBudgets,
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
  });

  final Budget budget;
  final List<Category> categories;
  final List<Budget> allBudgets;
  final List<Transaction> transactions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final spent = _spent();
    final effectiveAmount = _effectiveAmount();
    final usage = effectiveAmount <= 0 ? 0.0 : spent / effectiveAmount;
    final progress = usage.clamp(0.0, 1.0);
    final remaining = effectiveAmount - spent;
    final color = usage >= 1
        ? Colors.red
        : usage >= 0.9
        ? Colors.orange
        : usage >= 0.75
        ? Colors.amber.shade800
        : Colors.green;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(Icons.track_changes_outlined, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        budget.rollover ? 'Rollover enabled' : 'Fixed budget',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: 'Budget',
                    value: AppUtils.formatCurrency(effectiveAmount),
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Spent',
                    value: AppUtils.formatCurrency(spent),
                    color: color,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: remaining >= 0 ? 'Left' : 'Over',
                    value: AppUtils.formatCurrency(remaining.abs()),
                    color: remaining >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              color: color,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(usage * 100).round()}% used',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label() {
    final month = DateFormat('MMM yyyy')
        .format(DateTime(budget.year, budget.month));

    switch (budget.scope) {
      case BudgetScope.monthly:
        return 'Monthly budget • $month';
      case BudgetScope.category:
        final match = categories.where(
          (category) => category.id == budget.scopeKey,
        );
        return 'Category • ${match.isEmpty ? budget.scopeKey : match.first.name}';
      case BudgetScope.wallet:
        return 'Payment • ${budget.scopeKey}';
    }
  }

  double _spent() {
    return calculateBudgetSpent(budget: budget, transactions: transactions);
  }

  double _effectiveAmount() {
    return calculateEffectiveBudgetLimit(
      budget: budget,
      allBudgets: allBudgets,
      transactions: transactions,
    );
  }
}

class _MonthComparison extends StatelessWidget {
  const _MonthComparison({required this.transactions, required this.month});

  final List<Transaction> transactions;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final current = _total(month);
    final previous = _total(DateTime(month.year, month.month - 1));
    final difference = current - previous;
    final isImproved = difference <= 0;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current vs previous month',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: DateFormat('MMM yyyy')
                        .format(DateTime(month.year, month.month - 1)),
                    value: AppUtils.formatCurrency(previous),
                    color: Colors.orange,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: DateFormat('MMM yyyy').format(month),
                    value: AppUtils.formatCurrency(current),
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Icon(
                  isImproved ? Icons.trending_down : Icons.trending_up,
                  color: isImproved ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isImproved
                        ? 'Spending improved compared with last month'
                        : 'Spending increased compared with last month',
                    style: TextStyle(
                      color: isImproved ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${difference >= 0 ? '+' : '-'}'
                  '${AppUtils.formatCurrency(difference.abs())}',
                  style: TextStyle(
                    color: isImproved ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _total(DateTime value) {
    return transactions
        .where((item) {
          final date = item.date.toLocal();
          return item.type == TransactionType.expense &&
              date.year == value.year &&
              date.month == value.month;
        })
        .fold<double>(0, (sum, item) => sum + item.amount);
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _EmptyBudgetState extends StatelessWidget {
  const _EmptyBudgetState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'No budget set for this month',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a budget to track your spending progress.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Create budget'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
