import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/category.dart';
import '../viewmodels/transaction_viewmodel.dart';
import '../providers/category_provider.dart';

/// Page for editing an existing transaction
class EditTransactionPage extends ConsumerStatefulWidget {
  final String transactionId;

  const EditTransactionPage({
    Key? key,
    required this.transactionId,
  }) : super(key: key);

  @override
  ConsumerState<EditTransactionPage> createState() =>
      _EditTransactionPageState();
}

class _EditTransactionPageState extends ConsumerState<EditTransactionPage> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  late TransactionType _transactionType;
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  bool _isLoading = true;
  Transaction? _transaction;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    _selectedDate = DateTime.now();
    _transactionType = TransactionType.expense;
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    try {
      final vm = ref.read(transactionViewModelProvider);
      final transaction = await vm.getTransaction(widget.transactionId);
      if (mounted && transaction != null) {
        setState(() {
          _transaction = transaction;
          _amountController.text = transaction.amount.toString();
          _noteController.text = transaction.note ?? '';
          _selectedDate = transaction.date;
          _transactionType = transaction.type;
          _selectedCategory = transaction.categoryId;
          _selectedPaymentMethod = _paymentMethodLabel(
            transaction.paymentMethod,
          );
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _updateTransaction() async {
    if (_amountController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedTransaction = Transaction(
        id: _transaction!.id,
        type: _transactionType,
        amount: double.parse(_amountController.text),
        categoryId: _selectedCategory ?? '',
        date: _selectedDate,
        paymentMethod: PaymentMethod.values.firstWhere(
          (method) => _paymentMethodLabel(method) == _selectedPaymentMethod,
          orElse: () => PaymentMethod.cash,
        ),
        note: _noteController.text.isEmpty ? null : _noteController.text,
        createdAt: _transaction!.createdAt,
        updatedAt: DateTime.now(),
      );

      await ref
          .read(transactionViewModelProvider)
          .updateTransaction(updatedTransaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteTransaction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(transactionViewModelProvider)
            .deleteTransaction(_transaction!.id);
        if (mounted) {
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(
      categoriesByTypeProvider(
        _transactionType == TransactionType.expense
            ? CategoryType.expense
            : CategoryType.income,
      ),
    );
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Transaction')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Transaction')),
        body: const Center(child: Text('Transaction not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Transaction'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteTransaction,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Transaction Type Selector
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<TransactionType>(
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
                    onSelectionChanged: (Set<TransactionType> newSelection) {
                      setState(() {
                        _transactionType = newSelection.first;
                        _selectedCategory = null;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Amount Input
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${AppConstants.defaultCurrency} ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Selector
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: categories.when(
                loading: () => const <DropdownMenuItem<String>>[],
                error: (_, __) => const <DropdownMenuItem<String>>[],
                data: (items) => items
                    .where((category) =>
                        !category.isArchived || category.id == _selectedCategory)
                    .map((category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ))
                    .toList(),
              ),
              onChanged: (value) {
                setState(() => _selectedCategory = value);
              },
            ),
            const SizedBox(height: 16),

            // Payment Method Selector
            DropdownButtonFormField<String>(
              initialValue: _selectedPaymentMethod,
              decoration: InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: AppConstants.paymentMethods
                  .map((method) => DropdownMenuItem(
                        value: method,
                        child: Text(method),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedPaymentMethod = value);
              },
            ),
            const SizedBox(height: 16),

            // Date Selector
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Transaction title
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: AppConstants.maxNoteLength,
              decoration: InputDecoration(
                labelText: 'Title (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Update Button
            FilledButton(
              onPressed: _isLoading ? null : _updateTransaction,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Transaction'),
            ),
          ],
        ),
      ),
    );
  }

  String _paymentMethodLabel(PaymentMethod method) {
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
}
