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
import '../widgets/financial_summary_card.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  TransactionType? _selectedType;
  String _query = '';
  DateTime _selectedMonth = DateTime.now();
  DateTimeRange? _dateRange;
  double? _minimumAmount;
  double? _maximumAmount;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    var count = 0;

    if (_selectedCategory != null) count++;
    if (_selectedPaymentMethod != null) count++;
    if (_selectedType != null) count++;
    if (_query.trim().isNotEmpty) count++;
    if (_dateRange != null) count++;
    if (_minimumAmount != null) count++;
    if (_maximumAmount != null) count++;

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 58,
        titleSpacing: 16,
        title: Text(
          'Transactions',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear filters',
            onPressed: _activeFilterCount == 0 ? null : _clearFilters,
            icon: Badge(
              isLabelVisible: _activeFilterCount > 0,
              label: Text('$_activeFilterCount'),
              child: const Icon(Icons.filter_alt_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(message: error.toString()),
        data: (transactions) {
          final filteredTransactions = _filterTransactions(
            transactions,
            categoryNames,
          );
          final topExpenseCategories = _topExpenseCategories(transactions);
          final filteredIncome = _totalForType(
            filteredTransactions,
            TransactionType.income,
          );
          final filteredExpense = _totalForType(
            filteredTransactions,
            TransactionType.expense,
          );
          final filteredBalance = filteredIncome - filteredExpense;

          final groupedTransactions = _groupByDate(filteredTransactions);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      _MonthSelector(
                        selectedMonth: _selectedMonth,
                        onPrevious: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month - 1,
                            );
                          });
                        },
                        onNext: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _SummaryCard(
                        income: filteredIncome,
                        expense: filteredExpense,
                        balance: filteredBalance,
                        transactionCount: filteredTransactions.length,
                        selectedType: _selectedType,
                      ),
                      const SizedBox(height: 16),
                      _SearchField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                          });
                        },
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        onFilterPressed: () {
                          _showFilterSheet(categories);
                        },
                        activeFilterCount: _activeFilterCount,
                      ),
                      const SizedBox(height: 10),
                      _CategoryQuickTabs(
                        categories: topExpenseCategories,
                        categoryNames: categoryNames,
                        selectedCategory: _selectedCategory,
                        onSelected: (categoryId) {
                          setState(() => _selectedCategory = categoryId);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (groupedTransactions.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyTransactionsState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = groupedTransactions.entries.elementAt(
                        index,
                      );

                      return _DateTransactionGroup(
                        date: entry.key,
                        transactions: entry.value,
                        categoryNames: categoryNames,
                        onTransactionLongPress: _showTransactionActions,
                        onTransactionActions: _showTransactionActions,
                      );
                    }, childCount: groupedTransactions.length),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.pushNamed(AppRoutes.addTransactionName),
        icon: const Icon(Icons.add),
        label: const Text('Add transaction'),
      ),
    );
  }

  List<Transaction> _filterTransactions(
    List<Transaction> transactions,
    Map<String, String> categoryNames,
  ) {
    final normalizedQuery = _query.trim().toLowerCase();

    final filtered = transactions.where((transaction) {
      final date = transaction.date.toLocal();
      final sameMonth =
          _dateRange != null ||
          (date.year == _selectedMonth.year &&
              date.month == _selectedMonth.month);
      final dateMatches =
          _dateRange == null ||
          !date.isBefore(_dateRange!.start) &&
              !date.isAfter(
                DateTime(
                  _dateRange!.end.year,
                  _dateRange!.end.month,
                  _dateRange!.end.day,
                  23,
                  59,
                  59,
                ),
              );

      final categoryMatches =
          _selectedCategory == null ||
          transaction.categoryId == _selectedCategory;

      final paymentMatches =
          _selectedPaymentMethod == null ||
          transaction.paymentMethod.name == _selectedPaymentMethod;

      final typeMatches =
          _selectedType == null || transaction.type == _selectedType;

      final queryMatches =
          normalizedQuery.isEmpty ||
          (categoryNames[transaction.categoryId] ?? transaction.categoryId)
              .toLowerCase()
              .contains(normalizedQuery) ||
          _formatLabel(transaction.paymentMethod.name)
              .toLowerCase()
              .contains(normalizedQuery) ||
          (transaction.note ?? '').toLowerCase().contains(normalizedQuery);
      final minimumMatches =
          _minimumAmount == null || transaction.amount >= _minimumAmount!;
      final maximumMatches =
          _maximumAmount == null || transaction.amount <= _maximumAmount!;

      return sameMonth &&
          dateMatches &&
          categoryMatches &&
          paymentMatches &&
          typeMatches &&
          queryMatches &&
          minimumMatches &&
          maximumMatches;
    }).toList();

    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  List<MapEntry<String, double>> _topExpenseCategories(
    List<Transaction> transactions,
  ) {
    final totals = <String, double>{};

    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) continue;

      final date = transaction.date.toLocal();
      final bool isInsideSelectedPeriod;

      if (_dateRange != null) {
        final rangeStart = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final rangeEnd = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
          23,
          59,
          59,
          999,
        );

        isInsideSelectedPeriod =
            !date.isBefore(rangeStart) && !date.isAfter(rangeEnd);
      } else {
        isInsideSelectedPeriod =
            date.year == _selectedMonth.year &&
            date.month == _selectedMonth.month;
      }

      if (!isInsideSelectedPeriod) continue;

      totals.update(
        transaction.categoryId,
        (currentAmount) => currentAmount + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final visibleCategories = totals.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));
    final topCategories = visibleCategories.take(6).toList();

    if (_selectedCategory != null &&
        !topCategories.any((item) => item.key == _selectedCategory)) {
      topCategories.add(
        MapEntry(_selectedCategory!, totals[_selectedCategory!] ?? 0),
      );
    }

    return topCategories;
  }

  Map<DateTime, List<Transaction>> _groupByDate(
    List<Transaction> transactions,
  ) {
    final grouped = <DateTime, List<Transaction>>{};

    for (final transaction in transactions) {
      final localDate = transaction.date.toLocal();
      final date = DateTime(localDate.year, localDate.month, localDate.day);

      grouped.putIfAbsent(date, () => []).add(transaction);
    }

    return grouped;
  }

  Future<void> _showFilterSheet(List<Category> availableCategories) async {
    var draftCategory = _selectedCategory;
    var draftPaymentMethod = _selectedPaymentMethod;
    var draftType = _selectedType;
    var draftRange = _dateRange;
    var minController = TextEditingController(
      text: _minimumAmount?.toStringAsFixed(2) ?? '',
    );
    var maxController = TextEditingController(
      text: _maximumAmount?.toStringAsFixed(2) ?? '',
    );
    String? amountError;

    final result =
        await showModalBottomSheet<
          ({
            String? category,
            String? paymentMethod,
            TransactionType? type,
            DateTimeRange? range,
            double? minimum,
            double? maximum,
          })
        >(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

                return SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filter transactions',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  draftCategory = null;
                                  draftPaymentMethod = null;
                                  draftType = null;
                                  draftRange = null;
                                  amountError = null;
                                  minController.clear();
                                  maxController.clear();
                                });
                              },
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Transaction type',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            _FilterChoiceChip(
                              label: 'All',
                              selected: draftType == null,
                              onSelected: () {
                                setModalState(() => draftType = null);
                              },
                            ),
                            _FilterChoiceChip(
                              label: 'Expenses',
                              selected: draftType == TransactionType.expense,
                              onSelected: () {
                                setModalState(() {
                                  draftType = TransactionType.expense;
                                  if (draftCategory != null &&
                                      !availableCategories.any(
                                        (category) =>
                                            category.id == draftCategory &&
                                            category.type ==
                                                CategoryType.expense,
                                      )) {
                                    draftCategory = null;
                                  }
                                });
                              },
                            ),
                            _FilterChoiceChip(
                              label: 'Income',
                              selected: draftType == TransactionType.income,
                              onSelected: () {
                                setModalState(() {
                                  draftType = TransactionType.income;
                                  if (draftCategory != null &&
                                      !availableCategories.any(
                                        (category) =>
                                            category.id == draftCategory &&
                                            category.type ==
                                                CategoryType.income,
                                      )) {
                                    draftCategory = null;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _FilterSelectionField(
                          label: 'Category',
                          value: draftCategory == null
                              ? 'All categories'
                              : _categoryName(
                                  availableCategories,
                                  draftCategory!,
                                ),
                          icon: Icons.category_outlined,
                          onTap: () async {
                            final categoriesForType =
                                availableCategories
                                    .where(
                                      (category) =>
                                          draftType == null ||
                                          category.type.name == draftType!.name,
                                    )
                                    .toList()
                                  ..sort(
                                    (a, b) => a.name.toLowerCase().compareTo(
                                      b.name.toLowerCase(),
                                    ),
                                  );
                            final selected = await _showFilterPicker<String>(
                              title: 'Category',
                              subtitle: 'Choose a transaction category.',
                              selectedValue: draftCategory ?? '',
                              options: [
                                const _FilterPickerOption(
                                  value: '',
                                  title: 'All categories',
                                  subtitle: 'Do not filter by category',
                                  icon: Icons.category_outlined,
                                ),
                                ...categoriesForType.map(
                                  (category) => _FilterPickerOption(
                                    value: category.id,
                                    title: category.name,
                                    subtitle: category.type.name == 'income'
                                        ? 'Income category'
                                        : 'Expense category',
                                    icon: Icons.category_outlined,
                                  ),
                                ),
                              ],
                            );
                            if (selected != null) {
                              setModalState(
                                () => draftCategory = selected.isEmpty
                                    ? null
                                    : selected,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDateRange: draftRange,
                            );
                            if (picked != null) {
                              setModalState(() => draftRange = picked);
                            }
                          },
                          icon: const Icon(Icons.date_range_outlined),
                          label: Text(
                            draftRange == null
                                ? 'Any date range'
                                : '${DateFormat('d MMM').format(draftRange!.start)} - '
                                      '${DateFormat('d MMM yyyy').format(draftRange!.end)}',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Minimum amount',
                                  prefixText: '৳ ',
                                ),
                                onChanged: (_) {
                                  if (amountError != null) {
                                    setModalState(() => amountError = null);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: maxController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Maximum amount',
                                  prefixText: '৳ ',
                                ),
                                onChanged: (_) {
                                  if (amountError != null) {
                                    setModalState(() => amountError = null);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        if (amountError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            amountError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _FilterSelectionField(
                          label: 'Payment method',
                          value: draftPaymentMethod == null
                              ? 'All payment methods'
                              : _formatLabel(draftPaymentMethod!),
                          icon: Icons.payments_outlined,
                          onTap: () async {
                            final selected = await _showFilterPicker<String>(
                              title: 'Payment method',
                              subtitle: 'Choose a payment method to filter.',
                              selectedValue: draftPaymentMethod ?? '',
                              options: [
                                const _FilterPickerOption(
                                  value: '',
                                  title: 'All payment methods',
                                  subtitle: 'Do not filter by payment method',
                                  icon: Icons.payments_outlined,
                                ),
                                ...PaymentMethod.values.map(
                                  (method) => _FilterPickerOption(
                                    value: method.name,
                                    title: _formatLabel(method.name),
                                    subtitle: 'Payment method',
                                    icon: Icons.account_balance_wallet_outlined,
                                  ),
                                ),
                              ],
                            );
                            if (selected != null) {
                              setModalState(
                                () => draftPaymentMethod = selected.isEmpty
                                    ? null
                                    : selected,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              final minimum = double.tryParse(
                                minController.text.trim(),
                              );
                              final maximum = double.tryParse(
                                maxController.text.trim(),
                              );

                              if ((minController.text.trim().isNotEmpty &&
                                      (minimum == null || !minimum.isFinite)) ||
                                  (maxController.text.trim().isNotEmpty &&
                                      (maximum == null || !maximum.isFinite))) {
                                setModalState(
                                  () => amountError = 'Enter valid numbers for the amount filters.',
                                );
                                return;
                              }
                              if (minimum != null &&
                                  maximum != null &&
                                  minimum > maximum) {
                                setModalState(
                                  () => amountError = 'Minimum amount cannot exceed maximum amount.',
                                );
                                return;
                              }

                              Navigator.of(context).pop((
                                category: draftCategory,
                                paymentMethod: draftPaymentMethod,
                                type: draftType,
                                range: draftRange,
                                minimum: minimum,
                                maximum: maximum,
                              ));
                            },
                            child: const Text('Apply filters'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    minController.dispose();
    maxController.dispose();

    if (!mounted || result == null) return;
    setState(() {
      _selectedCategory = result.category;
      _selectedPaymentMethod = result.paymentMethod;
      _selectedType = result.type;
      _dateRange = result.range;
      _minimumAmount = result.minimum;
      _maximumAmount = result.maximum;
    });
  }

  String _categoryName(List<Category> categories, String categoryId) {
    for (final category in categories) {
      if (category.id == categoryId) return category.name;
    }
    return categoryId;
  }

  Future<T?> _showFilterPicker<T>({
    required String title,
    required String subtitle,
    required T selectedValue,
    required List<_FilterPickerOption<T>> options,
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
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  option.subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected) Icon(Icons.check_circle, color: color),
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

  Future<void> _showTransactionActions(Transaction transaction) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit transaction'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate transaction'),
              onTap: () => Navigator.pop(context, 'duplicate'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete transaction'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      context.pushNamed(
        AppRoutes.editTransactionName,
        pathParameters: {'id': transaction.id},
      );
      return;
    }
    if (action == 'duplicate') {
      final now = DateTime.now();
      final result = await ref
          .read(transactionRepositoryProvider)
          .addTransaction(
            transaction.copyWith(
              id: AppUtils.generateId(),
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (!mounted) return;
      result.fold((failure) => _showMessage(failure.message), (_) {
        ref.invalidate(allTransactionsProvider);
        _showMessage('Transaction duplicated');
      });
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This transaction will be removed from your records.',
        ),
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
    final result = await ref
        .read(transactionRepositoryProvider)
        .deleteTransaction(transaction.id);
    result.fold((failure) => _showMessage(failure.message), (_) {
      ref.invalidate(allTransactionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await ref
                  .read(transactionRepositoryProvider)
                  .addTransaction(transaction);
              ref.invalidate(allTransactionsProvider);
            },
          ),
        ),
      );
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedCategory = null;
      _selectedPaymentMethod = null;
      _selectedType = null;
      _query = '';
      _dateRange = null;
      _minimumAmount = null;
      _maximumAmount = null;
    });
  }

  double _totalForType(List<Transaction> transactions, TransactionType type) {
    return transactions
        .where((transaction) => transaction.type == type)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  static String _formatLabel(String value) {
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

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, size: 27),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(selectedMonth),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, size: 27),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.income,
    required this.expense,
    required this.balance,
    required this.transactionCount,
    required this.selectedType,
  });

  final double income;
  final double expense;
  final double balance;
  final int transactionCount;
  final TransactionType? selectedType;

  @override
  Widget build(BuildContext context) {
    final label = switch (selectedType) {
      TransactionType.income => 'Filtered income',
      TransactionType.expense => 'Filtered expense',
      null => 'Available balance',
    };
    final amount = switch (selectedType) {
      TransactionType.income => income,
      TransactionType.expense => expense,
      null => balance,
    };

    return FinancialSummaryCard(
      label: label,
      amount: amount,
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
}

class _CategoryQuickTabs extends StatelessWidget {
  const _CategoryQuickTabs({
    required this.categories,
    required this.categoryNames,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<MapEntry<String, double>> categories;
  final Map<String, String> categoryNames;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildChip(
              context: context,
              label: 'All',
              selected: selectedCategory == null,
              primaryColor: primaryColor,
              onTap: () => onSelected(null),
            );
          }

          final category = categories[index - 1];
          final categoryId = category.key;
          final name = categoryNames[categoryId] ?? categoryId;
          return _buildChip(
            context: context,
            label: name,
            selected: selectedCategory == categoryId,
            primaryColor: primaryColor,
            onTap: () => onSelected(categoryId),
          );
        },
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool selected,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: primaryColor,
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(
        color: selected ? primaryColor : Theme.of(context).dividerColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onFilterPressed,
    required this.activeFilterCount,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFilterPressed;
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search transactions',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
            Badge(
              isLabelVisible: activeFilterCount > 0,
              label: Text('$activeFilterCount'),
              child: IconButton(
                onPressed: onFilterPressed,
                icon: const Icon(Icons.tune),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _FilterPickerOption<T> {
  const _FilterPickerOption({
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

class _FilterSelectionField extends StatelessWidget {
  const _FilterSelectionField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
}

class _DateTransactionGroup extends StatelessWidget {
  const _DateTransactionGroup({
    required this.date,
    required this.transactions,
    required this.categoryNames,
    required this.onTransactionLongPress,
    required this.onTransactionActions,
  });

  final DateTime date;
  final List<Transaction> transactions;
  final Map<String, String> categoryNames;
  final Future<void> Function(Transaction) onTransactionLongPress;
  final Future<void> Function(Transaction) onTransactionActions;

  double _sum(TransactionType type) {
    return transactions
        .where((item) => item.type == type)
        .fold<double>(0, (sum, item) => sum + item.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateLabel(date),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _groupSummary(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${transactions.length} ${transactions.length == 1 ? 'transaction' : 'transactions'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              for (var index = 0; index < transactions.length; index++) ...[
                _TransactionCard(
                  transaction: transactions[index],
                  categoryName: categoryNames[transactions[index].categoryId],
                  onLongPress: () =>
                      onTransactionLongPress(transactions[index]),
                  onActions: () => onTransactionActions(transactions[index]),
                ),
                if (index < transactions.length - 1) Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _groupSummary() {
    final income = _sum(TransactionType.income);
    final expense = _sum(TransactionType.expense);
    if (income == 0) return 'Expense ${AppUtils.formatCurrency(expense)}';
    if (expense == 0) return 'Income ${AppUtils.formatCurrency(income)}';
    return 'Income ${AppUtils.formatCurrency(income)} • '
        'Expense ${AppUtils.formatCurrency(expense)}';
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) return 'Today';
    if (transactionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return DateFormat('EEE, d MMM').format(date);
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    this.categoryName,
    required this.onLongPress,
    required this.onActions,
  });

  final Transaction transaction;
  final String? categoryName;
  final VoidCallback onLongPress;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? const Color(0xFF00A578) : const Color(0xFFE85E6F);
    final category = categoryName ?? transaction.categoryId;
    final title = transaction.note?.trim().isNotEmpty == true
        ? transaction.note!
        : category;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        context.pushNamed(
          AppRoutes.transactionDetailsName,
          pathParameters: {'id': transaction.id},
        );
      },
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isIncome ? Icons.south_west : Icons.north_east,
                color: color,
                size: 25,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$category • ${_formatPaymentMethod(transaction.paymentMethod.name)} • '
                    '${DateFormat('h:mm a').format(transaction.date.toLocal())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${isIncome ? '+' : '-'}${AppUtils.formatCurrency(transaction.amount)}',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Transaction actions',
              visualDensity: VisualDensity.compact,
              onPressed: onActions,
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPaymentMethod(String value) {
    return value
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 30,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No transactions found',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing your filters or add a transaction.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Unable to load transactions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
