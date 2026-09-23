import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/transaction.dart';
import '../providers/transaction_provider.dart';


/// Page for viewing all transactions with filtering
class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  TransactionType? _selectedType;
  String _query = '';
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        elevation: 0,
      ),
      body: transactions.when(
        data: (data) {
          final filtered = data.where((transaction) {
            final sameMonth = transaction.date.year == _selectedMonth.year &&
                transaction.date.month == _selectedMonth.month;
            final category = _selectedCategory == null ||
                transaction.categoryId == _selectedCategory;
            final payment = _selectedPaymentMethod == null ||
                transaction.paymentMethod.name == _selectedPaymentMethod;
            final type =
                _selectedType == null || transaction.type == _selectedType;
            final query = _query.isEmpty ||
                (transaction.note ?? '')
                    .toLowerCase()
                    .contains(_query.toLowerCase());
            return sameMonth && category && payment && type && query;
          }).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final total = filtered.fold<double>(
            0,
            (sum, transaction) => sum + transaction.amount,
          );
          final totalLabel = _selectedType == TransactionType.income
              ? 'Filtered income'
              : _selectedType == TransactionType.expense
                  ? 'Filtered expenses'
                  : 'Filtered total';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month - 1,
                            );
                          }),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                            );
                          }),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search notes',
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TransactionType?>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Transaction type',
                        prefixIcon: Icon(Icons.swap_vert),
                      ),
                      items: const [
                        DropdownMenuItem<TransactionType?>(
                          value: null,
                          child: Text('All transactions'),
                        ),
                        DropdownMenuItem<TransactionType?>(
                          value: TransactionType.expense,
                          child: Text('Expenses only'),
                        ),
                        DropdownMenuItem<TransactionType?>(
                          value: TransactionType.income,
                          child: Text('Income only'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedType = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All categories'),
                              ),
                              ...data
                                  .map((transaction) => transaction.categoryId)
                                  .toSet()
                                  .map((id) => DropdownMenuItem(
                                        value: id,
                                        child: Text(id),
                                      )),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedCategory = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _selectedPaymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Payment',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All methods'),
                              ),
                              ...PaymentMethod.values.map((method) =>
                                  DropdownMenuItem(
                                    value: method.name,
                                    child: Text(method.name),
                                  )),
                            ],
                            onChanged: (value) => setState(
                                () => _selectedPaymentMethod = value),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '$totalLabel: ${AppUtils.formatCurrency(total)} (${filtered.length} transactions)',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No transactions match these filters'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final transaction = filtered[index];
                          final isIncome =
                              transaction.type == TransactionType.income;
                          final icon = isIncome
                              ? Icons.arrow_downward
                              : Icons.arrow_upward;
                          final iconColor =
                              isIncome ? Colors.green : Colors.red;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(icon, color: iconColor),
                              title: Text(transaction.note ?? transaction.categoryId),
                              subtitle: Text(
                                '${transaction.categoryId} • ${transaction.date.toLocal().toString().split(' ').first}',
                              ),
                              trailing: Text(
                                '${isIncome ? '+' : '-'}${AppUtils.formatCurrency(transaction.amount)}',
                                style: TextStyle(
                                  color: iconColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () => context.push(
                                '/edit-transaction/${transaction.id}',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error: ${err.toString()}'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/add-transaction');
        },
        tooltip: 'Add Transaction',
        child: const Icon(Icons.add),
      ),
    );
  }
}
