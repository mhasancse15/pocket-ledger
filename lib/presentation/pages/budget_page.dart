import 'dart:ui';

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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor
            .withValues(alpha: .84),
        toolbarHeight: 52,
        titleSpacing: 16,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Budget management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          _MonthNavigationButton(
            tooltip: 'Previous month',
            icon: Icons.chevron_left_rounded,
            onPressed: () => _changeMonth(-1),
          ),
          _MonthNavigationButton(
            tooltip: 'Next month',
            icon: Icons.chevron_right_rounded,
            onPressed: () => _changeMonth(1),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.secondary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: .28),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openBudgetEditor,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: scheme.onPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'Add budget',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: IgnorePointer(child: _BudgetAmbient())),
          budgetsAsync.when(
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
                  children: [
                    _MonthHeader(
                      month: _month,
                      hasBudgets: monthBudgets.isNotEmpty,
                    ),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: .5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${monthBudgets.length} set',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 4),
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
        ],
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
      showDragHandle: false,
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
    scope = existing?.scope ?? BudgetScope.category;
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
    final scheme = theme.colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final suggestedCategories = widget.categories
        .where(
          (category) =>
              category.type == CategoryType.expense && !category.isArchived,
        )
        .take(4)
        .toList();

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: IgnorePointer(child: _BudgetAmbient())),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.92,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: theme.brightness == Brightness.dark
                        ? [
                            scheme.surface.withValues(alpha: .98),
                            scheme.surface.withValues(alpha: .94),
                            scheme.surfaceContainerLow.withValues(alpha: .98),
                          ]
                        : [
                            Colors.white.withValues(alpha: .96),
                            Colors.white.withValues(alpha: .91),
                            const Color(0xFFF1F3F7).withValues(alpha: .97),
                          ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(34),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: theme.brightness == Brightness.dark ? .12 : .82,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.brightness == Brightness.dark ? .32 : .18,
                      ),
                      blurRadius: 40,
                      offset: const Offset(0, -12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(20, 10, 20, keyboardInset + 20),
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant.withValues(alpha: .75),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.existing == null
                                    ? 'Add budget'
                                    : 'Edit budget',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.4,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: scheme.tertiary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMMM yyyy')
                                        .format(widget.month),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.surfaceContainerHighest
                                .withValues(alpha: .65),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _selectionField(
                      label: 'Budget type',
                      value: _scopeLabel(scope),
                      icon: Icons.category_outlined,
                    ),
                    if (scope == BudgetScope.category) ...[
                      const SizedBox(height: 12),
                      _categoryField(suggestedCategories),
                    ] else if (scope == BudgetScope.wallet) ...[
                      const SizedBox(height: 12),
                      _selectionField(
                        label: 'Payment method',
                        value: _scopeKeyLabel(),
                        icon: Icons.account_balance_wallet_outlined,
                        onTap: _selectScopeKey,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _amountField(),
                    if (error != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
                      decoration: _editorCardDecoration(context),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rollover unused amount',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Carry unused budget into the next month',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: rollover,
                            onChanged: (value) {
                              setState(() => rollover = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: SizedBox(
                            height: 56,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [scheme.primary, scheme.secondary],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.primary.withValues(
                                      alpha: .34,
                                    ),
                                    blurRadius: 25,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 9),
                                  ),
                                  BoxShadow(
                                    color: scheme.secondary.withValues(
                                      alpha: .13,
                                    ),
                                    blurRadius: 30,
                                    offset: const Offset(0, 11),
                                  ),
                                ],
                              ),
                              child: FilledButton.icon(
                                onPressed: submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: scheme.onPrimary,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: Icon(
                                  widget.existing == null
                                      ? Icons.add_rounded
                                      : Icons.save_outlined,
                                ),
                                label: Text(
                                  widget.existing == null
                                      ? 'Create budget'
                                      : 'Save changes',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.primary,
                                backgroundColor: scheme.surface.withValues(
                                  alpha: .74,
                                ),
                                side: BorderSide(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: .48,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(19),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 112,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant.withValues(alpha: .7),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountField() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _editorCardDecoration(context),
      child: Row(
        children: [
          _editorIcon(Icons.payments_outlined, scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BUDGET AMOUNT',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .65,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '৳',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: .55,
                            ),
                          ),
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                        ),
                        onChanged: (_) {
                          if (error != null) setState(() => error = null);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryField(List<Category> suggestedCategories) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _selectScopeKey,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
          decoration: _editorCardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _editorIcon(Icons.category_outlined, scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: .8,
                            ),
                            fontWeight: FontWeight.w700,
                            letterSpacing: .65,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _scopeKeyLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scopeKey == null
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (suggestedCategories.isNotEmpty) ...[
                const SizedBox(height: 11),
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: .35),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final category in suggestedCategories)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ActionChip(
                            onPressed: () {
                              setState(() {
                                scopeKey = category.id;
                                error = null;
                              });
                            },
                            label: Text(category.name),
                            labelStyle: theme.textTheme.bodySmall?.copyWith(
                              color: scopeKey == category.id
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: scopeKey == category.id
                                ? scheme.primaryContainer.withValues(alpha: .55)
                                : scheme.surfaceContainerHighest.withValues(
                                    alpha: .55,
                                  ),
                            side: BorderSide(
                              color: scopeKey == category.id
                                  ? scheme.primary.withValues(alpha: .24)
                                  : Colors.transparent,
                            ),
                            shape: const StadiumBorder(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primary = scheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: _editorCardDecoration(context),
          child: Row(
            children: [
              _editorIcon(icon, primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: .8),
                        fontWeight: FontWeight.w700,
                        letterSpacing: .65,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onTap != null)
                Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectScopeKey() async {
    final List<_BudgetPickerOption<String>> options;
    if (scope == BudgetScope.category) {
      options = widget.categories
          .where(
            (category) =>
                category.type == CategoryType.expense && !category.isArchived,
          )
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

  Widget _editorIcon(IconData icon, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .1)),
      ),
      child: Icon(icon, color: color, size: 21),
    );
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

class _MonthNavigationButton extends StatelessWidget {
  const _MonthNavigationButton({
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
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: dark ? .96 : .9),
          shape: BoxShape.circle,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: dark ? .25 : .16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .055),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: scheme.primary.withValues(alpha: dark ? .08 : .035),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: Icon(icon, size: 21),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.hasBudgets});

  final DateTime month;
  final bool hasBudgets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _budgetGlassDecoration(context, radius: 32, elevated: true),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: .18),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.account_balance_outlined,
              color: scheme.onPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget overview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMMM yyyy').format(month),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: hasBudgets ? scheme.tertiary : scheme.outline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  hasBudgets ? 'Active' : 'No budgets',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;
    final color = usage >= 1 ? scheme.error : scheme.tertiary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _budgetGlassDecoration(context, radius: 32),
      child: Padding(
        padding: EdgeInsets.zero,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${(usage * 100).round()}% used',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
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
                    color: remaining >= 0 ? scheme.tertiary : scheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              borderRadius: BorderRadius.circular(99),
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (remaining < 0)
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 17,
                          color: color,
                        ),
                      if (remaining < 0) const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          totalBudget <= 0
                              ? 'Set a budget to track spending'
                              : remaining < 0
                              ? 'Exceeded by ${AppUtils.formatCurrency(remaining.abs())}'
                              : '${AppUtils.formatCurrency(remaining)} remaining',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: remaining < 0
                                    ? color
                                    : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (totalBudget > 0)
                  Text(
                    'Capped at ${AppUtils.formatCurrency(totalBudget)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
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
    final scheme = Theme.of(context).colorScheme;
    final color = usage >= 1 ? scheme.error : scheme.tertiary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _budgetGlassDecoration(context, radius: 32),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: color.withValues(alpha: .13),
                  child: Icon(
                    budget.scope == BudgetScope.monthly
                        ? Icons.calendar_month_outlined
                        : budget.scope == BudgetScope.wallet
                        ? Icons.account_balance_wallet_outlined
                        : Icons.monitor_heart_outlined,
                    color: color,
                  ),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
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
                  tooltip: 'Budget options',
                  iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    color: remaining >= 0 ? scheme.tertiary : scheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
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
    final scheme = Theme.of(context).colorScheme;
    final trendColor = isImproved ? scheme.tertiary : scheme.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _budgetGlassDecoration(context, radius: 32, elevated: true),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current vs previous month',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              'Comparative outflow analytics',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: DateFormat('MMM yyyy')
                        .format(DateTime(month.year, month.month - 1)),
                    value: AppUtils.formatCurrency(previous),
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: DateFormat('MMM yyyy').format(month),
                    value: AppUtils.formatCurrency(current),
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: trendColor.withValues(alpha: .18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isImproved ? Icons.trending_down : Icons.trending_up,
                      color: trendColor,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isImproved
                          ? 'Spending improved compared with last month'
                          : 'Spending increased compared with last month',
                      style: TextStyle(
                        color: trendColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${difference >= 0 ? '+' : '-'}'
                        '${AppUtils.formatCurrency(difference.abs())}',
                        style: TextStyle(
                          color: trendColor,
                          fontWeight: FontWeight.bold,
                        ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _budgetGlassDecoration(context, radius: 28, elevated: true),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.account_balance_outlined,
              size: 29,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No budget set for this month',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a budget to track your spending progress.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ActionChip(
            onPressed: onAdd,
            avatar: Icon(Icons.add_rounded, size: 18, color: scheme.onPrimary),
            label: Text(
              'Create budget',
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: scheme.primary,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            shape: const StadiumBorder(),
          ),
        ],
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

BoxDecoration _budgetGlassDecoration(
  BuildContext context, {
  required double radius,
  bool elevated = false,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: dark
        ? scheme.surface.withValues(alpha: .96)
        : Colors.white.withValues(alpha: elevated ? .88 : .76),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: dark
          ? scheme.outlineVariant.withValues(alpha: .3)
          : Colors.white.withValues(alpha: .85),
    ),
    boxShadow: [
      BoxShadow(
        color: scheme.primary.withValues(alpha: dark ? .035 : .045),
        blurRadius: elevated ? 28 : 24,
        offset: const Offset(0, 10),
      ),
      if (elevated)
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? .1 : .025),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
    ],
  );
}

BoxDecoration _editorCardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: dark
        ? scheme.surface.withValues(alpha: .98)
        : Colors.white.withValues(alpha: .9),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: dark
          ? scheme.outlineVariant.withValues(alpha: .3)
          : scheme.outlineVariant.withValues(alpha: .38),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? .12 : .035),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

class _BudgetAmbient extends StatelessWidget {
  const _BudgetAmbient();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 30,
            right: -80,
            child: _glowOrb(scheme.primary.withValues(alpha: .17), 250),
          ),
          Positioned(
            top: 360,
            left: -100,
            child: _glowOrb(scheme.secondary.withValues(alpha: .12), 280),
          ),
          Positioned(
            top: 760,
            right: -90,
            child: _glowOrb(
              scheme.tertiary.withValues(alpha: dark ? .08 : .10),
              260,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowOrb(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 54, sigmaY: 54),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
