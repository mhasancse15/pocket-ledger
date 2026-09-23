import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/transaction.dart';
import '../providers/transaction_provider.dart';

/// ViewModel for transaction management (add/edit)
class TransactionViewModel {
  final Ref _ref;

  TransactionViewModel(this._ref);

  /// Add a new transaction
  Future<void> addTransaction(Transaction transaction) async {
    await _ref.read(transactionNotifierProvider.notifier).addTransaction(transaction);
  }

  /// Update an existing transaction
  Future<void> updateTransaction(Transaction transaction) async {
    await _ref.read(transactionNotifierProvider.notifier).updateTransaction(transaction);
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String transactionId) async {
    await _ref.read(transactionNotifierProvider.notifier).deleteTransaction(transactionId);
  }

  /// Get a specific transaction
  Future<Transaction?> getTransaction(String id) async {
    try {
      final result = await _ref.read(allTransactionsProvider.future);
      return result.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}

/// Provider for TransactionViewModel
final transactionViewModelProvider = Provider((ref) {
  return TransactionViewModel(ref);
});
