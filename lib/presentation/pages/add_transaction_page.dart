import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/category.dart';
import '../viewmodels/transaction_viewmodel.dart';
import '../providers/category_provider.dart';


/// Page for adding a new transaction
class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  late TransactionType _transactionType;
  String? _selectedCategory;
  String? _selectedPaymentMethod;
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

  Future<void> _addTransaction() async {
    if (_amountController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final transaction = Transaction(
        id: AppUtils.generateId(),
        type: _transactionType,
        amount: double.parse(_amountController.text),
        categoryId: _selectedCategory ?? '',
        date: _selectedDate,
        paymentMethod: PaymentMethod.values.firstWhere(
          (method) => method.toString().split('.').last == _selectedPaymentMethod,
          orElse: () => PaymentMethod.cash,
        ),
        note: _noteController.text.isEmpty ? null : _noteController.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(transactionViewModelProvider).addTransaction(transaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction added successfully')),
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

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(
      categoriesByTypeProvider(
        _transactionType == TransactionType.expense
            ? CategoryType.expense
            : CategoryType.income,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        elevation: 0,
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              value: _selectedCategory,
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
                    .where((category) => !category.isArchived)
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
              value: _selectedPaymentMethod,
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

            // Note Input
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: AppConstants.maxNoteLength,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Add Button
            FilledButton(
              onPressed: _isLoading ? null : _addTransaction,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}
