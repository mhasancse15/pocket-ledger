import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/monthly_limit.dart';
import '../../domain/entities/monthly_saving.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/budget_calculations.dart';
import '../providers/budget_notification_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/limit_provider.dart';
import '../providers/monthly_saving_provider.dart';
import '../providers/preferences_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/financial_summary_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver {
  Color get primary => Theme.of(context).colorScheme.primary;
  Color get pageBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get textColor => Theme.of(context).colorScheme.onSurface;
  Color get cardColor => Theme.of(context).colorScheme.surface;
  Color get mutedColor => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get borderColor => Theme.of(context).colorScheme.outlineVariant;

  BoxDecoration _glassDecoration({double radius = 28}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: cardColor.withValues(alpha: isDark ? .84 : .78),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: isDark ? .10 : .82),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? .18 : .045),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _ambientBackground() {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 30,
          right: -80,
          child: _glowOrb(colors.primary.withValues(alpha: .17), 250),
        ),
        Positioned(
          top: 360,
          left: -100,
          child: _glowOrb(colors.secondary.withValues(alpha: .12), 280),
        ),
        Positioned(
          top: 760,
          right: -90,
          child: _glowOrb(colors.tertiary.withValues(alpha: .10), 260),
        ),
      ],
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

  late DateTime selectedMonth;
  (int, int)? _lastFinalizedPreviousMonth;
  bool _isFinalizingPreviousMonth = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _finalizePreviousMonthSurplus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _finalizePreviousMonthSurplus();
    }
  }

  Future<void> _showMonthlySavingsHistory() async {
    final entries = await ref.read(allMonthlySavingEntriesProvider.future);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MonthlySavingsHistorySheet(entries: entries),
    );
  }

  Future<void> _finalizePreviousMonthSurplus() async {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1);
    final previousKey = (previousMonth.year, previousMonth.month);
    if (_isFinalizingPreviousMonth ||
        _lastFinalizedPreviousMonth == previousKey) {
      return;
    }
    _isFinalizingPreviousMonth = true;
    try {
      ref.invalidate(monthlyTransactionsProvider(previousKey));
      ref.invalidate(monthlySavingEntriesProvider(previousKey));
      final transactions = await ref.read(
        monthlyTransactionsProvider(previousKey).future,
      );
      final entries = await ref.read(
        monthlySavingEntriesProvider(previousKey).future,
      );
      final summary = calculateMonthlySavingSummary(
        year: previousMonth.year,
        month: previousMonth.month,
        transactions: transactions,
        entries: entries,
      );
      final finalized = await ref
          .read(monthlySavingStoreProvider)
          .carryForwardMonth(
            summary: summary,
            incomeDate: DateTime(now.year, now.month),
          );
      _lastFinalizedPreviousMonth = previousKey;
      final amountCarried = summary.surplus > summary.saved
          ? summary.surplus
          : summary.saved;
      if (finalized && amountCarried > 0 && mounted) {
        _showMessage(
          '${AppUtils.formatCurrency(amountCarried)} from last month was added to this month’s income.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Unable to add last month’s savings to this month’s income: $error',
        );
      }
    } finally {
      _isFinalizingPreviousMonth = false;
    }
  }

  (int, int) get monthKey => (selectedMonth.year, selectedMonth.month);

  bool get isCurrentMonth {
    final now = DateTime.now();
    return selectedMonth.year == now.year && selectedMonth.month == now.month;
  }

  void changeMonth(int offset) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
      );
    });
  }

  Future<void> editMonthlyTarget() async {
    final current = await ref.read(monthlyLimitProvider(monthKey).future);

    if (!mounted) return;

    final result = await showModalBottomSheet<_TargetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _TargetEditorSheet(month: selectedMonth, current: current),
    );

    if (result == null || !mounted) return;

    try {
      if (result.remove) {
        await ref
            .read(limitRepositoryProvider)
            .deleteMonthlyLimit(selectedMonth.year, selectedMonth.month);
      } else if (result.amount != null) {
        final now = DateTime.now();

        await ref
            .read(limitRepositoryProvider)
            .setMonthlyLimit(
              MonthlyLimit(
                id: current?.id ?? AppUtils.generateId(),
                year: selectedMonth.year,
                month: selectedMonth.month,
                amount: result.amount!,
                createdAt: current?.createdAt ?? now,
                updatedAt: now,
              ),
            );
      }

      ref.invalidate(monthlyLimitProvider(monthKey));
      ref.invalidate(allLimitsProvider);
      await reportWidgetBudgetNotificationCheck(ref);

      if (!mounted) return;

      _showMessage(
        result.remove ? 'Monthly target removed' : 'Monthly target saved',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to update target: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _monthlySavingsSection({
    required List<Transaction> transactions,
    required List<MonthlySavingEntry> entries,
  }) {
    final summary = calculateMonthlySavingSummary(
      year: selectedMonth.year,
      month: selectedMonth.month,
      transactions: transactions,
      entries: entries,
    );
    final isPastMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month,
    ).isBefore(DateTime(DateTime.now().year, DateTime.now().month));

    return _MonthlySavingsCard(
      summary: summary,
      entries: entries,
      isPastMonth: isPastMonth,
      onViewAll: _showMonthlySavingsHistory,
      onDelete: _deleteMonthlySaving,
    );
  }

  Future<void> _deleteMonthlySaving(MonthlySavingEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove savings allocation?'),
        content: Text(
          '${AppUtils.formatCurrency(entry.amount)} will be returned to this month’s available surplus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(monthlySavingStoreProvider).delete(entry);
      if (!mounted) return;
      _showMessage('Savings allocation removed');
    } catch (error) {
      _showMessage('Unable to remove savings allocation: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(monthlyTransactionsProvider(monthKey));
    final limitAsync = ref.watch(monthlyLimitProvider(monthKey));
    final monthlySavingsAsync = ref.watch(
      monthlySavingEntriesProvider(monthKey),
    );
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? const <Budget>[];
    final recurringRules =
        ref.watch(activeRecurringRulesProvider).valueOrNull ?? const [];
    final preferences = ref.watch(preferencesNotifierProvider);
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];

    final categoryNames = <String, String>{
      for (final category in categories) category.id: category.name,
    };

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        toolbarHeight: 52,
        titleSpacing: 16,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: pageBackground.withValues(alpha: .82),
        title: Text(
          'Pocket Ledger',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add expense',
            onPressed: () => context.pushNamed(
              AppRoutes.addTransactionName,
              extra: TransactionType.expense,
            ),
            style: IconButton.styleFrom(
              backgroundColor: cardColor.withValues(alpha: .72),
              foregroundColor: mutedColor,
              fixedSize: const Size(40, 40),
            ),
            icon: const Icon(Icons.power_settings_new),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.goNamed(AppRoutes.settingsName),
            style: IconButton.styleFrom(
              backgroundColor: cardColor.withValues(alpha: .72),
              foregroundColor: mutedColor,
              fixedSize: const Size(40, 40),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: IgnorePointer(child: _ambientBackground())),
            transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(message: error.toString()),
              data: (transactions) {
                final income = _total(transactions, TransactionType.income);
                final expense = _total(transactions, TransactionType.expense);
                final balance = income - expense;
                final target = limitAsync.valueOrNull?.amount;

                final visibleTransactions = isCurrentMonth
                    ? _todayTransactions(transactions)
                    : _monthTransactions(transactions).take(4).toList();
                final monthBudgets = budgets
                    .where(
                      (budget) =>
                          budget.year == selectedMonth.year &&
                          budget.month == selectedMonth.month,
                    )
                    .toList();
                final expenseTransactions = transactions
                    .where((item) => item.type == TransactionType.expense)
                    .toList();
                final upcomingRules = recurringRules.toList()
                  ..sort(
                    (a, b) =>
                        a.nextOccurrenceDate.compareTo(b.nextOccurrenceDate),
                  );

                return RefreshIndicator(
                  color: primary,
                  onRefresh: () async {
                    ref.invalidate(monthlyTransactionsProvider(monthKey));
                    ref.invalidate(monthlyLimitProvider(monthKey));
                    ref.invalidate(monthlySavingEntriesProvider(monthKey));
                    ref.invalidate(allCategoriesProvider);
                    ref.invalidate(budgetsProvider);
                    ref.invalidate(activeRecurringRulesProvider);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _monthSelector(),
                      const SizedBox(height: 14),
                      if (_isSectionVisible(
                        preferences,
                        DashboardSection.balance,
                      )) ...[
                        _balanceCard(
                          balance: balance,
                          income: income,
                          expense: expense,
                          transactionCount: transactions.length,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_isSectionVisible(
                        preferences,
                        DashboardSection.monthlyTarget,
                      )) ...[
                        _budgetSection(expense: expense, target: target),
                        const SizedBox(height: 22),
                      ],
                      if (_isSectionVisible(
                        preferences,
                        DashboardSection.monthlySavings,
                      )) ...[
                        _monthlySavingsSection(
                          transactions: transactions,
                          entries: monthlySavingsAsync.valueOrNull ?? const [],
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (_isSectionVisible(
                        preferences,
                        DashboardSection.budgetStatus,
                      )) ...[
                        _budgetStatusSection(
                          budgets: monthBudgets,
                          allBudgets: budgets,
                          transactions: transactions,
                          categoryNames: categoryNames,
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (_isSectionVisible(
                        preferences,
                        DashboardSection.todayTransactions,
                      )) ...[
                        _sectionHeader(
                          title: isCurrentMonth
                              ? "Today's transactions"
                              : 'Recent transactions',
                          subtitle: isCurrentMonth
                              ? 'Your spending activity today'
                              : DateFormat('MMMM yyyy').format(selectedMonth),
                          actionLabel: 'View all',
                          onAction: () {
                            context.goNamed(AppRoutes.transactionsName);
                          },
                        ),
                        const SizedBox(height: 14),
                        _transactionsCard(
                          transactions: visibleTransactions,
                          categoryNames: categoryNames,
                        ),
                        const SizedBox(height: 28),
                      ],
                      if (_isSectionVisible(
                        preferences,
                        DashboardSection.categorySummary,
                      )) ...[
                        _categorySummarySection(
                          transactions: expenseTransactions,
                          categoryNames: categoryNames,
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (_isSectionVisible(
                        preferences,
                        DashboardSection.upcomingBills,
                      )) ...[
                        _upcomingBillsSection(
                          upcomingRules.take(3).toList(),
                          categoryNames,
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (_isSectionVisible(
                        preferences,
                        DashboardSection.savingsGoals,
                      )) ...[
                        _savingsGoalsSection(),
                        const SizedBox(height: 22),
                      ],
                      const SizedBox(height: 32),
                      _sectionHeader(
                        title: 'Quick actions',
                        subtitle: 'Record a transaction in seconds',
                      ),
                      const SizedBox(height: 14),
                      _quickActions(),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthSelector() {
    return Container(
      height: 60,
      decoration: _glassDecoration(radius: 30),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month - 1,
                );
              });
            },
            icon: const Icon(Icons.chevron_left, size: 28),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(selectedMonth),
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month + 1,
                );
              });
            },
            icon: const Icon(Icons.chevron_right, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard({
    required double balance,
    required double income,
    required double expense,
    required int transactionCount,
  }) {
    return FinancialSummaryCard(
      label: 'Available balance',
      amount: balance,
      metrics: [
        FinancialSummaryMetric(
          label: 'Income',
          value: AppUtils.formatCurrency(income),
          icon: Icons.south_west,
        ),
        FinancialSummaryMetric(
          label: 'Expense',
          value: AppUtils.formatCurrency(expense),
          icon: Icons.north_east,
        ),
        FinancialSummaryMetric(
          label: 'Records',
          value: '$transactionCount',
          icon: Icons.receipt_long_outlined,
        ),
      ],
    );
  }

  Widget _budgetSection({required double expense, required double? target}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Monthly target',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: editMonthlyTarget,
              child: Text(
                target == null ? 'Set target' : 'Edit',
                style: TextStyle(
                  color: primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (target == null || target <= 0)
          _noTargetCard()
        else
          _targetCard(expense: expense, target: target),
      ],
    );
  }

  Widget _targetCard({required double expense, required double target}) {
    final percentage = expense / target;
    final progress = percentage.clamp(0.0, 1.0);
    final remaining = target - expense;

    final progressColor = percentage >= 1
        ? Colors.redAccent
        : percentage >= 0.9
        ? Colors.orange
        : const Color(0xFF00A578);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: _glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${AppUtils.formatCurrency(expense)} spent',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remaining >= 0
                          ? '${AppUtils.formatCurrency(remaining)} remaining'
                          : '${AppUtils.formatCurrency(remaining.abs())} over target',
                      style: TextStyle(
                        color: remaining >= 0 ? mutedColor : Colors.redAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: '${(percentage * 100).round()}% ',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      TextSpan(
                        text: 'of ${AppUtils.formatCurrency(target)}',
                        style: TextStyle(
                          color: mutedColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noTargetCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: _glassDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: .58),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.track_changes_outlined, size: 25, color: primary),
          ),
          const SizedBox(height: 10),
          Text(
            'No monthly target set',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set a spending limit to track your progress effortlessly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedColor, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: editMonthlyTarget,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Set target',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSectionVisible(
    Map<String, dynamic> preferences,
    DashboardSection section,
  ) {
    return preferences[section.preferenceKey] as bool? ?? true;
  }

  Widget _budgetStatusSection({
    required List<Budget> budgets,
    required List<Budget> allBudgets,
    required List<Transaction> transactions,
    required Map<String, String> categoryNames,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Budget status',
          subtitle: DateFormat('MMMM yyyy').format(selectedMonth),
          actionLabel: 'View all',
          onAction: () => context.pushNamed(AppRoutes.budgetsName),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _glassDecoration(),
          child: budgets.isEmpty
              ? Row(
                  children: [
                    _emptyIcon(Icons.pie_chart_outline_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No budgets for this month',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Create budget limits for categories',
                            style: TextStyle(color: mutedColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.pushNamed(AppRoutes.budgetsName),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Budget'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 11),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < budgets.length && index < 3;
                      index++
                    ) ...[
                      if (index > 0) Divider(color: borderColor),
                      _budgetStatusRow(
                        budgets[index],
                        allBudgets,
                        transactions,
                        categoryNames,
                      ),
                    ],
                    if (budgets.length > 3)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              context.pushNamed(AppRoutes.budgetsName),
                          child: Text('+${budgets.length - 3} more budgets'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _budgetStatusRow(
    Budget budget,
    List<Budget> allBudgets,
    List<Transaction> transactions,
    Map<String, String> categoryNames,
  ) {
    final spent = calculateBudgetSpent(
      budget: budget,
      transactions: transactions,
    );
    final limit = calculateEffectiveBudgetLimit(
      budget: budget,
      allBudgets: allBudgets,
      transactions: transactions,
    );
    final percentage = limit > 0 ? spent / limit : 0.0;
    final progressColor = percentage >= 1
        ? Colors.redAccent
        : percentage >= 0.9
        ? Colors.orange
        : primary;
    final name = switch (budget.scope) {
      BudgetScope.monthly => 'Monthly budget',
      BudgetScope.category => categoryNames[budget.scopeKey] ?? budget.scopeKey,
      BudgetScope.wallet => _readableScopeKey(budget.scopeKey),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${AppUtils.formatCurrency(spent)} / ${AppUtils.formatCurrency(limit)}',
                style: TextStyle(color: mutedColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  String _readableScopeKey(String value) {
    return value
        .split(RegExp(r'[_\s-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Widget _categorySummarySection({
    required List<Transaction> transactions,
    required Map<String, String> categoryNames,
  }) {
    final totals = <String, double>{};
    for (final transaction in transactions) {
      totals.update(
        transaction.categoryId,
        (amount) => amount + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = entries.take(4).toList();
    final highest = topEntries.isEmpty ? 0.0 : topEntries.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Category summary',
          subtitle: DateFormat('MMMM yyyy').format(selectedMonth),
          actionLabel: 'View all',
          onAction: () => context.goNamed(AppRoutes.reportsName),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _glassDecoration(),
          child: topEntries.isEmpty
              ? _emptyInfoCard(
                  icon: Icons.category_outlined,
                  title: 'Expense categories will appear here',
                  message:
                      'Recorded spending organizes into charts automatically.',
                )
              : Column(
                  children: [
                    for (var index = 0; index < topEntries.length; index++) ...[
                      if (index > 0) const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              categoryNames[topEntries[index].key] ??
                                  topEntries[index].key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            AppUtils.formatCurrency(topEntries[index].value),
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: highest > 0
                              ? topEntries[index].value / highest
                              : 0,
                          minHeight: 6,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(primary),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _upcomingBillsSection(
    List<RecurringRule> rules,
    Map<String, String> categoryNames,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Upcoming bills',
          subtitle: 'Your next recurring payments',
          actionLabel: 'View all',
          onAction: () => context.pushNamed(AppRoutes.recurringExpensesName),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _glassDecoration(),
          child: rules.isEmpty
              ? _emptyInfoCard(
                  icon: Icons.event_repeat_outlined,
                  title: 'No upcoming recurring bills',
                  message: 'Keep track of utilities, subscriptions and rent.',
                )
              : Column(
                  children: [
                    for (var index = 0; index < rules.length; index++) ...[
                      if (index > 0) Divider(color: borderColor),
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.calendar_today_outlined,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rules[index].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${categoryNames[rules[index].categoryId] ?? rules[index].categoryId}'
                                  ' • ${DateFormat('d MMM').format(rules[index].nextOccurrenceDate.toLocal())}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            AppUtils.formatCurrency(rules[index].amount),
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _savingsGoalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Savings goals',
          subtitle: 'Track progress toward what matters',
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _glassDecoration(),
          child: Row(
            children: [
              _emptyIcon(Icons.flag_outlined, size: 38, iconSize: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Savings goals are not available yet',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Personal savings milestones are coming soon.',
                      style: TextStyle(color: mutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: mutedColor, fontSize: 14)),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              'View all',
              style: TextStyle(
                color: primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _transactionsCard({
    required List<Transaction> transactions,
    required Map<String, String> categoryNames,
  }) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: _glassDecoration(),
        child: Column(
          children: [
            _emptyIcon(Icons.receipt_long_outlined),
            const SizedBox(height: 10),
            Text(
              'No transactions found',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add a transaction to start tracking your money.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: _glassDecoration(radius: 26),
      child: Column(
        children: [
          for (var index = 0; index < transactions.length; index++) ...[
            _transactionRow(
              transaction: transactions[index],
              categoryName: categoryNames[transactions[index].categoryId],
            ),
            if (index < transactions.length - 1)
              Divider(height: 1, color: borderColor),
          ],
        ],
      ),
    );
  }

  Widget _emptyInfoCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Row(
      children: [
        _emptyIcon(icon, size: 38, iconSize: 19),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: TextStyle(color: mutedColor, fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyIcon(IconData icon, {double size = 40, double iconSize = 20}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer
            .withValues(alpha: .5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: primary, size: iconSize),
    );
  }

  Widget _transactionRow({
    required Transaction transaction,
    required String? categoryName,
  }) {
    final isIncome = transaction.type == TransactionType.income;

    final itemColor = isIncome
        ? const Color(0xFF00A578)
        : const Color(0xFFE85E6F);

    final category = categoryName ?? transaction.categoryId;

    final title = transaction.note?.trim().isNotEmpty == true
        ? transaction.note!.trim()
        : category;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        context.pushNamed(
          AppRoutes.transactionDetailsName,
          pathParameters: {'id': transaction.id},
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: itemColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(_categoryIcon(category), color: itemColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$category • '
                    '${DateFormat('d MMM').format(transaction.date.toLocal())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: mutedColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${isIncome ? '+' : '-'}'
                '${AppUtils.formatCurrency(transaction.amount)}',
                style: TextStyle(
                  color: itemColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                context.pushNamed(
                  AppRoutes.addTransactionName,
                  extra: TransactionType.expense,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: const Icon(Icons.add, size: 19),
              label: const Text(
                'Add expense',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                context.pushNamed(
                  AppRoutes.addTransactionName,
                  extra: TransactionType.income,
                );
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: cardColor,
                foregroundColor: primary,
                side: BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: const Icon(Icons.trending_up),
              label: const Text(
                'Add income',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _categoryIcon(String value) {
    switch (value.toLowerCase()) {
      case 'education':
        return Icons.menu_book_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'food':
      case 'dining':
        return Icons.restaurant_outlined;
      case 'bills':
      case 'utilities':
        return Icons.bolt_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  double _total(List<Transaction> items, TransactionType type) {
    return items
        .where((item) => item.type == type)
        .fold<double>(0, (sum, item) => sum + item.amount);
  }

  List<Transaction> _monthTransactions(List<Transaction> items) {
    return items.where((item) {
      final date = item.date.toLocal();
      return date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Transaction> _todayTransactions(List<Transaction> items) {
    final now = DateTime.now();

    return items.where((item) {
      final date = item.date.toLocal();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}

class _TargetResult {
  const _TargetResult.save(this.amount) : remove = false;

  const _TargetResult.remove() : amount = null, remove = true;

  final double? amount;
  final bool remove;
}

class _TargetEditorSheet extends StatefulWidget {
  const _TargetEditorSheet({required this.month, required this.current});

  final DateTime month;
  final MonthlyLimit? current;

  @override
  State<_TargetEditorSheet> createState() => _TargetEditorSheetState();
}

class _TargetEditorSheetState extends State<_TargetEditorSheet> {
  late final TextEditingController controller;
  String? error;
  bool isClosing = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.current?.amount.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void save() {
    final amount = double.tryParse(controller.text.trim());

    if (amount == null || amount <= 0) {
      setState(() => error = 'Enter an amount greater than ৳0.');
      return;
    }

    close(_TargetResult.save(amount));
  }

  void close([_TargetResult? result]) {
    if (isClosing || !mounted) return;
    setState(() => isClosing = true);
    Navigator.of(context).pop(result);
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
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(20, 16, 20, keyboardInset + 24),
            children: [
              Text(
                'Monthly expense target',
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
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Target amount',
                  prefixText: '৳ ',
                  prefixIcon: const Icon(Icons.track_changes_outlined),
                  errorText: error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onChanged: (_) {
                  if (error != null) setState(() => error = null);
                },
                onSubmitted: (_) => save(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: isClosing ? null : save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save target'),
                ),
              ),
              if (widget.current != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: isClosing
                        ? null
                        : () => close(const _TargetResult.remove()),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove target'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlySavingsCard extends StatelessWidget {
  const _MonthlySavingsCard({
    required this.summary,
    required this.entries,
    required this.isPastMonth,
    required this.onViewAll,
    required this.onDelete,
  });

  final MonthlySavingSummary summary;
  final List<MonthlySavingEntry> entries;
  final bool isPastMonth;
  final VoidCallback onViewAll;
  final ValueChanged<MonthlySavingEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surplus = summary.surplus;
    final available = summary.availableToSave;
    final progress = surplus <= 0
        ? 0.0
        : (summary.saved / surplus).clamp(0.0, 1.0);
    final label = isPastMonth
        ? 'Final monthly surplus'
        : 'Estimated available to save';

    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: isDark ? .88 : .76),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? .10 : .82),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .18 : .045),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: .58,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.savings_outlined,
                    color: theme.colorScheme.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Monthly savings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('All months'),
                ),
                if (summary.income > 0)
                  Flexible(
                    child: Text(
                      '${summary.savingRate.round()}% of income saved',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (summary.income <= 0 && summary.expenses <= 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: isDark ? .36 : .42,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: .24,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Projected surplus',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      AppUtils.formatCurrency(available),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add income this month to calculate your available surplus. Any unallocated surplus will be added to next month automatically.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ] else ...[
              if (summary.hasDeficit)
                _MonthlySavingMetric(
                  label: 'Expenses exceeded income',
                  value: AppUtils.formatCurrency(surplus.abs()),
                  color: Colors.orange.shade800,
                )
              else
                _MonthlySavingMetric(
                  label: label,
                  value: AppUtils.formatCurrency(available),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MonthlySavingMetric(
                      label: 'Income',
                      value: AppUtils.formatCurrency(summary.income),
                    ),
                  ),
                  Expanded(
                    child: _MonthlySavingMetric(
                      label: 'Expenses',
                      value: AppUtils.formatCurrency(summary.expenses),
                    ),
                  ),
                ],
              ),
              if (!summary.hasDeficit) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MonthlySavingMetric(
                        label: 'Saved',
                        value: AppUtils.formatCurrency(summary.saved),
                      ),
                    ),
                    Expanded(
                      child: _MonthlySavingMetric(
                        label: summary.isOverAllocated
                            ? 'Over surplus'
                            : 'Still available',
                        value: AppUtils.formatCurrency(
                          summary.isOverAllocated
                              ? summary.unallocatedSurplus.abs()
                              : available,
                        ),
                        color: summary.isOverAllocated ? Colors.orange : null,
                      ),
                    ),
                  ],
                ),
                if (surplus > 0) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
                if (summary.isOverAllocated) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Your savings are higher than this month’s current surplus. Existing allocations were kept unchanged.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ],
            ],
            if (!isPastMonth && !summary.hasDeficit) ...[
              const SizedBox(height: 12),
              Text(
                'Any unallocated surplus will be added to next month’s income automatically.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (entries.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Savings recorded this month',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              ...entries.map(
                (entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.savings_outlined, size: 20),
                  title: Text(AppUtils.formatCurrency(entry.amount)),
                  subtitle: Text(
                    entry.source == MonthlySavingSource.monthlySurplusRollover
                        ? 'Automatically saved from previous month’s surplus'
                        : entry.note?.isNotEmpty == true
                        ? '${DateFormat('d MMM').format(entry.date)} • ${entry.note}'
                        : DateFormat('d MMM yyyy').format(entry.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove allocation',
                    onPressed: entry.source == MonthlySavingSource.manual
                        ? () => onDelete(entry)
                        : null,
                    icon: Icon(
                      entry.source == MonthlySavingSource.manual
                          ? Icons.delete_outline
                          : Icons.lock_outline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthlySavingMetric extends StatelessWidget {
  const _MonthlySavingMetric({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

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
        const SizedBox(height: 3),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MonthlySavingsHistorySheet extends StatelessWidget {
  const _MonthlySavingsHistorySheet({required this.entries});

  final List<MonthlySavingEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = <(int, int), List<MonthlySavingEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent((entry.year, entry.month), () => []).add(entry);
    }
    final months = grouped.keys.toList()
      ..sort((a, b) {
        final byYear = b.$1.compareTo(a.$1);
        return byYear == 0 ? b.$2.compareTo(a.$2) : byYear;
      });

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Monthly savings history',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (months.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  'Your monthly savings allocations will appear here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...months.map((month) {
                final monthEntries = grouped[month]!;
                final total = monthEntries.fold<double>(
                  0,
                  (sum, entry) => sum + entry.amount,
                );
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(top: 10),
                  child: ExpansionTile(
                    leading: Icon(
                      Icons.calendar_month_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      DateFormat('MMMM yyyy')
                          .format(DateTime(month.$1, month.$2)),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: Text(
                      AppUtils.formatCurrency(total),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    children: [
                      for (final entry in monthEntries)
                        ListTile(
                          dense: true,
                          title: Text(AppUtils.formatCurrency(entry.amount)),
                          subtitle: Text(
                            entry.note?.isNotEmpty == true
                                ? entry.note!
                                : DateFormat('d MMM yyyy').format(entry.date),
                          ),
                        ),
                    ],
                  ),
                );
              }),
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
