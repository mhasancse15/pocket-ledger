

import '../../core/errors/failures.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Base UseCase interface
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

class NoParams {}

/// UseCase for getting all transactions
class GetAllTransactionsUseCase implements UseCase<List<Transaction>, NoParams> {
  final TransactionRepository repository;

  GetAllTransactionsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Transaction>>> call(NoParams params) {
    return repository.getAllTransactions();
  }
}

/// UseCase for getting transactions by month
class GetTransactionsByMonthUseCase implements UseCase<List<Transaction>, (int, int)> {
  final TransactionRepository repository;

  GetTransactionsByMonthUseCase(this.repository);

  @override
  Future<Either<Failure, List<Transaction>>> call((int, int) params) {
    final (year, month) = params;
    return repository.getTransactionsByMonth(year, month);
  }
}

/// UseCase for deleting a transaction
class DeleteTransactionUseCase implements UseCase<void, String> {
  final TransactionRepository repository;

  DeleteTransactionUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String id) {
    return repository.deleteTransaction(id);
  }
}

/// UseCase for updating a transaction
class UpdateTransactionUseCase implements UseCase<Transaction, Transaction> {
  final TransactionRepository repository;

  UpdateTransactionUseCase(this.repository);

  @override
  Future<Either<Failure, Transaction>> call(Transaction transaction) {
    return repository.updateTransaction(transaction);
  }
}
