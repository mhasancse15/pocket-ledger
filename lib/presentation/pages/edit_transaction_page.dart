import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../viewmodels/transaction_viewmodel.dart';

class EditTransactionPage extends ConsumerStatefulWidget {
  const EditTransactionPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  ConsumerState<EditTransactionPage> createState() =>
      _EditTransactionPageState();
}

class _EditTransactionPageState extends ConsumerState<EditTransactionPage> {
  Color get primary => Theme.of(context).colorScheme.primary;
  Color get background => Theme.of(context).scaffoldBackgroundColor;
  Color get textColor => Theme.of(context).colorScheme.onSurface;
  Color get cardColor => Theme.of(context).colorScheme.surface;
  Color get mutedColor => Theme.of(context).colorScheme.onSurfaceVariant;
  final formKey = GlobalKey<FormState>();

  late final TextEditingController amountController;
  late final TextEditingController noteController;

  DateTime selectedDate = DateTime.now();
  TransactionType transactionType = TransactionType.expense;

  String? selectedCategory;
  String selectedPaymentMethod = AppConstants.paymentMethods.first;

  Transaction? transaction;

  bool pageLoading = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    amountController = TextEditingController();
    noteController = TextEditingController();

    loadTransaction();
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> loadTransaction() async {
    try {
      final result = await ref
          .read(transactionViewModelProvider)
          .getTransaction(widget.transactionId);

      if (!mounted) return;

      if (result == null) {
        setState(() {
          pageLoading = false;
        });
        return;
      }

      setState(() {
        transaction = result;
        amountController.text = result.amount.toStringAsFixed(2);
        noteController.text = result.note ?? '';
        selectedDate = result.date;
        transactionType = result.type;
        selectedCategory = result.categoryId;
        selectedPaymentMethod = paymentMethodLabel(result.paymentMethod);
        pageLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        pageLoading = false;
      });

      showMessage('Unable to load transaction: $error');
    }
  }

