import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';

class TransactionDetailsPage extends ConsumerWidget {
  const TransactionDetailsPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionItems = ref.watch(allTransactionsProvider).valueOrNull;
    final transaction = transactionItems == null
        ? null
        : _findTransaction(transactionItems);
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];
    if (transaction == null) {
      return const Scaffold(body: Center(child: Text('Transaction not found')));
    }
    final category = _findCategoryName(
          categories,
          transaction.categoryId,
        ) ?? transaction.categoryId;
    final color = transaction.type == TransactionType.income
        ? Colors.green
        : Colors.redAccent;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => context.pushNamed(
              AppRoutes.editTransactionName,
              pathParameters: {'id': transaction.id},
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    transaction.type == TransactionType.income
                        ? Icons.south_west
                        : Icons.north_east,
                    color: color,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${transaction.type == TransactionType.income ? '+' : '-'}'
                    '${AppUtils.formatCurrency(transaction.amount)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(transaction.note?.trim().isNotEmpty == true
                      ? transaction.note!
                      : category),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Category', value: category),
          _DetailRow(
            label: 'Date',
            value: DateFormat('d MMM yyyy, h:mm a')
                .format(transaction.date.toLocal()),
          ),
          _DetailRow(
            label: 'Payment method',
            value: transaction.paymentMethod.name,
          ),
          if (transaction.note?.trim().isNotEmpty == true)
            _DetailRow(label: 'Note', value: transaction.note!.trim()),
        ],
      ),
    );
  }

  Transaction? _findTransaction(List<Transaction> items) {
    for (final item in items) {
      if (item.id == transactionId) return item;
    }
    return null;
  }

  String? _findCategoryName(List<dynamic> items, String id) {
    for (final item in items) {
      if (item.id == id) return item.name as String;
    }
    return null;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: Text(value, textAlign: TextAlign.right),
  );
}
