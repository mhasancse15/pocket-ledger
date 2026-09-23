import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_wallet/presentation/providers/database_provider.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction.dart';

/// Provides the transaction repository
final transactionRepositoryProvider = Provider((ref) {
  return TransactionRepositoryImpl(ref.watch(databaseProvider));
});

/// Fetches all transactions
final allTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final result = await repository.getAllTransactions();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (transactions) => transactions,
  );
});

/// Fetches transactions for a specific month
final monthlyTransactionsProvider = FutureProvider.family<List<Transaction>, (int, int)>((ref, params) async {
  final (year, month) = params;
  final repository = ref.watch(transactionRepositoryProvider);
  final result = await repository.getTransactionsByMonth(year, month);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (transactions) => transactions,
  );
});

/// Fetches monthly total for a specific type
final monthlyTotalProvider = FutureProvider.family<double, (int, int, TransactionType)>((ref, params) async {
  final (year, month, type) = params;
  final repository = ref.watch(transactionRepositoryProvider);
  final result = await repository.getMonthlyTotal(year, month, type);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (total) => total,
  );
});

/// StateNotifier for managing transaction additions/updates
class TransactionNotifier extends StateNotifier<AsyncValue<Transaction>> {
  final TransactionRepositoryImpl _repository;
  final Ref _ref;

  TransactionNotifier(this._repository, this._ref) : super(const AsyncValue.loading());

  void _refresh() {
    _ref.invalidate(allTransactionsProvider);
    _ref.invalidate(monthlyTransactionsProvider);
    _ref.invalidate(monthlyTotalProvider);
  }

  Future<void> addTransaction(Transaction transaction) async {
    state = const AsyncValue.loading();
    final result = await _repository.addTransaction(transaction);
    state = result.fold(
      (failure) => AsyncValue.error(Exception(failure.message), StackTrace.current),
      (transaction) {
        _refresh();
        return AsyncValue.data(transaction);
      },
    );
  }

  Future<void> updateTransaction(Transaction transaction) async {
    state = const AsyncValue.loading();
    final result = await _repository.updateTransaction(transaction);
    state = result.fold(
      (failure) => AsyncValue.error(Exception(failure.message), StackTrace.current),
      (transaction) {
        _refresh();
        return AsyncValue.data(transaction);
      },
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    final result = await _repository.deleteTransaction(transactionId);
    result.fold(
      (failure) => state = AsyncValue.error(Exception(failure.message), StackTrace.current),
      (_) {
        _refresh();
        return null;
      },
    );
  }
}

final transactionNotifierProvider = StateNotifierProvider<TransactionNotifier, AsyncValue<Transaction>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return TransactionNotifier(repository, ref);
});
