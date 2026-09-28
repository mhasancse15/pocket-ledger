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
  Color get borderColor => Theme.of(context).colorScheme.outlineVariant;

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

  void changeTransactionType(TransactionType type) {
    if (transactionType == type) return;

    setState(() {
      transactionType = type;
      selectedCategory = null;
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
        title: Text(
          'Edit transaction',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete transaction',
            onPressed: isLoading ? null : deleteTransaction,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                'Update your transaction',
                style: TextStyle(
                  color: textColor,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep your income and expenses organized.',
                style: TextStyle(color: mutedColor, fontSize: 14),
              ),
              const SizedBox(height: 18),
              typeSelector(),
              const SizedBox(height: 14),
              amountField(),
              const SizedBox(height: 12),
              selectionField(
                label: 'Category',
                value: categoriesAsync.isLoading
                    ? 'Loading categories...'
                    : categoryLabel(categories),
                icon: Icons.category_outlined,
                showLoading: categoriesAsync.isLoading,
                onTap:
                    isLoading ||
                        categoriesAsync.isLoading ||
                        categoriesAsync.hasError ||
                        categories.isEmpty
                    ? null
                    : () => selectCategory(categories),
              ),
              const SizedBox(height: 12),
              selectionField(
                label: 'Payment method',
                value: selectedPaymentMethod,
                icon: Icons.account_balance_wallet_outlined,
                onTap: isLoading ? null : selectPaymentMethod,
              ),
              if (categoriesAsync.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    'Unable to load categories',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (!categoriesAsync.isLoading &&
                  !categoriesAsync.hasError &&
                  categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    'No categories available for this transaction type.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              dateField(),
              const SizedBox(height: 12),
              noteField(),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : updateTransaction,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    disabledBackgroundColor: primary.withOpacity(.55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: isLoading
                      ? SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cardColor,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    isLoading ? 'Updating...' : 'Update transaction',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget typeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
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
    bool showLoading = false,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: borderColor),
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
                      style: TextStyle(color: mutedColor, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
                Icon(Icons.keyboard_arrow_down_rounded, color: mutedColor),
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
        ? const Color(0xFFE85E6F)
        : const Color(0xFF00A578);

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: isLoading
          ? null
          : () {
              changeTransactionType(type);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : mutedColor,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget amountField() {
    return TextFormField(
      controller: amountController,
      autofocus: false,
      enabled: !isLoading,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: TextStyle(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
      decoration: inputDecoration(
        label: 'Amount',
        hint: '0.00',
        icon: Icons.payments_outlined,
      ).copyWith(prefixText: '৳ '),
      validator: (value) {
        final amount = double.tryParse(value?.trim() ?? '');

        if (amount == null || amount <= 0) {
          return 'Enter an amount greater than ৳0';
        }

        return null;
      },
    );
  }

  Widget noteField() {
    return TextFormField(
      controller: noteController,
      enabled: !isLoading,
      maxLines: 3,
      maxLength: AppConstants.maxNoteLength,
      textCapitalization: TextCapitalization.sentences,
      decoration: inputDecoration(
        label: 'Title or note',
        hint: 'Example: Grocery shopping or monthly salary',
        icon: Icons.notes_outlined,
        alignLabelWithHint: true,
      ),
    );
  }

  Widget dateField() {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: isLoading ? null : selectDate,
      child: InputDecorator(
        decoration: inputDecoration(
          label: 'Transaction date',
          icon: Icons.calendar_today_outlined,
          suffix: const Icon(Icons.chevron_right),
        ),
        child: Text(DateFormat('EEE, d MMM yyyy').format(selectedDate)),
      ),
    );
  }

  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffix,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: primary),
      suffixIcon: suffix,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
