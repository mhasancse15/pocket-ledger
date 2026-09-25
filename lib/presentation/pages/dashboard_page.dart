import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/monthly_limit.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/limit_provider.dart';
import '../providers/transaction_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  static const purple = Color(0xFF5D56AA);
  static const pageBackground = Color(0xFFF7F7FB);
  static const darkText = Color(0xFF23232B);

  late DateTime selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month);
  }

  (int, int) get monthKey => (
  selectedMonth.year,
  selectedMonth.month,
  );

  bool get isCurrentMonth {
    final now = DateTime.now();
    return selectedMonth.year == now.year &&
        selectedMonth.month == now.month;
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
    final current = await ref.read(
      monthlyLimitProvider(monthKey).future,
    );

    if (!mounted) return;

    final result = await showModalBottomSheet<_TargetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TargetEditorSheet(
        month: selectedMonth,
        current: current,
      ),
    );

    if (result == null || !mounted) return;

    try {
      if (result.remove) {
        await ref.read(limitRepositoryProvider).deleteMonthlyLimit(
          selectedMonth.year,
          selectedMonth.month,
        );
      } else if (result.amount != null) {
        final now = DateTime.now();

        await ref.read(limitRepositoryProvider).setMonthlyLimit(
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

      if (!mounted) return;

      _showMessage(
        result.remove
            ? 'Monthly target removed'
            : 'Monthly target saved',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to update target: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(
      monthlyTransactionsProvider(monthKey),
    );
    final limitAsync = ref.watch(monthlyLimitProvider(monthKey));
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];

    final categoryNames = <String, String>{
      for (final category in categories) category.id: category.name,
    };

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 52,
        titleSpacing: 16,
        title: const Text(
          'Pocket Ledger',
          style: TextStyle(
            color: darkText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Set monthly target',
            onPressed: editMonthlyTarget,
            icon: const Icon(Icons.track_changes_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.goNamed(AppRoutes.settingsName),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: transactionsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => _ErrorState(
            message: error.toString(),
          ),
          data: (transactions) {
            final income = _total(
              transactions,
              TransactionType.income,
            );
            final expense = _total(
              transactions,
              TransactionType.expense,
            );
            final balance = income - expense;
            final target = limitAsync.valueOrNull?.amount;

            final visibleTransactions = isCurrentMonth
                ? _todayTransactions(transactions)
                : _monthTransactions(transactions).take(4).toList();

            return RefreshIndicator(
              color: purple,
              onRefresh: () async {
                ref.invalidate(monthlyTransactionsProvider(monthKey));
                ref.invalidate(monthlyLimitProvider(monthKey));
                ref.invalidate(allCategoriesProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _monthSelector(),
                  const SizedBox(height: 14),
                  _balanceCard(
                    balance: balance,
                    income: income,
                    expense: expense,
                  ),
                  const SizedBox(height: 16),
                  _budgetSection(
                    expense: expense,
                    target: target,
                  ),
                  const SizedBox(height: 22),
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
      ),
    );
  }

  Widget _monthSelector() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                style: const TextStyle(
                  color: darkText,
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
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: purple,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: purple.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              AppUtils.formatCurrency(balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _heroMetric(
                    icon: Icons.south_west,
                    label: 'Income',
                    value: AppUtils.formatCurrency(income),
                  ),
                ),
              ),

              Container(
                width: 1,
                height: 54,
                color: Colors.white.withOpacity(0.20),
              ),

              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _heroMetric(
                    icon: Icons.north_east,
                    label: 'Expense',
                    value: AppUtils.formatCurrency(expense),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _heroMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 105,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _budgetSection({
    required double expense,
    required double? target,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Monthly target',
                style: TextStyle(
                  color: darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: editMonthlyTarget,
              child: Text(
                target == null ? 'Set target' : 'Edit',
                style: const TextStyle(
                  color: purple,
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
          _targetCard(
            expense: expense,
            target: target,
          ),
      ],
    );
  }

  Widget _targetCard({
    required double expense,
    required double target,
  }) {
    final percentage = expense / target;
    final progress = percentage.clamp(0.0, 1.0);
    final remaining = target - expense;

    final progressColor = percentage >= 1
        ? Colors.redAccent
        : percentage >= 0.9
        ? Colors.orange
        : const Color(0xFF00A578);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
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
                        style: const TextStyle(
                          color: Color(0xFF00A578),
                          fontSize: 22,
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
                        color: remaining >= 0
                            ? Colors.black54
                            : Colors.redAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(percentage * 100).round()}% of ${AppUtils.formatCurrency(target)}',
                style: const TextStyle(
                  color: darkText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 11,
              backgroundColor: const Color(0xFFE8E9ED),
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noTargetCard() {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: const Color(0xFFB9B8F6),
        radius: 18,
        dashWidth: 6,
        dashSpace: 5,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE4E3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.track_changes_outlined,
                size: 29,
                color: purple,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'No monthly target set',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'Set a spending limit to track your progress.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: editMonthlyTarget,
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(
                  Icons.add,
                  size: 20,
                ),
                label: const Text(
                  'Set target',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
                style: const TextStyle(
                  color: darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: const Text(
              'View all',
              style: TextStyle(
                color: purple,
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
    // Empty state: no white card background
    if (transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E7FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 30,
                color: Color(0xFF5D56AA),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No transactions found',
              style: TextStyle(
                color: Color(0xFF23232B),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Add a transaction to start tracking your money.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Existing items: preserve the attached white-card design
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFE6E6EB),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < transactions.length; index++) ...[
            _transactionRow(
              transaction: transactions[index],
              categoryName: categoryNames[
              transactions[index].categoryId
              ],
            ),
            if (index < transactions.length - 1)
              const Divider(
                height: 1,
                color: Color(0xFFE0E0E4),
              ),
          ],
        ],
      ),
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
        context.push(
          '/edit-transaction/${transaction.id}',
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: itemColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                _categoryIcon(category),
                color: itemColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF23232B),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$category • '
                        '${DateFormat('d MMM').format(transaction.date.toLocal())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                    ),
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
                  fontSize: 18,
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
            height: 50,
            child: FilledButton.icon(
              onPressed: () {
                context.pushNamed(AppRoutes.addTransactionName);
              },
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.add),
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
                context.pushNamed(AppRoutes.addTransactionName);
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF00A578),
                side: const BorderSide(color: Color(0xFFE1E1E5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
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

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
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
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Transaction> _todayTransactions(List<Transaction> items) {
    final now = DateTime.now();

    return items.where((item) {
      final date = item.date.toLocal();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

class _TargetResult {
  const _TargetResult.save(this.amount) : remove = false;

  const _TargetResult.remove()
      : amount = null,
        remove = true;

  final double? amount;
  final bool remove;
}

class _TargetEditorSheet extends StatefulWidget {
  const _TargetEditorSheet({
    required this.month,
    required this.current,
  });

  final DateTime month;
  final MonthlyLimit? current;

  @override
  State<_TargetEditorSheet> createState() => _TargetEditorSheetState();
}

class _TargetEditorSheetState extends State<_TargetEditorSheet> {
  late final TextEditingController controller;
  String? error;

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

    Navigator.pop(context, _TargetResult.save(amount));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              keyboardInset + 24,
            ),
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
                  onPressed: save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _DashboardPageState.purple,
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
                    onPressed: () {
                      Navigator.pop(
                        context,
                        const _TargetResult.remove(),
                      );
                    },
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
  });

  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = mathMin(distance + dashWidth, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace;
  }

  double mathMin(double a, double b) => a < b ? a : b;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
