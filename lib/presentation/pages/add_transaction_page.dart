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

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({
    this.initialType = TransactionType.expense,
    super.key,
  });

  final TransactionType initialType;

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
    required Color iconColor,
    required Color iconEndColor,
    bool showForwardArrow = false,
    bool showLoading = false,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardBorder),
            boxShadow: _cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconColor, iconEndColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: .18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: mutedColor.withValues(alpha: .78),
                        fontWeight: FontWeight.w600,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (showLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: mutedColor,
                  ),
                )
              else
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: .58,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    showForwardArrow
                        ? Icons.chevron_right_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: mutedColor,
                  ),
                ),
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
  Color get mutedColor => Theme.of(context).colorScheme.onSurfaceVariant;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _surfaceColor => _isDark
      ? Theme.of(context).colorScheme.surface
      : Colors.white.withValues(alpha: .96);
  Color get _cardBorder => _isDark
      ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .26)
      : const Color(0xFFE5EAF2);
  List<BoxShadow> get _cardShadow => [
    BoxShadow(
      color: primary.withValues(alpha: _isDark ? .04 : .045),
      blurRadius: 22,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: _isDark ? .08 : .015),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

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

    transactionType = widget.initialType;
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
        toolbarHeight: 58,
        titleSpacing: 16,
        backgroundColor: background.withValues(alpha: .82),
        title: Text(
          'Add transaction',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _AddTransactionBackdrop()),
          SafeArea(
            child: Form(
              key: formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
                children: [
                  Text(
                    'Record your transaction',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontSize: 24,
                      height: 1.15,
                      letterSpacing: -.55,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep your income and expenses organized seamlessly.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: mutedColor, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  _typeSelector(),
                  const SizedBox(height: 12),
                  _amountField(),
                  const SizedBox(height: 10),
                  _selectionField(
                    label: 'Category',
                    value: categoriesAsync.isLoading
                        ? 'Loading categories...'
                        : _categoryLabel(categories),
                    icon: Icons.grid_view_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    iconEndColor: const Color(0xFF6366F1),
                    showLoading: categoriesAsync.isLoading,
                    onTap:
                        isLoading ||
                            categoriesAsync.isLoading ||
                            categoriesAsync.hasError ||
                            categories.isEmpty
                        ? null
                        : () => _selectCategory(categories),
                  ),
                  const SizedBox(height: 10),
                  _selectionField(
                    label: 'Payment method',
                    value: _paymentMethodLabel(
                      PaymentMethod.values.firstWhere(
                        (method) => method.name == selectedPaymentMethod,
                      ),
                    ),
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF06B6D4),
                    iconEndColor: const Color(0xFF14B8A6),
                    onTap: isLoading ? null : _selectPaymentMethod,
                  ),
                  if (categoriesAsync.hasError)
                    _categoryMessage(
                      'Unable to load categories',
                      Theme.of(context).colorScheme.error,
                    ),
                  if (!categoriesAsync.isLoading &&
                      !categoriesAsync.hasError &&
                      categories.isEmpty)
                    _categoryMessage(
                      'No categories available for this transaction type.',
                      Theme.of(context).colorScheme.error,
                    ),
                  const SizedBox(height: 10),
                  _dateField(),
                  const SizedBox(height: 10),
                  _noteField(),
                  const SizedBox(height: 16),
                  _saveButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryMessage(String message, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Text(message, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Widget _saveButton() {
    final color = transactionType == TransactionType.expense
        ? const Color(0xFF4F46E5)
        : const Color(0xFF059669);
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: transactionType == TransactionType.expense
                ? const [Color(0xFF4338CA), Color(0xFF6366F1)]
                : const [Color(0xFF059669), Color(0xFF10B981)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .25),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: isLoading ? null : saveTransaction,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: color.withValues(alpha: .6),
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 23),
          label: Text(
            isLoading ? 'Saving...' : 'Save Transaction',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _typeSelector() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: _isDark ? .42 : .56,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _isDark
              ? theme.colorScheme.outlineVariant.withValues(alpha: .2)
              : Colors.white.withValues(alpha: .9),
        ),
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
        ? const Color(0xFFF43F5E)
        : const Color(0xFF10B981);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isLoading ? null : () => changeTransactionType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: type == TransactionType.expense
                      ? const [Color(0xFFF43F5E), Color(0xFFEF4444)]
                      : const [Color(0xFF10B981), Color(0xFF059669)],
                )
              : null,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: .2),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: .2)
                    : mutedColor.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : mutedColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : mutedColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: .1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountField() {
    final theme = Theme.of(context);
    final amountAccent = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 11),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _isDark
              ? theme.colorScheme.primary.withValues(alpha: .25)
              : const Color(0xFFDDE4FF),
          width: 1.2,
        ),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: amountAccent.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'AMOUNT',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: amountAccent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
              ),
              Text(
                'BDT Currency',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: mutedColor.withValues(alpha: .75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: amountAccent.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: amountAccent.withValues(alpha: .1)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '৳',
                  style: TextStyle(
                    color: amountAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: amountController,
                  enabled: !isLoading,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: textColor,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: mutedColor.withValues(alpha: .35),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
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
          const SizedBox(height: 9),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: .35),
          ),
          const SizedBox(height: 9),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final amount in [100, 500, 1000, 5000]) ...[
                  if (amount != 100) const SizedBox(width: 8),
                  _QuickAmountChip(amount: amount, onTap: _addQuickAmount),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addQuickAmount(double amount) {
    if (isLoading) return;
    final current = double.tryParse(amountController.text.trim()) ?? 0;
    final updated = current + amount;
    amountController
      ..text = updated.toStringAsFixed(
        updated == updated.roundToDouble() ? 0 : 2,
      )
      ..selection = TextSelection.collapsed(
        offset: amountController.text.length,
      );
    formKey.currentState?.validate();
  }

  Widget _noteField() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
        boxShadow: _cardShadow,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: .18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.notes_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TITLE OR NOTE',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: mutedColor.withValues(alpha: .78),
                        fontWeight: FontWeight.w600,
                        letterSpacing: .7,
                      ),
                    ),
                    TextField(
                      controller: noteController,
                      enabled: !isLoading,
                      maxLines: 2,
                      minLines: 2,
                      maxLength: AppConstants.maxNoteLength,
                      textCapitalization: TextCapitalization.sentences,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: textColor,
                        height: 1.45,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Grocery shopping, salary, or coffee...',
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: mutedColor.withValues(alpha: .68),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.only(top: 5),
                        isDense: true,
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: .35),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: noteController,
              builder: (context, value, _) => Text(
                '${value.text.length}/${AppConstants.maxNoteLength}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: mutedColor.withValues(alpha: .7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField() {
    return _selectionField(
      label: 'Transaction date',
      value: DateFormat('EEE, d MMM yyyy').format(selectedDate),
      icon: Icons.calendar_month_outlined,
      iconColor: const Color(0xFF3B82F6),
      iconEndColor: const Color(0xFF6366F1),
      showForwardArrow: true,
      onTap: isLoading ? null : selectDate,
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

class _QuickAmountChip extends StatelessWidget {
  const _QuickAmountChip({required this.amount, required this.onTap});

  final int amount;
  final ValueChanged<double> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: theme.brightness == Brightness.dark ? .4 : .56,
      ),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => onTap(amount.toDouble()),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(
            '+৳${NumberFormat('#,##0').format(amount)}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTransactionBackdrop extends StatelessWidget {
  const _AddTransactionBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 30,
          right: -80,
          child: _glow(color: colors.primary.withValues(alpha: .17), size: 250),
        ),
        Positioned(
          top: 360,
          left: -100,
          child: _glow(
            color: colors.secondary.withValues(alpha: .12),
            size: 280,
          ),
        ),
        Positioned(
          top: 760,
          right: -90,
          child: _glow(
            color: colors.tertiary.withValues(alpha: .10),
            size: 260,
          ),
        ),
      ],
    );
  }

  Widget _glow({required Color color, required double size}) {
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
