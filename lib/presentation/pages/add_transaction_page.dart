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

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({super.key});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  String _categoryLabel(List<Category> categories) {
    if (selectedCategory == null) return 'Select a category';

    for (final category in categories) {
      if (category.id == selectedCategory) return category.name;
    }

    return 'Select a category';
  }

  Widget _selectionField({
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

  Future<void> _selectCategory(List<Category> categories) async {
    final selected = await _showSelectionPicker<String>(
      title: 'Category',
      subtitle: 'Choose a category for this transaction.',
      selectedValue: selectedCategory,
      options: categories
          .map(
            (category) => _TransactionPickerOption(
              value: category.id,
              title: category.name,
              subtitle: transactionType == TransactionType.expense
                  ? 'Expense category'
                  : 'Income category',
              icon: Icons.category_outlined,
            ),
          )
          .toList(),
    );

    if (selected == null || !mounted) return;
    _setSelectedCategory(selected);
  }

  Future<void> _selectPaymentMethod() async {
    final selected = await _showSelectionPicker<String>(
      title: 'Payment method',
      subtitle: 'Choose how this transaction was paid.',
      selectedValue: selectedPaymentMethod,
      options: PaymentMethod.values
          .map(
            (method) => _TransactionPickerOption(
              value: method.name,
              title: _paymentMethodLabel(method),
              subtitle: 'Payment method',
              icon: Icons.account_balance_wallet_outlined,
            ),
          )
          .toList(),
    );

    if (selected == null || !mounted) return;
    _setSelectedPaymentMethod(selected);
  }

  Future<T?> _showSelectionPicker<T>({
    required String title,
    required String subtitle,
    required T? selectedValue,
    required List<_TransactionPickerOption<T>> options,
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
  late String selectedPaymentMethod;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    amountController = TextEditingController();
    noteController = TextEditingController();
    selectedPaymentMethod = PaymentMethod.cash.name;
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
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
      selectedDate = pickedDate;
    });
  }

  void changeTransactionType(TransactionType type) {
    setState(() {
      transactionType = type;
      selectedCategory = null;
    });
  }

  Future<void> saveTransaction() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!formKey.currentState!.validate()) return;

    if (selectedCategory == null) {
      showMessage('Select a category.');
      return;
    }

    final amount = double.tryParse(amountController.text.trim());

    if (amount == null || amount <= 0) {
      showMessage('Enter a valid amount greater than ৳0.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final now = DateTime.now();

      final paymentMethod = PaymentMethod.values.firstWhere(
        (method) => method.name == selectedPaymentMethod,
      );

      final transaction = Transaction(
        id: AppUtils.generateId(),
        type: transactionType,
        amount: amount,
        categoryId: selectedCategory!,
        date: selectedDate,
        paymentMethod: paymentMethod,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(transactionViewModelProvider).addTransaction(transaction);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction added successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      showMessage('Could not save transaction: $error');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _setSelectedCategory(String value) {
    setState(() => selectedCategory = value);
  }

  void _setSelectedPaymentMethod(String value) {
    setState(() => selectedPaymentMethod = value);
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
            ?.where((category) => !category.isArchived)
            .toList() ??
        const <Category>[];

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Add transaction',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                'Record your transaction',
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

              _typeSelector(),

              const SizedBox(height: 14),

              _amountField(),

              const SizedBox(height: 12),

              _selectionField(
                label: 'Category',
                value: categoriesAsync.isLoading
                    ? 'Loading categories...'
                    : _categoryLabel(categories),
                icon: Icons.category_outlined,
                showLoading: categoriesAsync.isLoading,
                onTap:
                    isLoading ||
                        categoriesAsync.isLoading ||
                        categoriesAsync.hasError ||
                        categories.isEmpty
                    ? null
                    : () => _selectCategory(categories),
              ),
              const SizedBox(height: 12),
              _selectionField(
                label: 'Payment method',
                value: _paymentMethodLabel(
                  PaymentMethod.values.firstWhere(
                    (method) => method.name == selectedPaymentMethod,
                  ),
                ),
                icon: Icons.account_balance_wallet_outlined,
                onTap: isLoading ? null : _selectPaymentMethod,
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

              _dateField(),

              const SizedBox(height: 12),

              _noteField(),

              const SizedBox(height: 18),

              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : saveTransaction,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
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
                      : const Icon(Icons.check),
                  label: Text(
                    isLoading ? 'Saving...' : 'Save transaction',
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

  Widget _typeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _typeButton(
              type: TransactionType.expense,
              icon: Icons.north_east,
              label: 'Expense',
            ),
          ),
          Expanded(
            child: _typeButton(
              type: TransactionType.income,
              icon: Icons.south_west,
              label: 'Income',
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton({
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
      onTap: isLoading ? null : () => changeTransactionType(type),
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
            Icon(icon, size: 19, color: selected ? color : mutedColor),
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

  Widget _amountField() {
    return TextFormField(
      controller: amountController,
      autofocus: true,
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
      decoration: _inputDecoration(
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

  Widget _noteField() {
    return TextFormField(
      controller: noteController,
      enabled: !isLoading,
      maxLines: 3,
      maxLength: AppConstants.maxNoteLength,
      textCapitalization: TextCapitalization.sentences,
      decoration: _inputDecoration(
        label: 'Title or note',
        hint: 'Example: Grocery shopping or monthly salary',
        icon: Icons.notes_outlined,
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _dateField() {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: isLoading ? null : selectDate,
      child: InputDecorator(
        decoration: _inputDecoration(
          label: 'Transaction date',
          icon: Icons.calendar_today_outlined,
          suffix: const Icon(Icons.chevron_right),
        ),
        child: Text(DateFormat('EEE, d MMM yyyy').format(selectedDate)),
      ),
    );
  }

  InputDecoration _inputDecoration({
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

  String _paymentMethodLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.bankTransfer => 'Bank Transfer',
      PaymentMethod.debitCard => 'Debit Card',
      PaymentMethod.creditCard => 'Credit Card',
      PaymentMethod.mobileWallet => 'Mobile Wallet',
      PaymentMethod.other => 'Other',
    };
  }
}

class _TransactionPickerOption<T> {
  const _TransactionPickerOption({
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
