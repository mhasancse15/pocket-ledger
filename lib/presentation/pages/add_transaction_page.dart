import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/category.dart';
import '../viewmodels/transaction_viewmodel.dart';
import '../providers/category_provider.dart';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({super.key});

  @override
  ConsumerState<AddTransactionPage> createState() =>
      _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late DateTime _selectedDate;
  late TransactionType _transactionType;

  String? _selectedCategory;
  late String _selectedPaymentMethod;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController();
    _noteController = TextEditingController();

    _selectedDate = DateTime.now();
    _transactionType = TransactionType.expense;
    _selectedPaymentMethod = AppConstants.paymentMethods.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select transaction date',
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      _selectedDate = pickedDate;
    });
  }

  void _changeTransactionType(TransactionType type) {
    setState(() {
      _transactionType = type;

      // Categories are different for income and expenses.
      _selectedCategory = null;
    });
  }

  Future<void> _saveTransaction() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(
      _amountController.text.trim(),
    );

    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid amount greater than ৳0.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();

      final paymentMethod = PaymentMethod.values.firstWhere(
            (method) => method.name == _selectedPaymentMethod,
        orElse: () => PaymentMethod.cash,
      );

      final transaction = Transaction(
        id: AppUtils.generateId(),
        type: _transactionType,
        amount: amount,
        categoryId: _selectedCategory!,
        date: _selectedDate,
        paymentMethod: paymentMethod,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await ref
          .read(transactionViewModelProvider)
          .addTransaction(transaction);

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

      _showMessage('Could not save transaction: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    final theme = Theme.of(context);

    final categoryType = _transactionType == TransactionType.expense
        ? CategoryType.expense
        : CategoryType.income;

    final categoriesAsync = ref.watch(
      categoriesByTypeProvider(categoryType),
    );

    final categoryItems = categoriesAsync.when(
      loading: () => <DropdownMenuItem<String>>[],
      error: (_, __) => <DropdownMenuItem<String>>[],
      data: (categories) {
        return categories
            .where((category) => !category.isArchived)
            .map(
              (category) => DropdownMenuItem<String>(
            value: category.id,
            child: Text(category.name),
          ),
        )
            .toList();
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add transaction',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'Record your transaction',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Keep your income and expenses organized.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Transaction type
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_transactionType},
                onSelectionChanged: _isLoading
                    ? null
                    : (selection) {
                  _changeTransactionType(selection.first);
                },
              ),

              const SizedBox(height: 24),

              // Amount
              TextFormField(
                controller: _amountController,
                autofocus: true,
                enabled: !_isLoading,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixText: '${AppConstants.defaultCurrency} ',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  helperText: 'Enter the transaction amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');

                  if (amount == null || amount <= 0) {
                    return 'Enter an amount greater than ৳0';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                  suffixIcon: categoriesAsync.isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                items: categoryItems,
                onChanged: _isLoading || categoriesAsync.isLoading
                    ? null
                    : (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select a category';
                  }

                  return null;
                },
              ),

              if (categoriesAsync.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    'Unable to load categories',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Payment method
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Payment method',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                items: AppConstants.paymentMethods
                    .map(
                      (method) => DropdownMenuItem<String>(
                    value: method,
                    child: Text(_formatLabel(method)),
                  ),
                )
                    .toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedPaymentMethod = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select a payment method';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Date
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isLoading ? null : _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Transaction date',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: const Icon(Icons.chevron_right),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    DateFormat('EEE, d MMM yyyy').format(_selectedDate),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Note
              TextFormField(
                controller: _noteController,
                enabled: !_isLoading,
                maxLines: 4,
                maxLength: AppConstants.maxNoteLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Note',
                  hintText: 'Add a note about this transaction',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save button
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _saveTransaction,
                  icon: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.check),
                  label: Text(
                    _isLoading
                        ? 'Saving transaction...'
                        : 'Save transaction',
                  ),
                ),
              ),
            ],
          ),
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