  Future<void> selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select transaction date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme
                .copyWith(primary: primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        selectedDate.hour,
        selectedDate.minute,
      );
    });
  }

  Future<void> updateTransaction() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (selectedCategory == null) {
      showMessage('Select a category.');
      return;
    }

    final amount = double.tryParse(amountController.text.trim());

    if (amount == null || amount <= 0) {
      showMessage('Enter a valid amount greater than ৳0.');
      return;
    }

    final currentTransaction = transaction;

    if (currentTransaction == null) {
      showMessage('Transaction not found.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final paymentMethod = PaymentMethod.values.firstWhere(
        (method) => paymentMethodLabel(method) == selectedPaymentMethod,
        orElse: () => PaymentMethod.cash,
      );

      final updatedTransaction = Transaction(
        id: currentTransaction.id,
        type: transactionType,
        amount: amount,
        categoryId: selectedCategory!,
        date: selectedDate,
        paymentMethod: paymentMethod,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        createdAt: currentTransaction.createdAt,
        updatedAt: DateTime.now(),
      );

      await ref
          .read(transactionViewModelProvider)
          .updateTransaction(updatedTransaction);

      if (!mounted) return;

      showMessage('Transaction updated successfully');
      context.pop(true);
    } catch (error) {
      if (!mounted) return;

      showMessage('Could not update transaction: $error');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> deleteTransaction() async {
    final currentTransaction = transaction;

    if (currentTransaction == null || isLoading) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete transaction?'),
          content: const Text(
            'This transaction will be permanently removed. '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      await ref
          .read(transactionViewModelProvider)
          .deleteTransaction(currentTransaction.id);

      if (!mounted) return;

      showMessage('Transaction deleted');
      context.pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Could not delete transaction: $error');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(
      categoriesByTypeProvider(
        transactionType == TransactionType.expense
            ? CategoryType.expense
            : CategoryType.income,
      ),
    );

    final categories =
        categoriesAsync.valueOrNull
            ?.where(
              (category) =>
                  !category.isArchived || category.id == selectedCategory,
            )
            .toList() ??
        const <Category>[];

    if (pageLoading) {
      return Scaffold(
        backgroundColor: background,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    if (transaction == null) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: Text(
            'Edit transaction',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
          ),
        ),
        body: const Center(child: Text('Transaction not found')),
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        toolbarHeight: 60,
        centerTitle: true,
        titleSpacing: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background.withValues(alpha: .86),
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            tooltip: 'Go back',
            onPressed: isLoading ? null : () => context.pop(),
            style: IconButton.styleFrom(
              backgroundColor: cardColor.withValues(alpha: .9),
              foregroundColor: textColor,
              fixedSize: const Size(44, 44),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        title: Text(
          'Edit transaction',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: textColor, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete transaction',
            onPressed: isLoading ? null : deleteTransaction,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.error,
              fixedSize: const Size(44, 44),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _EditTransactionBackdrop()),
          SafeArea(
            bottom: false,
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                children: [
                  Text(
                    'Update your transaction',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Keep your income and expenses organized.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: mutedColor),
                  ),
                  const SizedBox(height: 12),
                  typeSelector(),
                  const SizedBox(height: 10),
                  amountField(),
                  const SizedBox(height: 9),
                  selectionField(
                    label: 'Category',
                    value: categoriesAsync.isLoading
                        ? 'Loading categories...'
                        : categoryLabel(categories),
                    icon: Icons.category_outlined,
                    iconColor: const Color(0xFF5148D7),
                    showLoading: categoriesAsync.isLoading,
                    onTap:
                        isLoading ||
                            categoriesAsync.isLoading ||
                            categoriesAsync.hasError ||
                            categories.isEmpty
                        ? null
                        : () => selectCategory(categories),
                  ),
                  const SizedBox(height: 8),
                  selectionField(
                    label: 'Payment method',
                    value: selectedPaymentMethod,
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF0284C7),
                    onTap: isLoading ? null : selectPaymentMethod,
                  ),
                  if (categoriesAsync.hasError)
                    _inlineCategoryError('Unable to load categories'),
                  if (!categoriesAsync.isLoading &&
                      !categoriesAsync.hasError &&
                      categories.isEmpty)
                    _inlineCategoryError(
                      'No categories available for this transaction type.',
                    ),
                  const SizedBox(height: 8),
                  dateField(),
                  const SizedBox(height: 8),
                  noteField(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _EditTransactionFooter(
        isLoading: isLoading,
        onCancel: isLoading ? null : () => context.pop(),
        onSave: isLoading ? null : updateTransaction,
      ),
    );
  }

  Widget typeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: .7),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        children: [
          Expanded(
            child: typeButton(
              type: TransactionType.expense,
              icon: Icons.north_east,
              label: 'Expense',
            ),
          ),
          Expanded(
            child: typeButton(
              type: TransactionType.income,
              icon: Icons.south_west,
              label: 'Income',
            ),
          ),
        ],
      ),
    );
  }

  String categoryLabel(List<Category> categories) {
    if (selectedCategory == null) return 'Select a category';

    for (final category in categories) {
      if (category.id == selectedCategory) return category.name;
    }

    return 'Select a category';
  }

  Widget selectionField({
    required String label,
    required String value,
    required IconData icon,
    Color? iconColor,
    bool showLoading = false,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badgeColor = iconColor ?? primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: cardColor.withValues(alpha: .93),
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .035),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: badgeColor, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (showLoading)
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: mutedColor,
                  ),
                )
              else
                Icon(Icons.expand_more_rounded, color: mutedColor, size: 25),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> selectCategory(List<Category> categories) async {
    final selected = await showSelectionPicker<String>(
      title: 'Category',
      subtitle: 'Choose a category for this transaction.',
      selectedValue: selectedCategory,
      options: categories
          .map(
            (category) => _EditTransactionPickerOption(
              value: category.id,
              title: category.name,
              subtitle: category.isArchived
                  ? 'Archived category'
                  : transactionType == TransactionType.expense
                  ? 'Expense category'
                  : 'Income category',
              icon: Icons.category_outlined,
            ),
          )
          .toList(),
    );

    if (selected == null || !mounted) return;
    setState(() => selectedCategory = selected);
  }

  Future<void> selectPaymentMethod() async {
    final selected = await showSelectionPicker<String>(
      title: 'Payment method',
      subtitle: 'Choose how this transaction was paid.',
      selectedValue: selectedPaymentMethod,
      options: AppConstants.paymentMethods
          .map(
            (method) => _EditTransactionPickerOption(
              value: method,
              title: formatLabel(method),
              subtitle: 'Payment method',
              icon: Icons.account_balance_wallet_outlined,
            ),
          )
          .toList(),
    );

    if (selected == null || !mounted) return;
    setState(() => selectedPaymentMethod = selected);
  }

  Future<T?> showSelectionPicker<T>({
    required String title,
    required String subtitle,
    required T? selectedValue,
    required List<_EditTransactionPickerOption<T>> options,
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
                  'No categories available.',
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

  Widget typeButton({
    required TransactionType type,
    required IconData icon,
    required String label,
  }) {
    final selected = transactionType == type;

    final color = type == TransactionType.expense
        ? const Color(0xFFF43F5E)
        : const Color(0xFF059669);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
          border: selected
              ? Border.all(color: color.withValues(alpha: .18))
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .04),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: .12)
                    : scheme.surface.withValues(alpha: .55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? color : mutedColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget amountField() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AMOUNT',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              _EditFieldIcon(
                icon: Icons.payments_rounded,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                '৳',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: TextFormField(
                  controller: amountController,
                  autofocus: false,
                  enabled: !isLoading,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: textColor,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.6,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');

                    if (amount == null || amount <= 0) {
                      return 'Enter an amount greater than ৳0';
                    }

                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget noteField() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EditFieldIcon(
                icon: Icons.notes_rounded,
                color: const Color(0xFF6366F1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: noteController,
                  enabled: !isLoading,
                  maxLines: 2,
                  maxLength: AppConstants.maxNoteLength,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Title or note',
                    hintText: 'Add description...',
                    counterText: '',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${noteController.text.length}/${AppConstants.maxNoteLength}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget dateField() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(23),
      onTap: isLoading ? null : selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: cardColor.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(23),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .035),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _EditFieldIcon(
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF2563EB),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction date',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEE, d MMM yyyy').format(selectedDate),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: mutedColor, size: 26),
          ],
        ),
      ),
    );
  }

  Widget _inlineCategoryError(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 7, left: 12),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
        ),
      ),
    );
  }

  String paymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.debitCard:
        return 'Debit Card';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.mobileWallet:
        return 'Mobile Wallet';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  String formatLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                    '${word.substring(1)}',
        )
        .join(' ');
  }
}

class _EditTransactionPickerOption<T> {
  const _EditTransactionPickerOption({
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

class _EditFieldIcon extends StatelessWidget {
  const _EditFieldIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _EditTransactionBackdrop extends StatelessWidget {
  const _EditTransactionBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        ),
        Positioned(
          top: -75,
          left: -110,
          child: _orb(colors.primary.withValues(alpha: .15), 280),
        ),
        Positioned(
          top: 250,
          right: -120,
          child: _orb(const Color(0xFFF43F5E).withValues(alpha: .11), 290),
        ),
      ],
    );
  }

  Widget _orb(Color color, double size) {
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

class _EditTransactionFooter extends StatelessWidget {
  const _EditTransactionFooter({
    required this.isLoading,
    required this.onCancel,
    required this.onSave,
  });

  final bool isLoading;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: .94),
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: .25)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: scheme.surface.withValues(alpha: .9),
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: .35),
                        ),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: onSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF4F46E5)
                            .withValues(alpha: .7),
                        shape: const StadiumBorder(),
                      ),
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        isLoading ? 'Updating...' : 'Update transaction',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 128,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
