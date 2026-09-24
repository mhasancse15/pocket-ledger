import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  TransactionType? _selectedType;
  String _query = '';
  DateTime _selectedMonth = DateTime.now();
  DateTimeRange? _dateRange;
  double? _minimumAmount;
  double? _maximumAmount;

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
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transactions',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Review and manage your activity',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
          final filteredTransactions = _filterTransactions(transactions);
          final total = filteredTransactions.fold<double>(
            0,
            (sum, transaction) => sum + transaction.amount,
          );

          final groupedTransactions = _groupByDate(filteredTransactions);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                        total: total,
                        transactionCount: filteredTransactions.length,
                        selectedType: _selectedType,
                      ),
                      const SizedBox(height: 16),
                      _SearchField(
                        value: _query,
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                          });
                        },
                        onFilterPressed: () {
                          _showFilterSheet(transactions);
                        },
                        activeFilterCount: _activeFilterCount,
                      ),
                      const SizedBox(height: 12),
                      _ActiveFilters(
                        category: _selectedCategory,
                        paymentMethod: _selectedPaymentMethod,
                        type: _selectedType,
                        onRemoveCategory: () {
                          setState(() => _selectedCategory = null);
                        },
                        onRemovePayment: () {
                          setState(() => _selectedPaymentMethod = null);
                        },
                        onRemoveType: () {
                          setState(() => _selectedType = null);
                        },
                      ),
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
                      );
                    }, childCount: groupedTransactions.length),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.addTransactionName),
        icon: const Icon(Icons.add),
        label: const Text('Add transaction'),
      ),
    );
  }

  List<Transaction> _filterTransactions(List<Transaction> transactions) {
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
          transaction.categoryId.toLowerCase().contains(normalizedQuery) ||
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

  Map<DateTime, List<Transaction>> _groupByDate(
    List<Transaction> transactions,
  ) {
    final grouped = <DateTime, List<Transaction>>{};

    for (final transaction in transactions) {
      final date = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      grouped.putIfAbsent(date, () => []).add(transaction);
    }

    return grouped;
  }

  Future<void> _showFilterSheet(List<Transaction> transactions) async {
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

    final categories =
        transactions
            .map((transaction) => transaction.categoryId)
            .toSet()
            .toList()
          ..sort();

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
                                setModalState(
                                  () => draftType = TransactionType.expense,
                                );
                              },
                            ),
                            _FilterChoiceChip(
                              label: 'Income',
                              selected: draftType == TransactionType.income,
                              onSelected: () {
                                setModalState(
                                  () => draftType = TransactionType.income,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: draftCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          hint: const Text('All categories'),
                          items: categories
                              .map(
                                (category) => DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setModalState(() => draftCategory = value);
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
                        DropdownButtonFormField<String>(
                          value: draftPaymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment method',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          hint: const Text('All payment methods'),
                          items: PaymentMethod.values
                              .map(
                                (method) => DropdownMenuItem<String>(
                                  value: method.name,
                                  child: Text(_formatLabel(method.name)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setModalState(() => draftPaymentMethod = value);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedCategory = result.category;
        _selectedPaymentMethod = result.paymentMethod;
        _selectedType = result.type;
        _dateRange = result.range;
        _minimumAmount = result.minimum;
        _maximumAmount = result.maximum;
      });
    });
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
    final title = DateFormat('MMMM yyyy').format(selectedMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
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
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.transactionCount,
    required this.selectedType,
  });

  final double total;
  final int transactionCount;
  final TransactionType? selectedType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = selectedType == TransactionType.income
        ? 'Filtered income'
        : selectedType == TransactionType.expense
        ? 'Filtered expenses'
        : 'Filtered total';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  AppUtils.formatCurrency(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$transactionCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'transactions',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.value,
    required this.onChanged,
    required this.onFilterPressed,
    required this.activeFilterCount,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterPressed;
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search by note or category',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Badge(
          isLabelVisible: activeFilterCount > 0,
          label: Text('$activeFilterCount'),
          child: IconButton(
            onPressed: onFilterPressed,
            icon: const Icon(Icons.tune),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.category,
    required this.paymentMethod,
    required this.type,
    required this.onRemoveCategory,
    required this.onRemovePayment,
    required this.onRemoveType,
  });

  final String? category;
  final String? paymentMethod;
  final TransactionType? type;
  final VoidCallback onRemoveCategory;
  final VoidCallback onRemovePayment;
  final VoidCallback onRemoveType;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (category != null) {
      chips.add(InputChip(label: Text(category!), onDeleted: onRemoveCategory));
    }

    if (paymentMethod != null) {
      chips.add(
        InputChip(label: Text(paymentMethod!), onDeleted: onRemovePayment),
      );
    }

    if (type != null) {
      chips.add(
        InputChip(
          label: Text(type == TransactionType.income ? 'Income' : 'Expense'),
          onDeleted: onRemoveType,
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }
}

class _DateTransactionGroup extends StatelessWidget {
  const _DateTransactionGroup({
    required this.date,
    required this.transactions,
    required this.categoryNames,
    required this.onTransactionLongPress,
  });

  final DateTime date;
  final List<Transaction> transactions;
  final Map<String, String> categoryNames;
  final Future<void> Function(Transaction) onTransactionLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _dateLabel(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Text(
                dateLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            ],
          ),
        ),
        ...transactions.map(
          (transaction) => _TransactionCard(
            transaction: transaction,
            categoryName: categoryNames[transaction.categoryId],
            onLongPress: () => onTransactionLongPress(transaction),
          ),
        ),
      ],
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    }

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
  });

  final Transaction transaction;
  final String? categoryName;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? Colors.green : Colors.redAccent;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isIncome ? Icons.south_west : Icons.north_east,
            color: color,
          ),
        ),
        title: Text(
          transaction.note?.trim().isNotEmpty == true
              ? transaction.note!
              : categoryName ?? transaction.categoryId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${categoryName ?? transaction.categoryId} • '
            '${_formatPaymentMethod(transaction.paymentMethod.name)} • '
            '${DateFormat('d MMM yyyy').format(transaction.date.toLocal())}',
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? '+' : '-'}'
              '${AppUtils.formatCurrency(transaction.amount)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('h:mm a').format(transaction.date.toLocal()),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        onTap: () {
          context.pushNamed(
            AppRoutes.transactionDetailsName,
            pathParameters: {'id': transaction.id},
          );
        },
        onLongPress: onLongPress,
      ),
    );
  }

  static String _formatPaymentMethod(String value) {
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
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: theme.colorScheme.primary.withOpacity(0.55),
            ),
            const SizedBox(height: 20),
            Text(
              'No transactions found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing your filters or add your first transaction for this month.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
